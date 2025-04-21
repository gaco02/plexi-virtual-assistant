import 'package:flutter_bloc/flutter_bloc.dart';
import 'calorie_event.dart';
import 'calorie_state.dart';
import '../../data/repositories/calorie_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../utils/daily_refresh_mixin.dart';
import '../../data/models/calorie_entry.dart';
import 'dart:async';
import '../../data/models/user_preferences.dart';
import '../../utils/nutrition_calculator.dart';

class CalorieBloc extends Bloc<CalorieEvent, CalorieState>
    with DailyRefreshMixin {
  final CalorieRepository _repository;
  final PreferencesRepository _userPreferencesRepository;
  Timer? _refreshTimer;

  CalorieBloc({
    required CalorieRepository repository,
    required PreferencesRepository userPreferencesRepository,
  })  : _repository = repository,
        _userPreferencesRepository = userPreferencesRepository,
        super(CalorieInitial()) {
    // First register all event handlers
    on<LoadDailyCalories>(_onLoadDaily);
    on<LoadWeeklyCalories>((event, emit) {
      return _onLoadWeekly(event, emit);
    });
    on<LoadMonthlyCalories>((event, emit) {
      return _onLoadMonthly(event, emit);
    });
    on<UpdateCaloriesFromChat>(_onUpdateCaloriesFromChat);
    on<AddCalorieEntry>(_onAddCalorieEntry);
    on<UpdateCalorieGoal>(_onUpdateCalorieGoal);
    on<EditCalorieEntry>(_onEditCalorieEntry);
    on<DeleteCalorieEntry>(_onDeleteCalorieEntry);

    // This reduces the number of checks by 15x
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      // Only refresh if we're in a loaded state to avoid unnecessary API calls
      if (state.status == CalorieStatus.loaded && shouldRefresh()) {
        add(LoadDailyCalories());
      }
    });
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadDaily(
    LoadDailyCalories event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      // Fetch daily calories
      final dailyData =
          await _repository.getDailyCalories(forceRefresh: event.forceRefresh);

      // Check if daily data is empty
      if (dailyData.isEmpty || dailyData['totalCalories'] == null) {
        // No daily data found, set total calories to 0
        emit(state.copyWith(
          status: CalorieStatus.loaded,
          totalCalories: 0,
          totalCarbs: 0.0,
          totalProtein: 0.0,
          totalFat: 0.0,
          breakdown: [],
        ));
        return;
      }

      // Process and emit the daily data as usual
      final int totalCalories = _parseToInt(dailyData['totalCalories']);
      final double totalCarbs = _parseToDouble(dailyData['totalCarbs']);
      final double totalProtein = _parseToDouble(dailyData['totalProtein']);
      final double totalFat = _parseToDouble(dailyData['totalFat']);

      // Get user preferences
      final preferencesData = await _userPreferencesRepository.getPreferences();
      final userPreferences = UserPreferences.fromJson(preferencesData);

      // Generate nutrition plan based on user preferences
      NutritionPlan? nutritionPlan;
      if (userPreferences.currentWeight != null &&
          userPreferences.height != null &&
          userPreferences.age != null) {
        try {
          nutritionPlan =
              NutritionCalculator.generateNutritionPlan(userPreferences);
        } catch (e) {}
      }

      final List<dynamic> newBreakdown =
          List.from(dailyData['breakdown'] ?? []);
      newBreakdown
          .sort((a, b) => a['item'].toString().compareTo(b['item'].toString()));

      // Compare new data with current state
      final bool dataChanged = state.totalCalories != totalCalories ||
          state.totalCarbs != totalCarbs ||
          state.totalProtein != totalProtein ||
          state.totalFat != totalFat ||
          !_listEquals(state.breakdown, newBreakdown);

      if (!dataChanged &&
          state.status == CalorieStatus.loaded &&
          !event.forceRefresh) {
        return;
      }

      // Emit loaded state with the data
      emit(state.copyWith(
        status: CalorieStatus.loaded,
        totalCalories: totalCalories,
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        breakdown: newBreakdown,
        nutritionPlan: nutritionPlan,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: CalorieStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateCaloriesFromChat(
    UpdateCaloriesFromChat event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      // Add new food entry if provided
      if (event.foodInfo != null) {
        final entry = CalorieEntry(
          foodItem: event.foodInfo!['food_item'] ?? 'Unknown food',
          calories: int.tryParse(event.foodInfo!['calories'] ?? '0') ?? 0,
          protein: int.tryParse(event.foodInfo!['protein'] ?? '0'),
          carbs: int.tryParse(event.foodInfo!['carbs'] ?? '0'),
          fat: int.tryParse(event.foodInfo!['fat'] ?? '0'),
          quantity: double.tryParse(event.foodInfo!['quantity'] ?? '1') ?? 1,
          unit: event.foodInfo!['unit'] ?? 'serving',
          timestamp: DateTime.now(),
        );

        final success = await _repository.addCalorieEntry(entry);
        if (success) {
        } else {}
      }

      // Get updated daily calorie data - if this is a query response and no food entry was added,
      // we'll use the data passed in the event
      Map<String, dynamic> dailyData;
      if (event.foodInfo == null && event.totalCalories >= 0) {
        // This is likely a query response, use the data from the event

        dailyData = {
          'totalCalories': event.totalCalories,
          'breakdown': event.breakdown ?? [],
        };
      } else {
        // Otherwise get the latest data from the repository
        dailyData = await _repository.getDailyCalories();
      }

      // Use the breakdown from the event if provided, otherwise use from repository
      final List<dynamic> breakdownList =
          event.breakdown ?? dailyData['breakdown'] ?? [];

      // Ensure proper type conversion for all numeric values
      final int totalCalories = (dailyData['totalCalories'] is int)
          ? dailyData['totalCalories']
          : (dailyData['totalCalories'] is double)
              ? (dailyData['totalCalories'] as double).round()
              : 0;

      final double totalCarbs = (dailyData['totalCarbs'] is double)
          ? dailyData['totalCarbs']
          : (dailyData['totalCarbs'] is int)
              ? (dailyData['totalCarbs'] as int).toDouble()
              : 0.0;

      final double totalProtein = (dailyData['totalProtein'] is double)
          ? dailyData['totalProtein']
          : (dailyData['totalProtein'] is int)
              ? (dailyData['totalProtein'] as int).toDouble()
              : 0.0;

      final double totalFat = (dailyData['totalFat'] is double)
          ? dailyData['totalFat']
          : (dailyData['totalFat'] is int)
              ? (dailyData['totalFat'] as int).toDouble()
              : 0.0;

      emit(state.copyWith(
        status: CalorieStatus.loaded,
        totalCalories: totalCalories,
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        breakdown: breakdownList,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: 'Failed to update calories: $e',
      ));
    }
  }

  Future<void> _onAddCalorieEntry(
    AddCalorieEntry event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      final success = await _repository.addCalorieEntry(event.entry);
      if (!success) {
        throw Exception('Failed to add calorie entry');
      }

      // Reload daily data
      final dailyData = await _repository.getDailyCalories();

      // Ensure proper type conversion for all numeric values
      final int totalCalories = (dailyData['totalCalories'] is int)
          ? dailyData['totalCalories']
          : (dailyData['totalCalories'] is double)
              ? (dailyData['totalCalories'] as double).round()
              : 0;

      final double totalCarbs = (dailyData['totalCarbs'] is double)
          ? dailyData['totalCarbs']
          : (dailyData['totalCarbs'] is int)
              ? (dailyData['totalCarbs'] as int).toDouble()
              : 0.0;

      final double totalProtein = (dailyData['totalProtein'] is double)
          ? dailyData['totalProtein']
          : (dailyData['totalProtein'] is int)
              ? (dailyData['totalProtein'] as int).toDouble()
              : 0.0;

      final double totalFat = (dailyData['totalFat'] is double)
          ? dailyData['totalFat']
          : (dailyData['totalFat'] is int)
              ? (dailyData['totalFat'] as int).toDouble()
              : 0.0;

      emit(state.copyWith(
        status: CalorieStatus.loaded,
        totalCalories: totalCalories,
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        breakdown: dailyData['breakdown'] ?? [],
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: 'Failed to add calorie entry: $e',
      ));
    }
  }

  Future<void> _onUpdateCalorieGoal(
    UpdateCalorieGoal event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(
        calorieGoal: event.calorieGoal,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: 'Failed to update calorie goal: $e',
      ));
    }
  }

  Future<void> _onEditCalorieEntry(
    EditCalorieEntry event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      // Update the entry using the repository
      final success = await _repository.updateCalorieEntry(
        event.id,
        event.foodItem,
        event.calories,
        protein: event.protein,
        carbs: event.carbs,
        fat: event.fat,
        quantity: event.quantity,
        unit: event.unit,
      );

      if (!success) {
        throw Exception('Failed to update calorie entry');
      }

      // Reload daily data
      final dailyData = await _repository.getDailyCalories(forceRefresh: true);

      // Extract values with proper type conversion
      final int totalCalories = _parseToInt(dailyData['totalCalories']);
      final double totalCarbs = _parseToDouble(dailyData['totalCarbs']);
      final double totalProtein = _parseToDouble(dailyData['totalProtein']);
      final double totalFat = _parseToDouble(dailyData['totalFat']);
      final List<dynamic> breakdownList = dailyData['breakdown'] ?? [];
      final List<dynamic> entries = dailyData['entries'] ?? [];

      emit(state.copyWith(
        status: CalorieStatus.loaded,
        totalCalories: totalCalories,
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        breakdown: breakdownList,
        entries: entries,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: 'Failed to edit calorie entry: $e',
      ));
    }
  }

  Future<void> _onDeleteCalorieEntry(
    DeleteCalorieEntry event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      // Delete the entry using the repository
      final success = await _repository.deleteCalorieEntry(event.id);

      if (!success) {
        throw Exception('Failed to delete calorie entry');
      }

      // Reload daily data
      final dailyData = await _repository.getDailyCalories(forceRefresh: true);

      // Extract values with proper type conversion
      final int totalCalories = _parseToInt(dailyData['totalCalories']);
      final double totalCarbs = _parseToDouble(dailyData['totalCarbs']);
      final double totalProtein = _parseToDouble(dailyData['totalProtein']);
      final double totalFat = _parseToDouble(dailyData['totalFat']);
      final List<dynamic> breakdownList = dailyData['breakdown'] ?? [];
      final List<dynamic> entries = dailyData['entries'] ?? [];

      emit(state.copyWith(
        status: CalorieStatus.loaded,
        totalCalories: totalCalories,
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        breakdown: breakdownList,
        entries: entries,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: 'Failed to delete calorie entry: $e',
      ));
    }
  }

  // Helper method to parse to int
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

  // Helper method to parse to double
  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }

    return 0.0;
  }

  // New method to fetch weekly calorie data
  Future<void> fetchWeeklyCalories() async {
    try {
      // Emit loading state to show the loading indicator
      emit(state.copyWith(status: CalorieStatus.loading));

      // Fetch weekly calories from the repository with force refresh to ensure fresh data
      final weeklyData =
          await _repository.getWeeklyCalories(forceRefresh: true);

      // Debug: Print the raw weekly data structure

      weeklyData.forEach((key, value) {
        if (key == 'entries') {
        } else {}
      });

      // Check if the data contains entries
      if (weeklyData['entries'] != null && weeklyData['entries'] is List) {
        final List<dynamic> entries = weeklyData['entries'];

        if (entries.isNotEmpty) {
          // Debug: Print the first entry structure

          final firstEntry = entries.first;
          if (firstEntry is Map) {
            firstEntry.forEach((key, value) {});
          } else {}
        }

        // Convert the entries to CalorieEntry objects
        final List<CalorieEntry> calorieEntries = entries.map((entry) {
          DateTime timestamp;
          try {
            if (entry['timestamp'] != null) {
              timestamp = DateTime.parse(entry['timestamp'].toString());
            } else {
              // If no timestamp, use current date with a random hour to distribute them
              final now = DateTime.now();
              timestamp =
                  DateTime(now.year, now.month, now.day, now.hour, now.minute);
            }
          } catch (e) {
            // If parsing fails, use current time as fallback
            timestamp = DateTime.now();
          }

          return CalorieEntry(
            id: entry['id']?.toString(),
            foodItem: entry['food_item'] ?? 'Unknown food',
            calories: _parseToInt(entry['calories']),
            protein:
                entry['protein'] != null ? _parseToInt(entry['protein']) : null,
            carbs: entry['carbs'] != null ? _parseToInt(entry['carbs']) : null,
            fat: entry['fat'] != null ? _parseToInt(entry['fat']) : null,
            quantity: entry['quantity'] != null
                ? _parseToDouble(entry['quantity'])
                : 1.0,
            unit: entry['unit'] ?? 'serving',
            timestamp: timestamp,
          );
        }).toList();

        // Debug: Display entries breakdown by day of week
        final Map<int, List<CalorieEntry>> entriesByDay = {};
        for (var i = 1; i <= 7; i++) {
          entriesByDay[i] = [];
        }

        for (var entry in calorieEntries) {
          final weekday = entry.timestamp.weekday;
          entriesByDay[weekday]?.add(entry);
        }

        final List<String> weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        for (var i = 1; i <= 7; i++) {
          final entries = entriesByDay[i] ?? [];
          int totalCalories = 0;
          for (var entry in entries) {
            totalCalories += entry.calories;
          }
        }

        // Emit the updated state with the weekly entries

        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: calorieEntries,
        ));
      } else {
        // Emit an empty state if no entries are found
        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: [],
        ));
      }
    } catch (e) {
      // Emit an error state if fetching fails
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Add this method to handle weekly data loading
  Future<void> _onLoadWeekly(
    LoadWeeklyCalories event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      final weeklyData =
          await _repository.getWeeklyCalories(forceRefresh: true);

      if (weeklyData['entries'] != null && weeklyData['entries'] is List) {
        final List<dynamic> entries = weeklyData['entries'];

        final List<CalorieEntry> calorieEntries = entries.map((entry) {
          DateTime timestamp;
          try {
            timestamp = entry['timestamp'] != null
                ? DateTime.parse(entry['timestamp'].toString())
                : DateTime.now();
          } catch (e) {
            timestamp = DateTime.now();
          }

          return CalorieEntry(
            id: entry['id']?.toString(),
            foodItem: entry['food_item'] ?? 'Unknown food',
            calories: _parseToInt(entry['calories']),
            protein:
                entry['protein'] != null ? _parseToInt(entry['protein']) : null,
            carbs: entry['carbs'] != null ? _parseToInt(entry['carbs']) : null,
            fat: entry['fat'] != null ? _parseToInt(entry['fat']) : null,
            quantity: entry['quantity'] != null
                ? _parseToDouble(entry['quantity'])
                : 1.0,
            unit: entry['unit'] ?? 'serving',
            timestamp: timestamp,
          );
        }).toList();

        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: calorieEntries,
          totalCalories: _parseToInt(weeklyData['total_calories']),
          totalCarbs: _parseToDouble(weeklyData['total_carbs']),
          totalProtein: _parseToDouble(weeklyData['total_protein']),
          totalFat: _parseToDouble(weeklyData['total_fat']),
        ));
      } else {
        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: [],
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMonthly(
    LoadMonthlyCalories event,
    Emitter<CalorieState> emit,
  ) async {
    try {
      emit(state.copyWith(status: CalorieStatus.loading));

      final monthlyData =
          await _repository.getMonthlyCalories(forceRefresh: true);

      if (monthlyData['entries'] != null && monthlyData['entries'] is List) {
        final List<dynamic> entries = monthlyData['entries'];

        final List<CalorieEntry> calorieEntries = entries.map((entry) {
          DateTime timestamp;
          try {
            timestamp = entry['timestamp'] != null
                ? DateTime.parse(entry['timestamp'].toString())
                : DateTime.now();
          } catch (e) {
            timestamp = DateTime.now();
          }

          return CalorieEntry(
            id: entry['id']?.toString(),
            foodItem: entry['food_item'] ?? 'Unknown food',
            calories: _parseToInt(entry['calories']),
            protein:
                entry['protein'] != null ? _parseToInt(entry['protein']) : null,
            carbs: entry['carbs'] != null ? _parseToInt(entry['carbs']) : null,
            fat: entry['fat'] != null ? _parseToInt(entry['fat']) : null,
            quantity: entry['quantity'] != null
                ? _parseToDouble(entry['quantity'])
                : 1.0,
            unit: entry['unit'] ?? 'serving',
            timestamp: timestamp,
          );
        }).toList();

        // Sort entries by date
        calorieEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Group entries by day and calculate daily totals
        final Map<DateTime, int> dailyTotals = {};
        for (var entry in calorieEntries) {
          final date = DateTime(
              entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
          dailyTotals[date] = (dailyTotals[date] ?? 0) + entry.calories;
        }

        // Print daily totals for debugging

        dailyTotals.forEach((date, calories) {});

        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: calorieEntries,
          totalCalories: _parseToInt(monthlyData['total_calories']),
          totalCarbs: _parseToDouble(monthlyData['total_carbs']),
          totalProtein: _parseToDouble(monthlyData['total_protein']),
          totalFat: _parseToDouble(monthlyData['total_fat']),
          dailyTotals: dailyTotals,
        ));
      } else {
        emit(state.copyWith(
          status: CalorieStatus.loaded,
          entries: [],
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CalorieStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}

bool _listEquals(List<dynamic> a, List<dynamic> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].toString() != b[i].toString()) return false;
  }
  return true;
}
