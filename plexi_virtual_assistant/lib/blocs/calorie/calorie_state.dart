import 'package:equatable/equatable.dart';
import '../../utils/nutrition_calculator.dart';

enum CalorieStatus { initial, loading, loaded, error }

class CalorieState extends Equatable {
  final CalorieStatus status;
  final int totalCalories;
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;
  final List<dynamic> breakdown;
  final int calorieGoal;
  final NutritionPlan? nutritionPlan;
  final String? errorMessage;
  final List<dynamic> entries;
  final Map<DateTime, int>? dailyTotals;

  const CalorieState({
    this.status = CalorieStatus.initial,
    this.totalCalories = 0,
    this.totalCarbs = 0,
    this.totalProtein = 0,
    this.totalFat = 0,
    this.breakdown = const [],
    this.calorieGoal = 2000,
    this.nutritionPlan,
    this.errorMessage,
    this.entries = const [],
    this.dailyTotals,
  });

  @override
  List<Object?> get props => [
        status,
        totalCalories,
        totalCarbs,
        totalProtein,
        totalFat,
        breakdown,
        calorieGoal,
        nutritionPlan,
        errorMessage,
        entries,
        dailyTotals,
      ];

  CalorieState copyWith({
    CalorieStatus? status,
    int? totalCalories,
    double? totalCarbs,
    double? totalProtein,
    double? totalFat,
    List<dynamic>? breakdown,
    int? calorieGoal,
    NutritionPlan? nutritionPlan,
    String? errorMessage,
    List<dynamic>? entries,
    Map<DateTime, int>? dailyTotals,
  }) {
    return CalorieState(
      status: status ?? this.status,
      totalCalories: totalCalories ?? this.totalCalories,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalProtein: totalProtein ?? this.totalProtein,
      totalFat: totalFat ?? this.totalFat,
      breakdown: breakdown ?? this.breakdown,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      nutritionPlan: nutritionPlan ?? this.nutritionPlan,
      errorMessage: errorMessage ?? this.errorMessage,
      entries: entries ?? this.entries,
      dailyTotals: dailyTotals ?? this.dailyTotals,
    );
  }
}

class CalorieInitial extends CalorieState {
  CalorieInitial() : super(status: CalorieStatus.initial);
}

// These classes can be removed as they're now handled by the status field
// Keeping them for backward compatibility
class CalorieLoading extends CalorieState {
  CalorieLoading() : super(status: CalorieStatus.loading);
}

class CaloriesLoaded extends CalorieState {
  CaloriesLoaded(
    int totalCalories, {
    double totalCarbs = 0,
    double totalProtein = 0,
    double totalFat = 0,
    Map<String, dynamic> breakdown = const {},
  }) : super(
          status: CalorieStatus.loaded,
          totalCalories: totalCalories,
          totalCarbs: totalCarbs,
          totalProtein: totalProtein,
          totalFat: totalFat,
          breakdown: breakdown.entries
              .map((e) => {'item': e.key, 'calories': e.value})
              .toList(),
        );
}

class CaloriesError extends CalorieState {
  CaloriesError(String message)
      : super(status: CalorieStatus.error, errorMessage: message);
}
