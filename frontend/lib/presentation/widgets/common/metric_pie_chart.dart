import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MetricPieChart extends StatelessWidget {
  final double currentValue;
  final double targetValue;
  final double chartSize;
  final double centerFontSize;
  final double labelFontSize;
  final Color primaryColor;
  final Color secondaryColor;
  final String metricLabel;
  final String valuePrefix;
  final String valueSuffix;
  final bool showFormatting;
  final bool showPercentage;
  final Widget? centerWidget;

  const MetricPieChart({
    Key? key,
    required this.currentValue,
    required this.targetValue,
    this.chartSize = 250.0,
    this.centerFontSize = 36.0,
    this.labelFontSize = 16.0,
    this.primaryColor = Colors.red,
    this.secondaryColor = const Color(0xFFEEEEEE),
    this.metricLabel = 'Current',
    this.valuePrefix = '',
    this.valueSuffix = '',
    this.showFormatting = true,
    this.showPercentage = false,
    this.centerWidget,
  }) : super(key: key);

  // Format number with commas
  String _formatValue(double value) {
    if (showFormatting) {
      final formatter = NumberFormat('#,###');
      return formatter.format(value.round());
    } else {
      return value.round().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (currentValue / targetValue).clamp(0.0, 1.0);
    final usedPercentage = progress * 100;
    final remainingPercentage = 100 - usedPercentage;

    return SizedBox(
      width: chartSize,
      height: chartSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: chartSize * 0.35,
              startDegreeOffset: 270,
              sections: [
                PieChartSectionData(
                  color: primaryColor,
                  value: usedPercentage,
                  title: '',
                  radius: chartSize * 0.08,
                  showTitle: false,
                ),
                PieChartSectionData(
                  color: secondaryColor,
                  value: remainingPercentage,
                  title: '',
                  radius: chartSize * 0.08,
                  showTitle: false,
                ),
              ],
            ),
          ),
          centerWidget ?? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metricLabel,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: Colors.white70,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$valuePrefix${_formatValue(currentValue)}$valueSuffix',
                    style: TextStyle(
                      fontSize: centerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (showPercentage) 
                    Text(
                      ' ${usedPercentage.round()}%',
                      style: TextStyle(
                        fontSize: centerFontSize * 0.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
