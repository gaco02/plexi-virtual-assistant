import 'package:flutter/material.dart';

class MacronutrientBarChart extends StatelessWidget {
  final double protein;
  final double proteinTarget;
  final double carbs;
  final double carbsTarget;
  final double fat;
  final double fatTarget;
  final double barHeight;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final Color backgroundColor;

  const MacronutrientBarChart({
    Key? key,
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbsTarget,
    required this.fat,
    required this.fatTarget,
    this.barHeight = 8.0,
    this.proteinColor = Colors.green,
    this.carbsColor = Colors.amber,
    this.fatColor = Colors.red,
    this.backgroundColor = Colors.white24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Protein
        _buildMacroItem('Protein', protein, proteinTarget, proteinColor),
        const SizedBox(height: 12),

        // Fats
        _buildMacroItem('Fats', fat, fatTarget, fatColor),
        const SizedBox(height: 12),

        // Carbs
        _buildMacroItem('Carbs', carbs, carbsTarget, carbsColor),
      ],
    );
  }

  Widget _buildMacroItem(
      String label, double value, double target, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _buildProgressBar(value, target, color),
        const SizedBox(height: 2),
        Text(
          '${value.round()}/${target.round()}g',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double value, double target, Color color) {
    final double progress = (value / target).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: barHeight,
        width: double.infinity,
        color: backgroundColor,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
