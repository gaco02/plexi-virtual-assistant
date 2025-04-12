import 'package:equatable/equatable.dart';
import '../../data/models/calorie_entry.dart';

abstract class CalorieEvent extends Equatable {
  const CalorieEvent();

  @override
  List<Object?> get props => [];
}

class LoadDailyCalories extends CalorieEvent {
  final bool forceRefresh;

  const LoadDailyCalories({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class UpdateCaloriesFromChat extends CalorieEvent {
  final int totalCalories;
  final Map<String, dynamic>? foodInfo;
  final List<dynamic>? breakdown;

  const UpdateCaloriesFromChat({
    required this.totalCalories,
    this.foodInfo,
    this.breakdown,
  });

  @override
  List<Object?> get props => [totalCalories, foodInfo, breakdown];
}

class AddCalorieEntry extends CalorieEvent {
  final CalorieEntry entry;

  const AddCalorieEntry(this.entry);

  @override
  List<Object?> get props => [entry];
}

class UpdateCalorieGoal extends CalorieEvent {
  final int calorieGoal;

  const UpdateCalorieGoal(this.calorieGoal);

  @override
  List<Object?> get props => [calorieGoal];
}

class EditCalorieEntry extends CalorieEvent {
  final String id;
  final String foodItem;
  final int calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final double quantity;
  final String unit;

  const EditCalorieEntry({
    required this.id,
    required this.foodItem,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.quantity = 1.0,
    this.unit = 'serving',
  });

  @override
  List<Object?> get props =>
      [id, foodItem, calories, protein, carbs, fat, quantity, unit];
}

class DeleteCalorieEntry extends CalorieEvent {
  final String id;

  const DeleteCalorieEntry(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadWeeklyCalories extends CalorieEvent {
  const LoadWeeklyCalories();

  @override
  List<Object?> get props => [];
}

class LoadMonthlyCalories extends CalorieEvent {
  const LoadMonthlyCalories();

  @override
  List<Object?> get props => [];
}
