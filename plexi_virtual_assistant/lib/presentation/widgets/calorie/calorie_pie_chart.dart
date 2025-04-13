import 'package:flutter/material.dart';
import '../common/metric_pie_chart.dart';

class CaloriePieChart extends StatelessWidget {
  final double consumedCalories;
  final double targetCalories;
  final double chartSize;
  final double centerFontSize;
  final double labelFontSize;
  final Color consumedColor;
  final Color remainingColor;
  final bool showPercentage;

  const CaloriePieChart({
    Key? key,
    required this.consumedCalories,
    required this.targetCalories,
    this.chartSize = 200.0,
    this.centerFontSize = 36.0,
    this.labelFontSize = 16.0,
    this.consumedColor = Colors.green,
    this.remainingColor = const Color(0xFFEEEEEE),
    this.showPercentage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug incoming values

    // Calculate percentage of target reached
    final double percentage = targetCalories > 0
        ? (consumedCalories / targetCalories * 100).clamp(0, 100).toDouble()
        : 0.0;

    // Choose color based on percentage
    final Color progressColor = _getProgressColor(percentage);

    // Create a custom center widget with icon and text
    final Widget centerWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Food icon
        const Text(
          '⚡️',
          style: TextStyle(
            fontSize: 30.0,
          ),
        ),
        const SizedBox(height: 4),
        // Consumed calories
        Text(
          '${consumedCalories} cal',
          style: TextStyle(
            color: Colors.white,
            fontSize: centerFontSize * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
        // "of" text
        Text(
          'of ${targetCalories}',
          style: TextStyle(
            color: Colors.white70,
            fontSize: labelFontSize,
          ),
        ),
      ],
    );

    // Use the generic MetricPieChart component
    return MetricPieChart(
      currentValue: consumedCalories.toDouble(), // Convert int to double
      targetValue: targetCalories.toDouble(), // Convert int to double
      chartSize: chartSize,
      centerFontSize: centerFontSize,
      labelFontSize: labelFontSize,
      primaryColor: progressColor,
      secondaryColor: remainingColor,
      metricLabel: 'Calories',
      valueSuffix: ' cal',
      showPercentage: showPercentage,
      centerWidget: centerWidget,
    );
  }

  // Helper method to determine color based on percentage
  Color _getProgressColor(double percentage) {
    if (percentage < 50) {
      return Colors.green; // Under 50% - Good progress
    } else if (percentage < 85) {
      return Colors.orange; // Between 50-85% - Moderate progress
    } else {
      return Colors.red; // Over 85% - Approaching limit
    }
  }
}

// Macronutrient pie chart for showing protein/carbs/fat breakdown
class MacronutrientPieChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double chartSize;
  final double centerFontSize;
  final double labelFontSize;
  final bool showPercentage;

  const MacronutrientPieChart({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.chartSize = 250.0,
    this.centerFontSize = 24.0,
    this.labelFontSize = 14.0,
    this.showPercentage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure all values are properly converted to double first
    final double proteinValue = protein.toDouble();
    final double carbsValue = carbs.toDouble();
    final double fatValue = fat.toDouble();

    final double total = proteinValue + carbsValue + fatValue;

    // If there's no data, show a placeholder
    if (total <= 0) {
      return SizedBox(
        width: chartSize,
        height: chartSize,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Calculate percentages as doubles without rounding to avoid precision loss
    final double proteinPercentage =
        total > 0 ? (proteinValue / total * 100) : 0.0;
    final double carbsPercentage = total > 0 ? (carbsValue / total * 100) : 0.0;
    final double fatPercentage = total > 0 ? (fatValue / total * 100) : 0.0;

    // Custom center widget showing macronutrient breakdown
    final Widget centerWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Macros',
          style: TextStyle(
            fontSize: labelFontSize,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem('P', Colors.orange, proteinPercentage),
            const SizedBox(width: 8),
            _buildLegendItem('C', Colors.teal, carbsPercentage),
            const SizedBox(width: 8),
            _buildLegendItem('F', Colors.purple, fatPercentage),
          ],
        ),
      ],
    );

    // Use the MetricPieChart with custom sections for macronutrients
    return MetricPieChart(
      currentValue: 100.0, // We're showing percentages, so this is always 100.0
      targetValue: 100.0, // Explicitly use 100.0 to ensure double is used
      chartSize: chartSize,
      centerFontSize: centerFontSize,
      labelFontSize: labelFontSize,
      primaryColor: Colors.transparent, // Not used with custom sections
      secondaryColor: Colors.transparent, // Not used with custom sections
      centerWidget: centerWidget,
    );
  }

  // Helper method to build a legend item
  Widget _buildLegendItem(String label, Color color, double percentage) {
    // Ensure safe conversion to int by using toInt()
    final int percentInt = percentage.toInt();

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '$label: ${percentInt}%', // Use the safely converted int value
          style: TextStyle(
            fontSize: labelFontSize * 0.8,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
