import 'dart:async';
import '../models/calorie_entry.dart';
import '../../services/api_service.dart';
import 'package:synchronized/synchronized.dart';
import '../local/database_helper.dart';

class CalorieRepository {
  // In-memory cache for calorie entries
  static List<CalorieEntry> _entries = [];
  static bool _initialized = false;

  // Cache metadata
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheDuration = Duration(minutes: 15);

  // API service for server communication
  final ApiService? apiService;

  // Database helper
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool get _isCacheValid =>
      _lastCacheUpdate != null &&
      DateTime.now().difference(_lastCacheUpdate!) < _cacheDuration;

  // Cache update lock
  final _cacheLock = Lock();

  // Constructor with optional ApiService
  CalorieRepository({ApiService? apiService}) : apiService = apiService {
    _initializeEntries();
  }

  // Initialize entries from SQLite and server if available
  Future<void> _initializeEntries() async {
    if (!_initialized) {
      try {
        // Get current user ID from Firebase Auth if available
        final userId = apiService?.getCurrentUserId();

        if (userId != null) {
          // Try to load from SQLite database first
          final dbEntries = await _dbHelper.getAllCalorieEntries(userId);

          if (dbEntries.isNotEmpty) {
            _entries = dbEntries;
            _lastCacheUpdate = DateTime.now();
          }

          // If we have an API service, try to fetch entries from server via direct API
          if (apiService != null) {
            try {
              await _fetchDailyCaloriesFromServerVoid();
            } catch (serverError) {
              // Ignore server errors, continue with local data
            }
          }
        }

        _initialized = true;
      } catch (e) {
        _initialized =
            true; // Mark as initialized even on error to prevent repeated attempts
      }
    }
  }

  // Fetch daily calories from server using the direct API endpoint
  Future<void> _fetchDailyCaloriesFromServerVoid() async {
    if (apiService == null) return;

    try {
      // Get current user ID from Firebase Auth
      final userId = apiService!.getCurrentUserId();

      if (userId == null) {
        return;
      }

      // Use the direct calories endpoint to get entries
      final response = await apiService!.post('/calories/entries', {
        'user_id': userId,
        'period': 'daily',
      });

      if (response != null) {
        if (response is Map && response.containsKey('success')) {}

        if (response is Map && response.containsKey('entries')) {
          if (response['entries'] is List && response['entries'].isNotEmpty) {}
        }
      }

      // Also fetch the summary data to get correct totals
      Map<String, dynamic>? summaryData;
      try {
        final summaryResponse = await apiService!.post('/calories/summary', {
          'user_id': userId,
          'period': 'daily',
        });

        if (summaryResponse != null &&
            summaryResponse is Map<String, dynamic>) {
          // The server returns the summary data directly
          summaryData = {
            'totalCalories': _parseToInt(summaryResponse['totalCalories']),
            'totalCarbs': _parseToDouble(summaryResponse['totalCarbs']),
            'totalProtein': _parseToDouble(summaryResponse['totalProtein']),
            'totalFat': _parseToDouble(summaryResponse['totalFat']),
            'breakdown': summaryResponse['breakdown'] ?? [],
          };
          print("CalorieRepository: Processed summary data: $summaryData");
        }
      } catch (e) {
        print("CalorieRepository: Error fetching summary data: $e");
      }

      if (response != null && response['success'] == true) {
        final List<dynamic> serverEntries = response['entries'] ?? [];

        if (serverEntries.isNotEmpty) {
          // Process server response and create entries
          final List<CalorieEntry> newEntries = [];

          // Get today's date
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Create entries from the server data
          for (var entry in serverEntries) {
            try {
              // Parse timestamp or use current time
              DateTime timestamp;
              if (entry['timestamp'] != null) {
                timestamp = DateTime.parse(entry['timestamp']);
              } else {
                timestamp =
                    today.add(Duration(hours: now.hour, minutes: now.minute));
              }

              // Parse numeric values safely
              int calories = _parseToInt(entry['calories']);
              int? protein = entry['protein'] != null
                  ? _parseToInt(entry['protein'])
                  : null;
              int? carbs =
                  entry['carbs'] != null ? _parseToInt(entry['carbs']) : null;
              int? fat =
                  entry['fat'] != null ? _parseToInt(entry['fat']) : null;
              double quantity =
                  _parseToDouble(entry['quantity'], defaultValue: 1.0);

              // Parse food item
              final foodItem = entry['food_item'] ?? 'Unknown food';

              final calorieEntry = CalorieEntry(
                id: entry['id']?.toString(), // Add the ID from the server
                foodItem: foodItem,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                quantity: quantity,
                unit: entry['unit'] ?? 'serving',
                timestamp: timestamp,
              );

              // Check if this is a March 28 entry
              if (timestamp.month == 3 && timestamp.day == 28) {}

              newEntries.add(calorieEntry);
            } catch (e) {
              // Continue to next entry
            }
          }

          if (newEntries.isNotEmpty) {
            // Merge server entries with local entries, avoiding duplicates
            // Keep track of server IDs to avoid duplicates
            final Set<String> serverIds = newEntries.map((e) => e.id).toSet();

            // Remove any local entries that have matching server IDs (these are duplicates)
            _entries
                .removeWhere((localEntry) => serverIds.contains(localEntry.id));

            // Also remove local UUID entries that are duplicates of server entries
            // (same food item, calories, and timestamp within 30 seconds)
            _entries.removeWhere((localEntry) {
              return newEntries.any((serverEntry) {
                final timeDiff = localEntry.timestamp
                    .difference(serverEntry.timestamp)
                    .abs();
                final isSameFood = localEntry.foodItem.toLowerCase() ==
                    serverEntry.foodItem.toLowerCase();
                final isSameCalories =
                    localEntry.calories == serverEntry.calories;
                final isWithinTimeWindow = timeDiff.inSeconds <= 30;

                // If it's a UUID (local entry) and matches a server entry, it's a duplicate
                final isLocalUUID =
                    localEntry.id.contains('-') && localEntry.id.length == 36;

                return isLocalUUID &&
                    isSameFood &&
                    isSameCalories &&
                    isWithinTimeWindow;
              });
            });

            // Add all server entries
            _entries.addAll(newEntries);

            // Sort entries by timestamp (newest first)
            _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            // Save to local storage
            await _saveEntries();

            // Update daily summary - but also save the server summary if available
            _updateDailySummary();
          }
        } else {
          print(
              "CalorieRepository: No server entries returned, but may have summary data");
        }

        // Save summary data if we have it, regardless of whether there were entries
        if (summaryData != null) {
          final today = DateTime.now();
          final todayStr =
              "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
          await _dbHelper.saveDailyCalorieSummary(todayStr, summaryData);
          print(
              "CalorieRepository: Saved server summary to local cache: $summaryData");
        }
      } else {
        print(
            "CalorieRepository: Server response was not successful or missing");

        // Still save summary data if we have it from the separate summary call
        if (summaryData != null) {
          final today = DateTime.now();
          final todayStr =
              "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
          await _dbHelper.saveDailyCalorieSummary(todayStr, summaryData);
          print(
              "CalorieRepository: Saved server summary to local cache (fallback): $summaryData");
        }

        // Try to get summary data as a fallback
        await _fetchDailySummaryFromServer();
      }
    } catch (e) {
      // Try to get summary data as a fallback
      await _fetchDailySummaryFromServer();
    }
  }

  // Update the daily summary based on entries
  void _updateDailySummary() {
    // Get today's date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter entries for today
    final todayEntries = _entries.where((entry) {
      final entryDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      return entryDate.isAtSameMomentAs(today);
    }).toList();

    // Group entries by food item for breakdown
    final Map<String, List<CalorieEntry>> entriesByFood = {};
    for (var entry in todayEntries) {
      if (!entriesByFood.containsKey(entry.foodItem)) {
        entriesByFood[entry.foodItem] = [];
      }
      entriesByFood[entry.foodItem]!.add(entry);
    }

    // Create breakdown items
    final List<Map<String, dynamic>> breakdown = [];
    entriesByFood.forEach((foodItem, entries) {
      int totalFoodCalories = 0;
      for (var entry in entries) {
        totalFoodCalories += entry.calories;
      }

      breakdown.add({
        'item': foodItem,
        'calories': totalFoodCalories,
        'count': entries.length,
      });
    });

    // Sort by calories (highest first)
    breakdown
        .sort((a, b) => (b['calories'] as int).compareTo(a['calories'] as int));

    // Update the daily summary (placeholder for future implementation)
  }

  // Fetch daily summary from server as a fallback
  Future<void> _fetchDailySummaryFromServer() async {
    if (apiService == null) return;

    try {
      // Get current user ID from Firebase Auth
      final userId = apiService!.getCurrentUserId();

      if (userId == null) {
        return;
      }

      // Use the summary endpoint
      final response = await apiService!.post('/calories/summary', {
        'user_id': userId,
        'period': 'daily',
        'message':
            'show me my daily calories', // Help the server determine the right query scope
      });

      if (response != null) {
        if (response is Map && response.containsKey('success')) {}

        if (response is Map && response.containsKey('calorie_info')) {}
      }

      // Process the summary data
      if (response != null && response['calorie_info'] != null) {
        // Future implementation: Update the daily summary with the data from the server
      }
    } catch (e) {}
  }

  // Check if it's a new day since last load
  bool _isNewDay() {
    if (_entries.isEmpty) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Find the most recent entry
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestEntry = _entries.first;
    final latestDate = DateTime(
      latestEntry.timestamp.year,
      latestEntry.timestamp.month,
      latestEntry.timestamp.day,
    );

    // If the latest entry is from before today, it's a new day
    return latestDate.isBefore(today);
  }

  // Save entries to SQLite database
  Future<void> _saveEntries() async {
    try {
      if (_entries.isEmpty) {
        return;
      }

      // Get current user ID
      final userId = apiService?.getCurrentUserId();
      if (userId == null) {
        return;
      }

      // Save to SQLite database
      await _dbHelper.saveCalorieEntries(_entries, userId);

      _lastCacheUpdate = DateTime.now(); // Update cache timestamp
    } catch (e) {}
  }

  /// Fetches all calorie entries
  Future<List<CalorieEntry>> getCalorieEntries(
      {bool forceRefresh = false}) async {
    try {
      print(
          "CalorieRepository: getCalorieEntries called with forceRefresh: $forceRefresh");
      print(
          "CalorieRepository: Current cache has ${_entries.length} total entries");

      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
        print(
            "CalorieRepository: No user ID available, returning cached entries");
        return List.from(_entries);
      }

      // If cache is valid and not forcing refresh, return cached entries
      if (_entries.isNotEmpty && _isCacheValid && !forceRefresh) {
        return List.from(_entries);
      }

      return await _cacheLock.synchronized(() async {
        // Double-check cache validity after lock acquisition to avoid duplicate work
        if (_entries.isNotEmpty && _isCacheValid && !forceRefresh) {
          return List.from(_entries);
        }

        // If we have an API service, try to fetch from server first
        if (apiService != null && forceRefresh) {
          try {
            await _fetchDailyCaloriesFromServerVoid();
          } catch (e) {
            // If server fetch fails, fall back to local database
            final dbEntries = await _dbHelper.getAllCalorieEntries(userId);
            if (dbEntries.isNotEmpty) {
              _entries = dbEntries;
              _lastCacheUpdate = DateTime.now();
            }
          }
        } else {
          // Just get from local database
          final dbEntries = await _dbHelper.getAllCalorieEntries(userId);
          if (dbEntries.isNotEmpty) {
            _entries = dbEntries;
            _lastCacheUpdate = DateTime.now();
          }
        }

        return List.from(_entries);
      });
    } catch (e) {
      return List.from(_entries); // Return what we have in case of error
    }
  }

  /// Fetches calorie entries for a specific date
  Future<List<CalorieEntry>> getCalorieEntriesForDate(DateTime date,
      {bool forceRefresh = false}) async {
    try {
      final dateStr = date.toString().split(' ')[0]; // Just the date part
      print(
          "CalorieRepository: getCalorieEntriesForDate called for $dateStr, forceRefresh: $forceRefresh");
      print(
          "CalorieRepository: Current cache has ${_entries.length} total entries");

      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
        print(
            "CalorieRepository: No user ID available, returning filtered cache entries");
        return _filterEntriesByDate(_entries, date);
      }

      // If cache is valid and not forcing refresh, return filtered cached entries
      if (_entries.isNotEmpty && _isCacheValid && !forceRefresh) {
        return _filterEntriesByDate(_entries, date);
      }

      return await _cacheLock.synchronized(() async {
        // Double-check cache validity after lock acquisition
        if (_entries.isNotEmpty && _isCacheValid && !forceRefresh) {
          return _filterEntriesByDate(_entries, date);
        }

        // Try to get directly from database for the specific date
        final dbEntries =
            await _dbHelper.getCalorieEntriesForDate(userId, date);

        // If we have entries for this date in the database and not forcing refresh, return them
        if (dbEntries.isNotEmpty && !forceRefresh) {
          return dbEntries;
        }

        // If we have an API service and either we're forcing refresh or we don't have local data
        if (apiService != null && (forceRefresh || dbEntries.isEmpty)) {
          try {
            await _fetchDailyCaloriesFromServerVoid();

            // After server fetch, get updated entries from database
            final freshDbEntries =
                await _dbHelper.getCalorieEntriesForDate(userId, date);
            return freshDbEntries;
          } catch (e) {
            // If server fetch fails, return what we got from the database
            return dbEntries;
          }
        }

        // Return database entries if we couldn't refresh from server
        return dbEntries;
      });
    } catch (e) {
      // Return filtered in-memory entries as a fallback
      return _filterEntriesByDate(_entries, date);
    }
  }

  /// Fetches daily calories and returns a summary
  Future<Map<String, dynamic>> getDailyCalories(
      {bool forceRefresh = false}) async {
    try {
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      // Get today's date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Check if we have valid cached summary data first
      Map<String, dynamic>? cachedSummary;
      if (!forceRefresh && userId != null) {
        try {
          cachedSummary = await _dbHelper.getDailyCalorieSummary(todayStr);
          if (cachedSummary != null) {
            // Check if the cache is still valid (less than 5 minutes old)
            final lastUpdated = cachedSummary['lastUpdated'] as int;
            final lastUpdateTime =
                DateTime.fromMillisecondsSinceEpoch(lastUpdated);
            final cacheAge = DateTime.now().difference(lastUpdateTime);

            if (cacheAge.inMinutes < 5) {
              print(
                  "CalorieRepository: Using cached summary data: $cachedSummary");

              // Still get today's entries for the breakdown and entries list
              final todayEntries = _entries.where((entry) {
                final entryDate = DateTime(
                  entry.timestamp.year,
                  entry.timestamp.month,
                  entry.timestamp.day,
                );
                return entryDate.isAtSameMomentAs(today);
              }).toList();

              return {
                'totalCalories': cachedSummary['totalCalories'] ?? 0,
                'totalCarbs': cachedSummary['totalCarbs'] ?? 0.0,
                'totalProtein': cachedSummary['totalProtein'] ?? 0.0,
                'totalFat': cachedSummary['totalFat'] ?? 0.0,
                'breakdown': cachedSummary['breakdown'] ?? [],
                'entries': todayEntries.map((e) => e.toJson()).toList(),
              };
            } else {
              print(
                  "CalorieRepository: Cached summary is stale (${cacheAge.inMinutes} minutes old), will refresh");
            }
          }
        } catch (e) {
          print("CalorieRepository: Error reading cached summary: $e");
        }
      }

      // If we need to refresh or it's a new day, fetch from server
      if (forceRefresh ||
          _isNewDay() ||
          !_isCacheValid ||
          cachedSummary == null) {
        if (apiService != null) {
          await _fetchDailyCaloriesFromServerVoid();

          // After fetching from server, try to get updated cached summary
          if (userId != null) {
            try {
              cachedSummary = await _dbHelper.getDailyCalorieSummary(todayStr);
              if (cachedSummary != null) {
                print(
                    "CalorieRepository: Using fresh cached summary data after server fetch: $cachedSummary");

                // Get today's entries for the breakdown and entries list
                final todayEntries = _entries.where((entry) {
                  final entryDate = DateTime(
                    entry.timestamp.year,
                    entry.timestamp.month,
                    entry.timestamp.day,
                  );
                  return entryDate.isAtSameMomentAs(today);
                }).toList();

                return {
                  'totalCalories': cachedSummary['totalCalories'] ?? 0,
                  'totalCarbs': cachedSummary['totalCarbs'] ?? 0.0,
                  'totalProtein': cachedSummary['totalProtein'] ?? 0.0,
                  'totalFat': cachedSummary['totalFat'] ?? 0.0,
                  'breakdown': cachedSummary['breakdown'] ?? [],
                  'entries': todayEntries.map((e) => e.toJson()).toList(),
                };
              }
            } catch (e) {
              print(
                  "CalorieRepository: Error reading fresh cached summary: $e");
            }
          }
        }
      }

      // Fall back to calculating from entries if no cached summary is available
      print(
          "CalorieRepository: No cached summary available, calculating from entries");

      // Filter entries for today
      final todayEntries = _entries.where((entry) {
        final entryDate = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        return entryDate.isAtSameMomentAs(today);
      }).toList();

      print(
          "CalorieRepository: getDailyCalories - Today's entries (${todayEntries.length}):");
      for (int i = 0; i < todayEntries.length; i++) {
        final e = todayEntries[i];
        print(
            "  [$i] ${e.foodItem}: ${e.calories} cal, ID: ${e.id}, Time: ${e.timestamp}");
      }

      // Calculate totals
      int totalCalories = 0;
      double totalCarbs = 0;
      double totalProtein = 0;
      double totalFat = 0;

      // Group entries by food item
      final Map<String, List<CalorieEntry>> entriesByFood = {};
      for (var entry in todayEntries) {
        if (!entriesByFood.containsKey(entry.foodItem)) {
          entriesByFood[entry.foodItem] = [];
        }
        entriesByFood[entry.foodItem]!.add(entry);
      }

      // Create breakdown items
      final List<Map<String, dynamic>> breakdown = [];
      entriesByFood.forEach((foodItem, entries) {
        int totalFoodCalories = 0;
        for (var entry in entries) {
          totalCalories += entry.calories;
          totalCarbs += entry.carbs?.toDouble() ?? 0;
          totalProtein += entry.protein?.toDouble() ?? 0;
          totalFat += entry.fat?.toDouble() ?? 0;
          totalFoodCalories += entry.calories;
        }

        breakdown.add({
          'item': foodItem,
          'calories': totalFoodCalories,
          'count': entries.length,
        });
      });

      // Sort by calories (highest first)
      breakdown.sort(
          (a, b) => (b['calories'] as int).compareTo(a['calories'] as int));

      print("CalorieRepository: getDailyCalories - Calculated totals:");
      print("  Total Calories: $totalCalories");
      print("  Total Protein: $totalProtein");
      print("  Total Carbs: $totalCarbs");
      print("  Total Fat: $totalFat");
      print("  Breakdown: $breakdown");

      return {
        'totalCalories': totalCalories,
        'totalCarbs': totalCarbs,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'breakdown': breakdown,
        'entries': todayEntries.map((e) => e.toJson()).toList(),
      };
    } catch (e) {
      // Return empty data in case of error
      return {
        'totalCalories': 0,
        'totalCarbs': 0.0,
        'totalProtein': 0.0,
        'totalFat': 0.0,
        'breakdown': [],
        'entries': [],
      };
    }
  }

  /// Fetches weekly calories and returns a summary
  Future<Map<String, dynamic>> getWeeklyCalories(
      {bool forceRefresh = false}) async {
    try {
      // Make sure entries are initialized
      await _initializeEntries();

      // If force refresh, try to get latest data from server
      if (forceRefresh && apiService != null) {
        try {
          await _fetchDailyCaloriesFromServerVoid();
        } catch (e) {
          // Ignore server errors, use what we have
        }
      }

      // Get the start of the current week (Sunday)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Find the previous Sunday (or today if it's Sunday)
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));

      // Filter entries for the current week
      final weekEntries = _entries.where((entry) {
        final entryDate = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        return !entryDate.isBefore(startOfWeek) && !entryDate.isAfter(today);
      }).toList();

      // Calculate totals
      int totalCalories = 0;
      double totalCarbs = 0;
      double totalProtein = 0;
      double totalFat = 0;

      for (var entry in weekEntries) {
        totalCalories += entry.calories;
        totalCarbs += entry.carbs?.toDouble() ?? 0;
        totalProtein += entry.protein?.toDouble() ?? 0;
        totalFat += entry.fat?.toDouble() ?? 0;
      }

      return {
        'total_calories': totalCalories,
        'total_carbs': totalCarbs,
        'total_protein': totalProtein,
        'total_fat': totalFat,
        'entries': weekEntries.map((e) => e.toJson()).toList(),
      };
    } catch (e) {
      // Return empty data in case of error
      return {
        'total_calories': 0,
        'total_carbs': 0.0,
        'total_protein': 0.0,
        'total_fat': 0.0,
        'entries': [],
      };
    }
  }

  /// Fetches monthly calories and returns a summary
  Future<Map<String, dynamic>> getMonthlyCalories(
      {bool forceRefresh = false}) async {
    try {
      // Make sure entries are initialized
      await _initializeEntries();

      // If force refresh, try to get latest data from server
      if (forceRefresh && apiService != null) {
        try {
          await _fetchDailyCaloriesFromServerVoid();
        } catch (e) {
          // Ignore server errors, use what we have
        }
      }

      // Get the start of the current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final today = DateTime(now.year, now.month, now.day);

      // Filter entries for the current month
      final monthEntries = _entries.where((entry) {
        final entryDate = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        return !entryDate.isBefore(startOfMonth) && !entryDate.isAfter(today);
      }).toList();

      // Calculate totals
      int totalCalories = 0;
      double totalCarbs = 0;
      double totalProtein = 0;
      double totalFat = 0;

      for (var entry in monthEntries) {
        totalCalories += entry.calories;
        totalCarbs += entry.carbs?.toDouble() ?? 0;
        totalProtein += entry.protein?.toDouble() ?? 0;
        totalFat += entry.fat?.toDouble() ?? 0;
      }

      return {
        'total_calories': totalCalories,
        'total_carbs': totalCarbs,
        'total_protein': totalProtein,
        'total_fat': totalFat,
        'entries': monthEntries.map((e) => e.toJson()).toList(),
      };
    } catch (e) {
      // Return empty data in case of error
      return {
        'total_calories': 0,
        'total_carbs': 0.0,
        'total_protein': 0.0,
        'total_fat': 0.0,
        'entries': [],
      };
    }
  }

  /// Adds a new calorie entry
  Future<bool> addCalorieEntry(CalorieEntry entry) async {
    try {
      print(
          "CalorieRepository: addCalorieEntry called for '${entry.foodItem}' with ${entry.calories} calories");
      print(
          "CalorieRepository: Entry ID: ${entry.id}, Protein: ${entry.protein}, Carbs: ${entry.carbs}, Fat: ${entry.fat}");

      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
        print("CalorieRepository: No user ID available, returning false");
        return false;
      }

      print(
          "CalorieRepository: Current cache has ${_entries.length} entries before adding");

      // Enhanced duplicate check - look for exact matches and recent similar entries
      final recentWindow =
          Duration(seconds: 10); // 10 second window for duplicates

      final duplicates = _entries.where((e) {
        final timeDiff = e.timestamp.difference(entry.timestamp).abs();
        final isRecentEntry = timeDiff < recentWindow;
        final isSameFoodAndCalories =
            e.foodItem.toLowerCase() == entry.foodItem.toLowerCase() &&
                e.calories == entry.calories;

        return isRecentEntry && isSameFoodAndCalories;
      }).toList();

      if (duplicates.isNotEmpty) {
        print(
            "CalorieRepository: Duplicate entry detected! Found ${duplicates.length} similar entries:");
        for (var existing in duplicates) {
          print(
              "  - Existing: ${existing.foodItem}, ${existing.calories} cal, ID: ${existing.id}, Protein: ${existing.protein}, Time: ${existing.timestamp}");
        }
        print(
            "  - New entry: ${entry.foodItem}, ${entry.calories} cal, ID: ${entry.id}, Protein: ${entry.protein}, Time: ${entry.timestamp}");
        print("CalorieRepository: Skipping duplicate entry addition");
        return true; // Return true to avoid error state, but don't add duplicate
      }

      // If we have an API service, try to send to server FIRST before adding locally
      String? serverId;
      if (apiService != null) {
        try {
          print("CalorieRepository: Sending entry to server first...");
          final response = await apiService!.post('/calories/entries/add', {
            'user_id': userId,
            'food_item': entry.foodItem,
            'calories': entry.calories,
            'protein': entry.protein,
            'carbs': entry.carbs,
            'fat': entry.fat,
            'quantity': entry.quantity,
            'unit': entry.unit,
            'timestamp': entry.timestamp.toIso8601String(),
          });

          print("CalorieRepository: Server response: $response");

          // Check if server detected a duplicate
          if (response != null && response['duplicate'] == true) {
            print(
                "CalorieRepository: Server detected duplicate, but updating summary data");

            // Even though it's a duplicate, the server may have provided updated totals
            // Extract summary data from the server response and update our cache
            if (response['total_calories'] != null) {
              final serverSummary = {
                'totalCalories': _parseToInt(response['total_calories']),
                'totalCarbs': _parseToDouble(response['total_carbs']),
                'totalProtein': _parseToDouble(response['total_protein']),
                'totalFat': _parseToDouble(response['total_fat']),
                'breakdown': response['breakdown'] ?? [],
              };

              // Save the updated summary to local cache
              final today = DateTime.now();
              final todayStr =
                  "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
              await _dbHelper.saveDailyCalorieSummary(todayStr, serverSummary);
              print(
                  "CalorieRepository: Updated cached summary with server data after duplicate detection: $serverSummary");
            }

            return true; // Server already has this entry
          }

          // If the server responds with an ID, use it for the entry
          if (response != null &&
              response['success'] == true &&
              response['id'] != null) {
            serverId = response['id'].toString();
            print("CalorieRepository: Server assigned ID $serverId to entry");
          }

          // Also check if the server provided summary data in the response
          if (response != null && response['total_calories'] != null) {
            final serverSummary = {
              'totalCalories': _parseToInt(response['total_calories']),
              'totalCarbs': _parseToDouble(response['total_carbs']),
              'totalProtein': _parseToDouble(response['total_protein']),
              'totalFat': _parseToDouble(response['total_fat']),
              'breakdown': response['breakdown'] ?? [],
            };

            // Save the summary to local cache
            final today = DateTime.now();
            final todayStr =
                "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
            await _dbHelper.saveDailyCalorieSummary(todayStr, serverSummary);
            print(
                "CalorieRepository: Updated cached summary with server data from add response: $serverSummary");
          }
        } catch (e) {
          print("CalorieRepository: Server error while adding entry: $e");
          // Continue with local storage even if server fails
        }
      }

      // Create the final entry with server ID if available
      final finalEntry = serverId != null
          ? CalorieEntry(
              id: serverId, // Use server ID as the primary ID
              foodItem: entry.foodItem,
              calories: entry.calories,
              protein: entry.protein,
              carbs: entry.carbs,
              fat: entry.fat,
              quantity: entry.quantity,
              unit: entry.unit,
              timestamp: entry.timestamp,
            )
          : entry; // Use original entry if no server ID

      // Add the entry to the in-memory cache
      _entries.add(finalEntry);
      print(
          "CalorieRepository: Added entry to cache with ID ${finalEntry.id}, new cache size: ${_entries.length}");

      // Save to SQLite database
      await _dbHelper.saveCalorieEntry(finalEntry, userId);
      print("CalorieRepository: Saved entry to SQLite database");

      // Update the last cache update time
      _lastCacheUpdate = DateTime.now();

      print("CalorieRepository: addCalorieEntry completed successfully");
      return true;
    } catch (e) {
      print("CalorieRepository: Error in addCalorieEntry: $e");
      return false;
    }
  }

  /// Updates an existing calorie entry
  Future<bool> updateCalorieEntry(
    String? id,
    String foodItem,
    int calories, {
    int? protein,
    int? carbs,
    int? fat,
    double? quantity,
    String? unit,
  }) async {
    try {
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null || id == null) {
        return false;
      }

      // Find the entry in the in-memory cache
      final index = _entries.indexWhere((e) => e.id == id);
      if (index < 0) {
        return false;
      }

      // Update the entry
      final updatedEntry = CalorieEntry(
        id: id,
        foodItem: foodItem,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        quantity: quantity ?? _entries[index].quantity,
        unit: unit ?? _entries[index].unit,
        timestamp: _entries[index].timestamp,
      );

      // Update in-memory cache
      _entries[index] = updatedEntry;

      // Save to SQLite database
      await _dbHelper.updateCalorieEntry(updatedEntry, userId);

      // Update the last cache update time
      _lastCacheUpdate = DateTime.now();

      // If we have an API service, try to send to server
      if (apiService != null) {
        try {
          await apiService!.post('/calories/entries/update', {
            'user_id': userId,
            'entry_id': id,
            'food_item': foodItem,
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'quantity': quantity,
            'unit': unit,
          });
        } catch (e) {
          // Ignore server errors, entry is already updated locally
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a calorie entry
  Future<bool> deleteCalorieEntry(String? id) async {
    print("CalorieRepository: deleteCalorieEntry called with ID: $id");

    try {
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
        print("CalorieRepository: deleteCalorieEntry failed - no user ID");
        return false;
      }

      if (id == null) {
        print(
            "CalorieRepository: deleteCalorieEntry failed - no entry ID provided");
        return false;
      }

      // Find the entry in the in-memory cache
      final index = _entries.indexWhere((e) => e.id == id);
      if (index < 0) {
        print(
            "CalorieRepository: deleteCalorieEntry failed - entry not found in cache");
        return false;
      }

      final entryToDelete = _entries[index];
      print(
          "CalorieRepository: Found entry to delete: ${entryToDelete.foodItem} (${entryToDelete.calories} cal)");

      // Remove from in-memory cache first
      _entries.removeAt(index);
      print(
          "CalorieRepository: Removed entry from in-memory cache. Cache now has ${_entries.length} entries");

      try {
        // Remove from SQLite database
        await _dbHelper.deleteCalorieEntry(id);
        print(
            "CalorieRepository: Successfully deleted entry from local database");
      } catch (e) {
        print("CalorieRepository: Error deleting from local database: $e");
        // Re-add to cache if local delete failed
        _entries.insert(index, entryToDelete);
        return false;
      }

      // Update the last cache update time and force cache invalidation
      _lastCacheUpdate = DateTime.now();

      // If we have an API service, try to send delete request to server
      if (apiService != null) {
        try {
          print("CalorieRepository: Sending delete request to server");

          // Check if we have a server ID for this entry
          final serverId = await _dbHelper.getCalorieEntryServerId(id);
          final entryIdToDelete = serverId ?? id;

          print(
              "CalorieRepository: Using entry ID for server delete: $entryIdToDelete ${serverId != null ? '(server ID)' : '(local ID)'}");

          await apiService!.post('/calories/entries/delete', {
            'user_id': userId,
            'entry_id': entryIdToDelete,
          });
          print("CalorieRepository: Successfully deleted entry from server");
        } catch (e) {
          print("CalorieRepository: Server delete failed (ignoring): $e");
          // We don't re-add to cache for server errors since local delete succeeded
        }
      } else {
        print(
            "CalorieRepository: No API service available, skipping server delete");
      }

      // Force refresh from server on next access to ensure consistency
      _lastCacheUpdate = null;

      print("CalorieRepository: deleteCalorieEntry completed successfully");
      return true;
    } catch (e) {
      print("CalorieRepository: deleteCalorieEntry failed with exception: $e");
      return false;
    }
  }

  /// Clears the in-memory cache and forces a fresh reload from the database
  void clearCache() {
    _entries.clear();
    _lastCacheUpdate = null;
    _initialized = false;
  }

  // Helper method to filter entries by date
  List<CalorieEntry> _filterEntriesByDate(
      List<CalorieEntry> entries, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return entries.where((entry) {
      final entryDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      return entryDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  // Helper method to parse integers
  int _parseToInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;

      // Try to parse as double first, then convert to int
      final parsedDouble = double.tryParse(value);
      if (parsedDouble != null) return parsedDouble.round();
    }

    return 0;
  }

  // Helper method to parse doubles
  double _parseToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }

    return defaultValue;
  }
}
