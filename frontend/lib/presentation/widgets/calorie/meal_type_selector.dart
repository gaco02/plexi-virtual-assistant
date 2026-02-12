import 'package:flutter/material.dart';

class MealTypeSelector extends StatelessWidget {
  final String selectedMeal;
  final Function(String) onMealSelected;
  final List<String> mealTypes;

  const MealTypeSelector({
    Key? key,
    required this.selectedMeal,
    required this.onMealSelected,
    this.mealTypes = const ['Breakfast', 'Lunch', 'Dinner'],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: mealTypes.map((mealType) {
          final isSelected = selectedMeal == mealType;

          return GestureDetector(
            onTap: () => onMealSelected(mealType),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withAlpha(77)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Text(
                mealType,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
