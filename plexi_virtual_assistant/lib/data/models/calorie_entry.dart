import 'package:uuid/uuid.dart';

/// A model class representing a single food item entry with calorie information
class CalorieEntry {
  /// Unique identifier for the entry
  final String id;

  /// Name of the food item
  final String foodItem;

  /// Calorie amount per serving
  final int calories;

  /// Protein amount in grams (optional)
  final int? protein;

  /// Carbohydrates amount in grams (optional)
  final int? carbs;

  /// Fat amount in grams (optional)
  final int? fat;

  /// Quantity consumed (e.g. 1, 2.5)
  final double quantity;

  /// Unit of measurement (e.g. "serving", "cup", "oz")
  final String unit;

  /// Timestamp when the entry was recorded
  final DateTime timestamp;

  /// Creates a new CalorieEntry with the given parameters
  /// If no ID is provided, a new UUID is generated
  CalorieEntry({
    String? id,
    required this.foodItem,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.quantity = 1.0,
    this.unit = "serving",
    DateTime? timestamp,
  })  : this.id = id ?? const Uuid().v4(),
        this.timestamp = timestamp ?? DateTime.now();

  /// Creates a copy of this CalorieEntry with the given field values replaced
  CalorieEntry copyWith({
    String? foodItem,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    double? quantity,
    String? unit,
    DateTime? timestamp,
  }) {
    return CalorieEntry(
      id: this.id, // ID remains the same for a copy
      foodItem: foodItem ?? this.foodItem,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Converts this CalorieEntry to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'food_item': foodItem,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,
      'unit': unit,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Converts this CalorieEntry to a JSON-compatible Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'food_item': foodItem,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates a CalorieEntry from a Map
  factory CalorieEntry.fromMap(Map<String, dynamic> map) {
    return CalorieEntry(
      id: map['id'] as String,
      foodItem: map['food_item'] as String,
      calories: map['calories'] as int,
      protein: map['protein'] as int?,
      carbs: map['carbs'] as int?,
      fat: map['fat'] as int?,
      quantity: map['quantity'] as double? ?? 1.0,
      unit: map['unit'] as String? ?? 'serving',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Gets the total calories accounting for quantity
  int get totalCalories => (calories * quantity).round();

  /// Gets the total protein accounting for quantity
  int? get totalProtein =>
      protein != null ? (protein! * quantity).round() : null;

  /// Gets the total carbs accounting for quantity
  int? get totalCarbs => carbs != null ? (carbs! * quantity).round() : null;

  /// Gets the total fat accounting for quantity
  int? get totalFat => fat != null ? (fat! * quantity).round() : null;

  @override
  String toString() {
    return 'CalorieEntry{id: $id, foodItem: $foodItem, calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, quantity: $quantity, unit: $unit, timestamp: $timestamp}';
  }
}
