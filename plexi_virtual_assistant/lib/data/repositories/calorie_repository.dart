import 'dart:async';
import '../models/calorie_entry.dart';
import 'dart:convert';
import 'dart:math';
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
            // Replace the in-memory list with new entries from server to avoid duplication
            // First, preserve any local entries that might not be on the server yet
            final localOnlyEntries = _entries.where((localEntry) {
              // Keep entries that don't have a server ID (newly created, not yet synced)
              return localEntry.id == null ||
                  !newEntries
                      .any((serverEntry) => serverEntry.id == localEntry.id);
            }).toList();

            // Combine server entries with local-only entries
            _entries = [...newEntries, ...localOnlyEntries];

            // Save to local storage
            await _saveEntries();

            // Update daily summary
            _updateDailySummary();
          }
        } else {}
      } else {
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
    breakdown
        .sort((a, b) => (b['calories'] as int).compareTo(a['calories'] as int));

    // Update the daily summary
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
        final calorieInfo = response['calorie_info'];

        // Update the daily summary with the data from the server
      }
    } catch (e) {}
  }

  // Helper method to fetch daily calories from server
  Future<Map<String, dynamic>?> _fetchDailyCaloriesFromServer(
      {bool forceRefresh = false}) async {
    if (apiService == null) return null;

    try {
      // Get current user ID from Firebase Auth
      final userId = apiService!.getCurrentUserId();

      if (userId == null) {
        return null;
      }

      // Try the summary endpoint
      final summaryResponse = await apiService!.post('/calories/summary', {
        'user_id': userId,
        'period': 'daily',
        'message':
            'show me my daily calories', // Help the server determine the right query scope
        'force_refresh': forceRefresh,
      });

      return summaryResponse;
    } catch (e) {
      return null;
    }
  }

  // Helper method to convert items to breakdown list
  List<Map<String, dynamic>> _getBreakdownFromItems(dynamic items) {
    if (items == null) return [];

    List<Map<String, dynamic>> breakdownList = [];

    if (items is Map<String, dynamic>) {
      breakdownList = items.entries
          .map((e) => {
                'item': e.key,
                'calories': e.value is Map ? e.value['calories'] ?? 0 : e.value,
                'count': e.value is Map ? e.value['count'] ?? 1 : 1,
              })
          .toList();
    } else if (items is List) {
      breakdownList = items.map((item) {
        if (item is Map<String, dynamic>) {
          return {
            'item': item['item'] ?? 'Unknown',
            'calories': item['calories'] ?? 0,
            'count': item['count'] ?? 1,
          };
        }
        return {'item': 'Unknown', 'calories': 0, 'count': 1};
      }).toList();
    }

    // Sort by calories (highest first)
    breakdownList
        .sort((a, b) => (b['calories'] as int).compareTo(a['calories'] as int));

    return breakdownList;
  }

  // Helper method to process breakdown list from server response
  List<Map<String, dynamic>> _processBreakdownList(
      List<dynamic> breakdownItems) {
    if (breakdownItems.isEmpty) return [];

    List<Map<String, dynamic>> result = [];

    for (final item in breakdownItems) {
      if (item is Map) {
        // Handle different formats of breakdown items
        final String foodItem = item['food_item'] ?? item['item'] ?? 'Unknown';
        final int calories = _parseToInt(item['calories']);
        final int count = _parseToInt(item['count'] ?? 1);

        result.add({
          'item': foodItem,
          'calories': calories,
          'count': count,
        });
      }
    }

    return result;
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
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
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
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
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

      // If we need to refresh or it's a new day, fetch from server
      if (forceRefresh || _isNewDay() || !_isCacheValid) {
        if (apiService != null) {
          await _fetchDailyCaloriesFromServerVoid();
        }
      }

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
      // Make sure entries are initialized
      await _initializeEntries();

      // Get current user ID
      final userId = apiService?.getCurrentUserId();

      if (userId == null) {
        return false;
      }

      // Add the entry to the in-memory cache
      _entries.add(entry);

      // Save to SQLite database
      await _dbHelper.saveCalorieEntry(entry, userId);

      // Update the last cache update time
      _lastCacheUpdate = DateTime.now();

      // If we have an API service, try to send to server
      if (apiService != null) {
        try {
          final response = await apiService!.post('/calories/add', {
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

          // If the server responds with an ID, update the entry
          if (response != null &&
              response['success'] == true &&
              response['id'] != null) {
            // Create a new entry with the server ID instead of modifying the final field
            final updatedEntry = CalorieEntry(
              id: response['id'].toString(),
              foodItem: entry.foodItem,
              calories: entry.calories,
              protein: entry.protein,
              carbs: entry.carbs,
              fat: entry.fat,
              quantity: entry.quantity,
              unit: entry.unit,
              timestamp: entry.timestamp,
            );

            // Update the entry in the database and in the cache
            await _dbHelper.updateCalorieEntry(updatedEntry, userId);

            // Update in-memory cache
            final entryIndex = _entries.indexWhere((e) => e.id == entry.id);
            if (entryIndex >= 0) {
              _entries[entryIndex] = updatedEntry;
            }
          }
        } catch (e) {
          // Ignore server errors, entry is already saved locally
        }
      }

      return true;
    } catch (e) {
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
          await apiService!.post('/calories/update', {
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

      // Remove from in-memory cache
      _entries.removeAt(index);

      // Remove from SQLite database
      await _dbHelper.deleteCalorieEntry(id);

      // Update the last cache update time
      _lastCacheUpdate = DateTime.now();

      // If we have an API service, try to send delete request to server
      if (apiService != null) {
        try {
          await apiService!.post('/calories/delete', {
            'user_id': userId,
            'entry_id': id,
          });
        } catch (e) {
          // Ignore server errors, entry is already deleted locally
        }
      }

      return true;
    } catch (e) {
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
