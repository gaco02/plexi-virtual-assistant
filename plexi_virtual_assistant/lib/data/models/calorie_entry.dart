class CalorieEntry {
  final String? id; 
  final String foodItem;
  final int calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final double quantity;
  final String unit;
  final DateTime timestamp;

  CalorieEntry({
    this.id, 
    required this.foodItem,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.quantity = 1.0,
    this.unit = 'serving',
    required this.timestamp,
  });

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

  factory CalorieEntry.fromJson(Map<String, dynamic> json) {
    return CalorieEntry(
      id: json['id']?.toString(), 
      foodItem: json['food_item'],
      calories: json['calories'],
      protein: json['protein'],
      carbs: json['carbs'],
      fat: json['fat'],
      quantity: json['quantity']?.toDouble() ?? 1.0,
      unit: json['unit'] ?? 'serving',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
