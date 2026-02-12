import 'package:flutter/material.dart';
import '../common/metric_pie_chart.dart';

class BudgetPieChart extends StatelessWidget {
  final double spentAmount;
  final double totalBudget;
  final double chartSize;
  final double centerFontSize;
  final double labelFontSize;
  final Color spentColor;
  final Color remainingColor;

  const BudgetPieChart({
    Key? key,
    required this.spentAmount,
    required this.totalBudget,
    this.chartSize = 250.0,
    this.centerFontSize = 36.0,
    this.labelFontSize = 16.0,
    this.spentColor = Colors.amber,
    this.remainingColor = const Color(0xFFEEEEEE),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use the new MetricPieChart component
    return MetricPieChart(
      currentValue: spentAmount,
      targetValue: totalBudget,
      chartSize: chartSize,
      centerFontSize: centerFontSize,
      labelFontSize: labelFontSize,
      primaryColor: spentColor,
      secondaryColor: remainingColor,
      metricLabel: '💵',
      valuePrefix: '\$',
      showFormatting: true,
    );
  }
}
