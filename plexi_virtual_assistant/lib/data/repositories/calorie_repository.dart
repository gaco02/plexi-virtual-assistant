import 'dart:async';
import '../models/calorie_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../../services/api_service.dart';
import 'package:synchronized/synchronized.dart';

class CalorieRepository {
  // In-memory storage for calorie entries
  static List<CalorieEntry> _entries = [];
  static bool _initialized = false;
  static const String _storageKey = 'calorie_entries';

  // Cache metadata
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheDuration = Duration(minutes: 15);

  // API service for server communication
  final ApiService? apiService;

  bool get _isCacheValid =>
      _lastCacheUpdate != null &&
      DateTime.now().difference(_lastCacheUpdate!) < _cacheDuration;

  // Cache update lock
  final _cacheLock = Lock();

  // Constructor with optional ApiService
  CalorieRepository({ApiService? apiService}) : apiService = apiService {
    _initializeEntries();
  }

  // Initialize entries from SharedPreferences and server if available
  Future<void> _initializeEntries() async {
    if (!_initialized) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Try to load from SharedPreferences first
        final entriesJson = prefs.getStringList(_storageKey);
        bool loadedFromPrefs = false;

        if (entriesJson != null && entriesJson.isNotEmpty) {
          try {
            _entries = entriesJson.map((json) {
              return CalorieEntry.fromJson(jsonDecode(json));
            }).toList();
            loadedFromPrefs = true;
          } catch (parseError) {
            // Ignore parse errors
          }
        } else {
          // No entries found in SharedPreferences
        }

        // If we have an API service, try to fetch entries from server via direct API
        if (apiService != null) {
          try {
            await _fetchDailyCaloriesFromServerVoid();
          } catch (serverError) {
            // Ignore server errors
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
                print(
                    '🍎 [CalorieRepository] Parsed timestamp: ${timestamp.toString().split(' ')[0]}');
              } else {
                timestamp =
                    today.add(Duration(hours: now.hour, minutes: now.minute));
                print('🍎 [CalorieRepository] Using current time as timestamp');
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
              if (timestamp.month == 3 && timestamp.day == 28) {
                print(
                    '🍎 [CalorieRepository] Found March 28 entry: ${calorieEntry.foodItem}');
              }

              newEntries.add(calorieEntry);
            } catch (e) {
              print('🍎 [CalorieRepository] Error parsing entry: $e');
              // Continue to next entry
            }
          }

          print(
              '🍎 [CalorieRepository] Successfully parsed ${newEntries.length} entries from server');

          if (newEntries.isNotEmpty) {
            // Add new entries to the in-memory list
            _entries.addAll(newEntries);

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

      print(
          '🍎 [CalorieRepository] Daily summary response: ${response != null ? 'Success' : 'Null'}');

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

      print(
          '🍎 [CalorieRepository] Daily summary response from server: ${summaryResponse != null ? 'Success' : 'Null'}');

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
    print('🍎 [CalorieRepository] Processing breakdown list: $breakdownItems');

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

  // Save entries to SharedPreferences
  Future<void> _saveEntries() async {
    try {
      if (_entries.isEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Convert entries to JSON
      final entriesJson = _entries.map((entry) {
        final json = jsonEncode(entry.toJson());
        return json;
      }).toList();

      // Save to SharedPreferences
      final success = await prefs.setStringList(_storageKey, entriesJson);
    } catch (e) {}
  }

  /// Fetches all calorie entries
  Future<List<CalorieEntry>> getCalorieEntries(
      {bool forceRefresh = false}) async {
    try {
      print(
          '🍎 [CalorieRepository] getCalorieEntries called with forceRefresh: $forceRefresh');

      // Make sure entries are initialized
      await _initializeEntries();

      // If cache is valid and not forcing refresh, return cached entries
      if (_entries.isNotEmpty && _isCacheValid && !forceRefresh) {
        print(
            '🍎 [CalorieRepository] Using ${_entries.length} cached entries (cache age: ${DateTime.now().difference(_lastCacheUpdate!).inMinutes}m)');
        return List.from(_entries);
      }

      print(
          '🍎 [CalorieRepository] Cache invalid or force refresh requested, fetching fresh data');

      // If we have an API service, try to fetch from server first
      if (apiService != null) {
        try {
          // Get current user ID
          final userId = apiService?.getCurrentUserId();
          if (userId == null) {
            print(
                '🍎 [CalorieRepository] No user ID found, using local entries');
            return List.from(_entries);
          }

          print(
              '🍎 [CalorieRepository] Fetching entries from server for user: $userId');

          // Fetch entries from server using monthly period instead of 'all'
          final response = await apiService!.post('/calories/entries', {
            'user_id': userId,
            'period': 'monthly',
            'force_refresh':
                forceRefresh, // Pass through the force refresh parameter
          });

          print(
              '🍎 [CalorieRepository] Server response received: ${response != null ? 'Success' : 'Null'}');

          if (response != null) {
            // Handle the response based on its structure
            if (response is Map && response['entries'] is List) {
              final List<dynamic> serverEntries = response['entries'];
              print(
                  '🍎 [CalorieRepository] Processing ${serverEntries.length} entries from server response map');

              // Process entries and add to in-memory list
              await _processServerEntries(serverEntries);

              print(
                  '🍎 [CalorieRepository] After processing, have ${_entries.length} entries');
              return List.from(_entries);
            } else if (response is List) {
              print(
                  '🍎 [CalorieRepository] Processing ${response.length} entries from server response list');

              // Process entries and add to in-memory list
              await _processServerEntries(response);

              print(
                  '🍎 [CalorieRepository] After processing, have ${_entries.length} entries');
              return List.from(_entries);
            } else {
              print(
                  '🍎 [CalorieRepository] Unexpected server response format: ${response.runtimeType}');
            }
          }
        } catch (e) {
          print(
              '🍎 [CalorieRepository] Error fetching entries from server: $e');
          // Continue with local entries
        }
      }

      // Return the current entries if server fetch fails or is not available
      print(
          '🍎 [CalorieRepository] Returning ${_entries.length} local entries');
      return List.from(_entries);
    } catch (e) {
      print('🍎 [CalorieRepository] Error in getCalorieEntries: $e');
      // Return empty list if anything fails
      return [];
    }
  }

  /// Process server entries and add them to in-memory list
  Future<void> _processServerEntries(List<dynamic> serverEntries) async {
    return _cacheLock.synchronized(() async {
      final List<CalorieEntry> newEntries = [];

      for (var entry in serverEntries) {
        try {
          // Parse timestamp
          DateTime timestamp;
          if (entry['timestamp'] != null) {
            timestamp = DateTime.parse(entry['timestamp']);
            print(
                '🍎 [CalorieRepository] Parsed timestamp: ${timestamp.toString().split(' ')[0]}');
          } else {
            final now = DateTime.now();
            timestamp =
                DateTime(now.year, now.month, now.day, now.hour, now.minute);
            print('🍎 [CalorieRepository] Using current time as timestamp');
          }

          // Parse numeric values safely using existing helper methods
          int calories = _parseToInt(entry['calories']);
          int? protein =
              entry['protein'] != null ? _parseToInt(entry['protein']) : null;
          int? carbs =
              entry['carbs'] != null ? _parseToInt(entry['carbs']) : null;
          int? fat = entry['fat'] != null ? _parseToInt(entry['fat']) : null;
          double quantity =
              _parseToDouble(entry['quantity'], defaultValue: 1.0);

          final String foodItem = entry['food_item'] ?? 'Unknown food';

          // Create a new entry
          final calorieEntry = CalorieEntry(
            id: entry['id']?.toString(),
            foodItem: foodItem,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            quantity: quantity,
            unit: entry['unit'] ?? 'serving',
            timestamp: timestamp,
          );

          newEntries.add(calorieEntry);
        } catch (e) {
          print('🍎 [CalorieRepository] Error processing entry: $e');
        }
      }

      if (newEntries.isNotEmpty) {
        // Replace existing entries with new ones
        _entries = newEntries;
        _lastCacheUpdate = DateTime.now();

        // Save to shared preferences
        await _saveEntries();
      }
    });
  }

  // Helper method to parse int values safely
  int _parseToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // Helper method to parse double values safely
  double _parseToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Adds a new calorie entry
  Future<bool> addCalorieEntry(CalorieEntry entry) async {
    // Ensure entries are initialized
    await _initializeEntries();

    try {
      // First try to add to the server if API service is available
      if (apiService != null) {
        try {
          print(
              '🍎 [CalorieRepository] Attempting to add entry to server: ${entry.foodItem}');

          // Format the timestamp in a more compatible format: YYYY-MM-DD HH:MM:SS
          final formattedTimestamp =
              "${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')} "
              "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}";

          // Use the direct calories endpoint to add the entry
          // Convert numeric values to strings to ensure proper handling on the server
          final response = await apiService!.post('/calories/entries/add', {
            'food_item': entry.foodItem,
            'calories': entry.calories.toString(), // Convert to string
            'protein': entry.protein != null ? entry.protein.toString() : null,
            'carbs': entry.carbs != null ? entry.carbs.toString() : null,
            'fat': entry.fat != null ? entry.fat.toString() : null,
            'quantity': entry.quantity.toString(), // Convert to string
            'unit': entry.unit,
            'timestamp': formattedTimestamp, // Use the formatted timestamp
          });

          print('🍎 [CalorieRepository] Sent data: ${{
            "food_item": entry.foodItem,
            "calories": entry.calories.toString(),
            "timestamp": formattedTimestamp
          }}');

          print('🍎 [CalorieRepository] Server response: $response');

          // Add to local storage regardless of server response
          // This ensures we have the entry even if server sync failed
          _entries.add(entry);
          await _saveEntries();

          // Try to refresh from server but don't fail if it doesn't work
          try {
            await _fetchDailyCaloriesFromServerVoid();
          } catch (e) {
            print('🍎 [CalorieRepository] Error refreshing data: $e');
          }

          // Update daily summary
          _updateDailySummary();

          return true;
        } catch (e) {
          print('🍎 [CalorieRepository] Exception in server add: $e');
          // Continue with local storage even if server fails
          _entries.add(entry);
          await _saveEntries();

          // Update daily summary
          _updateDailySummary();

          return true;
        }
      }

      // Add to local storage
      _entries.add(entry);
      await _saveEntries();

      // Update daily summary
      _updateDailySummary();

      return true;
    } catch (e) {
      print('🍎 [CalorieRepository] Error adding calorie entry: $e');
      return false;
    }
  }

  /// Adds multiple calorie entries
  Future<bool> addCalorieEntries(List<CalorieEntry> entries) async {
    // Ensure entries are initialized
    await _initializeEntries();
    _entries.addAll(entries);
    await _saveEntries();
    return true;
  }

  /// Clears all calorie entries
  Future<bool> clearCalorieEntries() async {
    // Ensure entries are initialized
    await _initializeEntries();
    _entries.clear();
    await _saveEntries();
    return true;
  }

  /// Gets entries for a specific date
  Future<List<CalorieEntry>> getEntriesForDate(DateTime date) async {
    print(
        '🍎 [CalorieRepository] getEntriesForDate called for ${date.toString().split(' ')[0]}');
    final allEntries = await getCalorieEntries();
    final dateEntries = allEntries.where((entry) {
      return entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();
    print(
        '🍎 [CalorieRepository] Found ${dateEntries.length} entries for ${date.toString().split(' ')[0]}');
    // If looking for March 28 specifically, print more details
    if (date.month == 3 && date.day == 28) {
      print('🍎 [CalorieRepository] Detailed check for March 28:');
      print(
          '🍎 [CalorieRepository] Total entries in memory: ${allEntries.length}');
      // Check for any entries in March
      final marchEntries =
          allEntries.where((entry) => entry.timestamp.month == 3).toList();
      print(
          '🍎 [CalorieRepository] Total March entries: ${marchEntries.length}');
      if (marchEntries.isNotEmpty) {
        // Group by day
        final Map<int, int> entriesByDay = {};
        for (var entry in marchEntries) {
          final day = entry.timestamp.day;
          entriesByDay[day] = (entriesByDay[day] ?? 0) + 1;
        }
        print('🍎 [CalorieRepository] March entries by day: $entriesByDay');
      }
    }
    return dateEntries;
  }

  /// Gets entries for a date range
  Future<List<CalorieEntry>> getEntriesForDateRange(
      DateTime startDate, DateTime endDate) async {
    final allEntries = await getCalorieEntries();
    return allEntries.where((entry) {
      return entry.timestamp
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          entry.timestamp.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Gets daily calorie summary for today without caching.
  Future<Map<String, dynamic>> getDailyCalories(
      {bool forceRefresh = false}) async {
    try {
      final result = await _getDailyCaloriesImpl(forceRefresh: forceRefresh);
      return result;
    } catch (e) {
      print('❌ [CalorieRepository] Error getting daily calories: $e');
      return {
        'totalCalories': 0,
        'totalCarbs': 0.0,
        'totalProtein': 0.0,
        'totalFat': 0.0,
        'breakdown': <Map<String, dynamic>>[],
      };
    }
  }

  // Implementation of daily calories fetching logic
  Future<Map<String, dynamic>> _getDailyCaloriesImpl(
      {bool forceRefresh = false}) async {
    // Ensure entries are initialized
    await _initializeEntries();

    // Try to get data from server first if API service is available
    if (apiService != null) {
      try {
        // First try to get the summary from the server
        final summaryResponse =
            await _fetchDailyCaloriesFromServer(forceRefresh: forceRefresh);
        if (summaryResponse != null) {
          print(
              '🍎 [CalorieRepository] Processing server response: $summaryResponse');

          // Handle the case where total_calories is directly in the response (not in calorie_info)
          if (summaryResponse['total_calories'] != null ||
              summaryResponse['totalCalories'] != null) {
            final int totalCalories = _parseToInt(
                summaryResponse['totalCalories'] ??
                    summaryResponse['total_calories'] ??
                    0);

            final double totalCarbs = _parseToDouble(
                summaryResponse['totalCarbs'] ??
                    summaryResponse['total_carbs'] ??
                    0);

            final double totalProtein = _parseToDouble(
                summaryResponse['totalProtein'] ??
                    summaryResponse['total_protein'] ??
                    0);

            final double totalFat = _parseToDouble(
                summaryResponse['totalFat'] ??
                    summaryResponse['total_fat'] ??
                    0);

            // Get breakdown items from the server response
            List<dynamic> serverItems =
                summaryResponse['items'] ?? summaryResponse['breakdown'] ?? [];

            // Process breakdown items
            final List<Map<String, dynamic>> breakdown =
                serverItems is List ? _processBreakdownList(serverItems) : [];

            final result = {
              'totalCalories': totalCalories,
              'totalCarbs': totalCarbs,
              'totalProtein': totalProtein,
              'totalFat': totalFat,
              'breakdown': breakdown,
            };

            print(
                '🍎 [CalorieRepository] Using direct server response: $result');
            return result;
          }

          // Check if we have calorie_info in the response
          if (summaryResponse['calorie_info'] != null) {
            final calorieInfo = summaryResponse['calorie_info'];
            print('🍎 [CalorieRepository] Found calorie_info: $calorieInfo');

            // Parse total calories
            final int totalCalories = _parseToInt(
                calorieInfo['totalCalories'] ??
                    calorieInfo['total_calories'] ??
                    0);
            print(
                '🍎 [CalorieRepository] Parsed totalCalories: $totalCalories');

            // Always process the data from the server, even if totalCalories is 0
            {
              // Parse macros - handle both camelCase and snake_case keys
              final double totalCarbs = _parseToDouble(
                  calorieInfo['totalCarbs'] ?? calorieInfo['total_carbs'] ?? 0);
              final double totalProtein = _parseToDouble(
                  calorieInfo['totalProtein'] ??
                      calorieInfo['total_protein'] ??
                      0);
              final double totalFat = _parseToDouble(
                  calorieInfo['totalFat'] ?? calorieInfo['total_fat'] ?? 0);

              print(
                  '🍎 [CalorieRepository] Parsed macros - carbs: $totalCarbs, protein: $totalProtein, fat: $totalFat');

              // Get breakdown from items - handle both 'items' and 'breakdown' keys
              final List<Map<String, dynamic>> breakdown =
                  calorieInfo['breakdown'] != null &&
                          calorieInfo['breakdown'] is List
                      ? _processBreakdownList(calorieInfo['breakdown'])
                      : _getBreakdownFromItems(calorieInfo['items'] ?? {});

              print(
                  '🍎 [CalorieRepository] Processed breakdown with ${breakdown.length} items');

              final result = {
                'totalCalories': totalCalories,
                'totalCarbs': totalCarbs,
                'totalProtein': totalProtein,
                'totalFat': totalFat,
                'breakdown': breakdown,
              };
              return result;
            }
          }
        }
      } catch (e) {
        print('🍎 [CalorieRepository] Error getting data from server: $e');
        // Continue with local data if server fails
      }
    }

    print(
        '🍎 [CalorieRepository] Server data unavailable, calculating from local entries');

    // Fall back to local calculation if server fails or is not available
    final entries = await getCalorieEntries(forceRefresh: forceRefresh);

    // Get today's date at midnight for comparison
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter entries for today only
    final todayEntries = entries.where((entry) {
      final entryDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      final isToday = entryDate.isAtSameMomentAs(today);
      return isToday;
    }).toList();

    print(
        '🍎 [CalorieRepository] Found ${todayEntries.length} local entries for today');

    if (todayEntries.isNotEmpty) {
      // Calculate totals
      int totalCalories = 0;
      double totalCarbs = 0;
      double totalProtein = 0;
      double totalFat = 0;

      // Use a map to track food items for the breakdown
      // This is more memory efficient than creating a lot of objects
      final Map<String, Map<String, dynamic>> foodBreakdown = {};

      for (final entry in todayEntries) {
        totalCalories += entry.calories;
        totalCarbs += entry.carbs?.toDouble() ?? 0;
        totalProtein += entry.protein?.toDouble() ?? 0;
        totalFat += entry.fat?.toDouble() ?? 0;

        // Update the breakdown
        final foodItem = entry.foodItem;
        if (!foodBreakdown.containsKey(foodItem)) {
          foodBreakdown[foodItem] = {
            'calories': 0,
            'count': 0,
          };
        }
        foodBreakdown[foodItem]!['calories'] += entry.calories;
        foodBreakdown[foodItem]!['count'] += 1;
      }

      // Convert the breakdown to a list of the top items by calories
      final breakdownList = foodBreakdown.entries
          .map((e) => {
                'item': e.key,
                'calories': e.value['calories'],
                'count': e.value['count'],
              })
          .toList();

      // Sort by calories (highest first)
      breakdownList.sort(
          (a, b) => (b['calories'] as int).compareTo(a['calories'] as int));

      final result = {
        'totalCalories': totalCalories,
        'totalCarbs': totalCarbs,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'breakdown': breakdownList,
      };

      print(
          '🍎 [CalorieRepository] Calculated from local: totalCalories=$totalCalories');
      return result;
    } else {
      print('🍎 [CalorieRepository] No entries for today, returning zeros');
      return {
        'totalCalories': 0,
        'totalCarbs': 0.0,
        'totalProtein': 0.0,
        'totalFat': 0.0,
        'breakdown': [],
      };
    }
  }

  /// Force refresh from server
  Future<bool> refreshFromServer() async {
    if (apiService == null) return false;

    try {
      // Get current user ID from Firebase Auth
      final userId = apiService!.getCurrentUserId();
      if (userId == null) {
        return false;
      }

      // First try to get entries
      final entriesResponse = await apiService!.post('/calories/entries', {
        'user_id': userId,
        'period': 'daily',
      });

      List<dynamic> serverEntries = [];
      bool hasValidEntries = false;

      if (entriesResponse != null && entriesResponse['success'] == true) {
        serverEntries = entriesResponse['entries'] ?? [];
        if (serverEntries.isNotEmpty) {
          hasValidEntries = true;
        }
      }

      // Now try to get summary
      final summaryResponse = await apiService!.post('/calories/summary', {
        'user_id': userId,
        'period': 'daily',
        'message':
            'show me my daily calories', // Help the server determine the right query scope
      });

      print(
          '🍎 [CalorieRepository] Daily summary response: ${summaryResponse != null ? 'Success' : 'Null'}');

      bool hasSummaryData = false;
      int summaryTotalCalories = 0;

      if (summaryResponse != null) {
        if (summaryResponse['success'] == true &&
            summaryResponse['summary'] != null) {
          final summary = summaryResponse['summary'];
          summaryTotalCalories = _parseToInt(summary['total_calories']);
          hasSummaryData = summaryTotalCalories > 0;
        } else if (summaryResponse['calorie_info'] != null) {
          final calorieInfo = summaryResponse['calorie_info'];
          summaryTotalCalories = _parseToInt(calorieInfo['total_calories']);
          hasSummaryData = summaryTotalCalories > 0;
        }
      }

      // If we have entries but summary shows zero calories, calculate totals from entries
      if (hasValidEntries && !hasSummaryData && serverEntries.isNotEmpty) {
        // Calculate totals from entries
        int totalCalories = 0;
        double totalCarbs = 0;
        double totalProtein = 0;
        double totalFat = 0;

        // Use a map to track food items for the breakdown
        final Map<String, Map<String, dynamic>> foodBreakdown = {};

        for (final entry in serverEntries) {
          // Parse calories
          int calories = 0;
          if (entry['calories'] != null) {
            calories = _parseToInt(entry['calories']);
          }

          // Add to total
          totalCalories += calories;

          // Parse and add other nutrients
          if (entry['carbs'] != null) {
            totalCarbs += _parseToDouble(entry['carbs']);
          }
          if (entry['protein'] != null) {
            totalProtein += _parseToDouble(entry['protein']);
          }
          if (entry['fat'] != null) {
            totalFat += _parseToDouble(entry['fat']);
          }

          // Add to breakdown if food name is available
          final foodItem =
              entry['food_item'] ?? entry['food_name'] ?? 'Unknown food';
          if (!foodBreakdown.containsKey(foodItem)) {
            foodBreakdown[foodItem] = {
              'calories': 0,
              'count': 0,
            };
          }
          foodBreakdown[foodItem]!['calories'] += calories;
          foodBreakdown[foodItem]!['count'] += 1;
        }

        // Convert breakdown to list and sort by calories
        final List<Map<String, dynamic>> breakdownList = foodBreakdown.entries
            .map((entry) => {
                  'food_name': entry.key,
                  'calories': entry.value['calories'],
                  'count': entry.value['count'],
                })
            .toList();
        breakdownList.sort((a, b) => b['calories'].compareTo(a['calories']));

        // Update the daily summary with calculated values
        _updateDailySummary();

        // Update in-memory entries
        await _fetchDailyCaloriesFromServerVoid();
        return true;
      }

      // If we have valid summary data, use it
      if (hasSummaryData) {
        // Update in-memory entries
        await _fetchDailyCaloriesFromServerVoid();
        return true;
      }

      // If we have valid entries but no summary, still consider it a success
      if (hasValidEntries) {
        // Update in-memory entries
        await _fetchDailyCaloriesFromServerVoid();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if there are any calorie entries on the server
  Future<bool> checkServerEntries() async {
    if (apiService == null) return false;

    try {
      // Get current user ID from Firebase Auth
      final userId = apiService!.getCurrentUserId();
      if (userId == null) {
        return false;
      }

      // Try to get entries
      final response = await apiService!.post('/calories/entries', {
        'user_id': userId,
        'period': 'daily',
      });

      if (response != null && response['success'] == true) {
        final List<dynamic> serverEntries = response['entries'] ?? [];
        if (serverEntries.isNotEmpty) {
          return true;
        }
      }

      // Try summary endpoint as fallback
      final summaryResponse = await apiService!.post('/calories/summary', {
        'user_id': userId,
        'period': 'daily',
        'message':
            'show me my daily calories', // Help the server determine the right query scope
      });

      print(
          '🍎 [CalorieRepository] Daily summary response (fallback): ${summaryResponse != null ? 'Success' : 'Null'}');

      if (summaryResponse != null) {
        if (summaryResponse['success'] == true &&
            summaryResponse['summary'] != null) {
          final summary = summaryResponse['summary'];
          final totalCalories = _parseToInt(summary['total_calories']);
          return totalCalories > 0;
        } else if (summaryResponse['calorie_info'] != null) {
          final calorieInfo = summaryResponse['calorie_info'];
          final totalCalories = _parseToInt(calorieInfo['total_calories']);
          return totalCalories > 0;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Gets weekly calorie data without caching.
  Future<Map<String, dynamic>> getWeeklyCalories(
      {bool forceRefresh = false}) async {
    try {
      final result = await _getWeeklyCaloriesImpl(forceRefresh: forceRefresh);
      return result;
    } catch (e) {
      return {
        'total_calories': 0,
        'total_carbs': 0.0,
        'total_protein': 0.0,
        'total_fat': 0.0,
        'breakdown': [],
        'entries': [],
      };
    }
  }

  // Implementation of weekly calories fetching logic
  Future<Map<String, dynamic>> _getWeeklyCaloriesImpl(
      {bool forceRefresh = false}) async {
    if (apiService != null) {
      try {
        // Get current user ID from Firebase Auth
        final userId = apiService!.getCurrentUserId();
        if (userId == null) {
          print('🍎 [CalorieRepository] Weekly: No user ID available');
          throw Exception('No user ID available');
        }

        print('🍎 [CalorieRepository] Weekly: Getting data for user: $userId');

        // Get entries for the week with force refresh
        final entriesResponse = await apiService!.post('/calories/entries', {
          'user_id': userId,
          'period': 'weekly',
          'force_refresh': true,
          'message':
              'show me my weekly calories', // Help server understand the context
        });

        print(
            '🍎 [CalorieRepository] Weekly: Server response: $entriesResponse');

        List<dynamic> serverEntries = [];
        bool hasValidEntries = false;

        if (entriesResponse != null && entriesResponse['success'] == true) {
          serverEntries = entriesResponse['entries'] ?? [];
          print(
              '🍎 [CalorieRepository] Weekly: Received ${serverEntries.length} entries');

          // Debug: Print timestamps of entries to verify date range
          if (serverEntries.isNotEmpty) {
            print('🍎 [CalorieRepository] First few entries timestamps:');
            for (var i = 0; i < min(5, serverEntries.length); i++) {
              final entry = serverEntries[i];
              if (entry['timestamp'] != null) {
                print(
                    '🍎 [CalorieRepository] Entry $i timestamp: ${entry['timestamp']}');
                try {
                  final date = DateTime.parse(entry['timestamp']);
                  print(
                      '🍎 [CalorieRepository] Parsed date: ${date.year}-${date.month}-${date.day}, Weekday: ${date.weekday}');
                } catch (e) {
                  print('🍎 [CalorieRepository] Error parsing date: $e');
                }
              }
            }

            // Group entries by day of week to see distribution
            final Map<String, int> caloriesByDay = {};
            final List<String> weekdays = [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ];

            // Initialize with zero calories for each day
            for (final day in weekdays) {
              caloriesByDay[day] = 0;
            }

            for (final entry in serverEntries) {
              if (entry['timestamp'] != null) {
                try {
                  final date = DateTime.parse(entry['timestamp']);
                  final weekday = _getWeekdayName(date.weekday);
                  final calories = _parseToInt(entry['calories']);
                  caloriesByDay[weekday] =
                      (caloriesByDay[weekday] ?? 0) + calories;
                } catch (e) {
                  // Ignore parsing errors
                }
              }
            }
            print(
                '🍎 [CalorieRepository] Calories by day of week: $caloriesByDay');
          }

          if (serverEntries.isNotEmpty) {
            hasValidEntries = true;

            // Calculate totals from entries
            int totalCalories = 0;
            double totalCarbs = 0;
            double totalProtein = 0;
            double totalFat = 0;

            // Use a map to track food items for the breakdown
            final Map<String, Map<String, dynamic>> foodBreakdown = {};

            for (final entry in serverEntries) {
              // Parse calories
              int calories = 0;
              if (entry['calories'] != null) {
                calories = _parseToInt(entry['calories']);
              }

              // Add to total
              totalCalories += calories;

              // Parse and add other nutrients
              if (entry['carbs'] != null) {
                totalCarbs += _parseToDouble(entry['carbs']);
              }
              if (entry['protein'] != null) {
                totalProtein += _parseToDouble(entry['protein']);
              }
              if (entry['fat'] != null) {
                totalFat += _parseToDouble(entry['fat']);
              }

              // Add to breakdown if food name is available
              final foodItem =
                  entry['food_item'] ?? entry['food_name'] ?? 'Unknown food';
              if (!foodBreakdown.containsKey(foodItem)) {
                foodBreakdown[foodItem] = {
                  'calories': 0,
                  'count': 0,
                };
              }
              foodBreakdown[foodItem]!['calories'] += calories;
              foodBreakdown[foodItem]!['count'] += 1;
            }

            // Convert breakdown to list and sort by calories
            final List<Map<String, dynamic>> breakdownList =
                foodBreakdown.entries
                    .map((entry) => {
                          'food_name': entry.key,
                          'calories': entry.value['calories'],
                          'count': entry.value['count'],
                        })
                    .toList();
            breakdownList
                .sort((a, b) => b['calories'].compareTo(a['calories']));

            // Create result map
            return {
              'total_calories': totalCalories,
              'total_carbs': totalCarbs,
              'total_protein': totalProtein,
              'total_fat': totalFat,
              'breakdown': breakdownList,
              'entries': serverEntries,
            };
          }
        } else {
          print(
              '🍎 [CalorieRepository] No entries found in server response: $entriesResponse');
        }

        // If we don't have valid entries, try to get summary
        final summaryResponse = await apiService!.post('/calories/summary', {
          'user_id': userId,
          'period': 'weekly',
          'message':
              'show me my weekly calories by day', // More specific for daily breakdown
          'force_refresh': true, // Add force_refresh parameter
        });

        print(
            '🍎 [CalorieRepository] Weekly summary response: ${summaryResponse != null ? 'Success' : 'Null'}');

        if (summaryResponse != null && summaryResponse['success'] == true) {
          final summary = summaryResponse['summary'] ??
              summaryResponse['calorie_info'] ??
              {};

          // Parse values
          final totalCalories = _parseToInt(summary['total_calories']);
          final totalCarbs = _parseToDouble(summary['total_carbs']);
          final totalProtein = _parseToDouble(summary['total_protein']);
          final totalFat = _parseToDouble(summary['total_fat']);

          // Get breakdown if available
          List<Map<String, dynamic>> breakdownList = [];
          if (summary['breakdown'] != null && summary['breakdown'] is List) {
            breakdownList = (summary['breakdown'] as List)
                .map((item) => {
                      'food_name': item['food_name'] ?? 'Unknown',
                      'calories': _parseToInt(item['calories']),
                      'count': _parseToInt(item['count'] ?? 1),
                    })
                .toList();
          }

          // In case server didn't provide entries but we have summary
          if (serverEntries.isEmpty) {
            // Try to get entries separately
            final retryEntriesResponse =
                await apiService!.post('/calories/entries', {
              'user_id': userId,
              'period': 'weekly',
              'force_refresh': true,
            });

            if (retryEntriesResponse != null &&
                retryEntriesResponse['success'] == true) {
              serverEntries = retryEntriesResponse['entries'] ?? [];
              print(
                  '🍎 [CalorieRepository] Retrieved ${serverEntries.length} entries on retry');
            }
          }

          return {
            'total_calories': totalCalories,
            'total_carbs': totalCarbs,
            'total_protein': totalProtein,
            'total_fat': totalFat,
            'breakdown': breakdownList,
            'entries': serverEntries,
          };
        } else {
          print(
              '🍎 [CalorieRepository] Failed to get weekly summary: $summaryResponse');
        }
      } catch (e) {
        print('🍎 [CalorieRepository] Error getting weekly calories: $e');
      }
    } else {
      print(
          '🍎 [CalorieRepository] No API service available for weekly calories');
    }

    // If we reach here, we couldn't get data from the server
    // Calculate from local entries
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get the date for the start of the week (Monday)
    final currentWeekday = now.weekday;
    final startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
    final startOfWeekMidnight =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    print('🍎 [CalorieRepository] Start of week: $startOfWeekMidnight');

    // Filter entries for current week only
    final weeklyEntries = _entries.where((entry) {
      return entry.timestamp.isAfter(
              startOfWeekMidnight.subtract(const Duration(minutes: 1))) &&
          entry.timestamp
              .isBefore(startOfWeekMidnight.add(const Duration(days: 7)));
    }).toList();

    print(
        '🍎 [CalorieRepository] Found ${weeklyEntries.length} local entries for current week');

    int totalCalories = 0;
    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;

    for (final entry in weeklyEntries) {
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
      'breakdown': [],
      'entries': weeklyEntries.map((e) => e.toJson()).toList(),
    };
  }

  // Helper to convert weekday number to name
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// Gets monthly calorie data without caching.
  Future<Map<String, dynamic>> getMonthlyCalories(
      {bool forceRefresh = false}) async {
    try {
      final result = await _getMonthlyCaloriesImpl(forceRefresh: forceRefresh);
      return result;
    } catch (e) {
      return {
        'total_calories': 0,
        'total_carbs': 0.0,
        'total_protein': 0.0,
        'total_fat': 0.0,
        'breakdown': [],
        'entries': [],
      };
    }
  }

  // Implementation of monthly calories fetching logic
  Future<Map<String, dynamic>> _getMonthlyCaloriesImpl(
      {bool forceRefresh = false}) async {
    if (apiService != null) {
      try {
        // Get current user ID from Firebase Auth
        final userId = apiService!.getCurrentUserId();
        if (userId == null) {
          throw Exception('No user ID available');
        }

        // Get entries for the month
        final entriesResponse = await apiService!.post('/calories/entries', {
          'user_id': userId,
          'period': 'monthly',
        });

        List<dynamic> serverEntries = [];
        bool hasValidEntries = false;

        if (entriesResponse != null && entriesResponse['success'] == true) {
          serverEntries = entriesResponse['entries'] ?? [];
          if (serverEntries.isNotEmpty) {
            hasValidEntries = true;

            // Calculate totals from entries
            int totalCalories = 0;
            double totalCarbs = 0;
            double totalProtein = 0;
            double totalFat = 0;

            // Use a map to track food items for the breakdown
            final Map<String, Map<String, dynamic>> foodBreakdown = {};

            for (final entry in serverEntries) {
              // Parse calories
              int calories = 0;
              if (entry['calories'] != null) {
                calories = _parseToInt(entry['calories']);
              }

              // Add to total
              totalCalories += calories;

              // Parse and add other nutrients
              if (entry['carbs'] != null) {
                totalCarbs += _parseToDouble(entry['carbs']);
              }
              if (entry['protein'] != null) {
                totalProtein += _parseToDouble(entry['protein']);
              }
              if (entry['fat'] != null) {
                totalFat += _parseToDouble(entry['fat']);
              }

              // Add to breakdown if food name is available
              final foodItem =
                  entry['food_item'] ?? entry['food_name'] ?? 'Unknown food';
              if (!foodBreakdown.containsKey(foodItem)) {
                foodBreakdown[foodItem] = {
                  'calories': 0,
                  'count': 0,
                };
              }
              foodBreakdown[foodItem]!['calories'] += calories;
              foodBreakdown[foodItem]!['count'] += 1;
            }

            // Convert breakdown to list and sort by calories
            final List<Map<String, dynamic>> breakdownList =
                foodBreakdown.entries
                    .map((entry) => {
                          'food_name': entry.key,
                          'calories': entry.value['calories'],
                          'count': entry.value['count'],
                        })
                    .toList();
            breakdownList
                .sort((a, b) => b['calories'].compareTo(a['calories']));

            // Create result map
            return {
              'total_calories': totalCalories,
              'total_carbs': totalCarbs,
              'total_protein': totalProtein,
              'total_fat': totalFat,
              'breakdown': breakdownList,
              'entries': serverEntries,
            };
          }
        }

        // If we don't have valid entries, try to get summary
        final summaryResponse = await apiService!.post('/calories/summary', {
          'user_id': userId,
          'period': 'monthly',
          'message':
              'show me my monthly calories', // Help the server determine the right query scope
        });

        print(
            '🍎 [CalorieRepository] Monthly summary response: ${summaryResponse != null ? 'Success' : 'Null'}');

        if (summaryResponse != null && summaryResponse['success'] == true) {
          final summary = summaryResponse['summary'] ??
              summaryResponse['calorie_info'] ??
              {};

          // Parse values
          final totalCalories = _parseToInt(summary['total_calories']);
          final totalCarbs = _parseToDouble(summary['total_carbs']);
          final totalProtein = _parseToDouble(summary['total_protein']);
          final totalFat = _parseToDouble(summary['total_fat']);

          // Get breakdown if available
          List<Map<String, dynamic>> breakdownList = [];
          if (summary['breakdown'] != null && summary['breakdown'] is List) {
            breakdownList = (summary['breakdown'] as List)
                .map((item) => {
                      'food_name': item['food_name'] ?? 'Unknown',
                      'calories': _parseToInt(item['calories']),
                      'count': _parseToInt(item['count'] ?? 1),
                    })
                .toList();
          }

          return {
            'total_calories': totalCalories,
            'total_carbs': totalCarbs,
            'total_protein': totalProtein,
            'total_fat': totalFat,
            'breakdown': breakdownList,
            'entries': serverEntries,
          };
        }
      } catch (e) {}
    }

    // If we reach here, we couldn't get data from the server
    // Calculate from local entries
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthAgo = DateTime(today.year, today.month - 1, today.day);

    final monthlyEntries =
        _entries.where((entry) => entry.timestamp.isAfter(monthAgo)).toList();

    int totalCalories = 0;
    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;

    for (final entry in monthlyEntries) {
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
      'breakdown': [],
      'entries': monthlyEntries.map((e) => e.toJson()).toList(),
    };
  }

  /// Deletes a calorie entry
  Future<bool> deleteCalorieEntry(String id) async {
    try {
      // Get current user ID
      final userId = apiService?.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // If we have an API service, try to delete on the server
      if (apiService != null) {
        final response = await apiService!.post('/calories/entries/delete', {
          'user_id': userId,
          'entry_id': id,
        });

        // Check if the deletion was successful
        if (response is Map<String, dynamic> && response['success'] == true) {
          // Refresh local data from server to ensure consistency
          await _fetchDailyCaloriesFromServerVoid();
          return true;
        } else {
          return false;
        }
      }

      // If no API service or server deletion failed, delete locally
      // Find the entry in the local list
      await _initializeEntries();

      // Since we don't have a direct way to identify entries by ID in the local storage,
      // this would require implementing a local deletion mechanism with a unique identifier.
      // For now, we'll just return false if the API service is not available.
      return false;
    } catch (e) {
      throw Exception('Failed to delete calorie entry: $e');
    }
  }

  /// Updates an existing calorie entry
  Future<bool> updateCalorieEntry(String id, String foodItem, int calories,
      {int? protein,
      int? carbs,
      int? fat,
      double quantity = 1.0,
      String unit = 'serving'}) async {
    try {
      // Get current user ID
      final userId = apiService?.getCurrentUserId();
      if (userId == null) {
        throw Exception('No user ID available');
      }

      // If we have an API service, try to update on the server
      if (apiService != null) {
        final response = await apiService!.post('/calories/entries/update', {
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

        // Check if the update was successful
        if (response is Map<String, dynamic> && response['success'] == true) {
          // Update the entry in the local list as well
          await _initializeEntries();

          // Remove the old entry with the same ID
          _entries.removeWhere((entry) => entry.id == id);

          // Create a new entry with the updated values
          final updatedEntry = CalorieEntry(
            id: id,
            foodItem: foodItem,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            quantity: quantity,
            unit: unit,
            timestamp: DateTime.now(), // Use current timestamp for the update
          );

          // Add the updated entry to the local list
          _entries.add(updatedEntry);

          // Save the updated entries to local storage
          await _saveEntries();

          // Refresh local data from server to ensure consistency
          await _fetchDailyCaloriesFromServerVoid();
          return true;
        } else {
          return false;
        }
      }

      // If no API service or server update failed, update locally
      // Find the entry in the local list
      await _initializeEntries();

      // Since we don't have a direct way to identify entries by ID in the local storage,
      // this would require implementing a local update mechanism with a unique identifier.
      // For now, we'll just return false if the API service is not available.
      return false;
    } catch (e) {
      throw Exception('Failed to update calorie entry: $e');
    }
  }
}
