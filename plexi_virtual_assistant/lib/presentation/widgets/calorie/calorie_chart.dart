import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/models/calorie_entry.dart';

class CalorieChart extends StatelessWidget {
  final List<CalorieEntry> entries;

  // Maximum number of points to render to prevent memory issues
  final int maxPoints;

  const CalorieChart({
    super.key,
    required this.entries,
    this.maxPoints = 15, // Default to 15 points max
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Sort entries by timestamp (oldest first for chart)
    final sortedEntries = List<CalorieEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Limit the number of entries to prevent memory issues
    final limitedEntries = sortedEntries.length > maxPoints
        ? _sampleEntries(sortedEntries, maxPoints)
        : sortedEntries;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= limitedEntries.length) {
                    return const SizedBox.shrink();
                  }

                  // Only show a few labels to prevent overcrowding
                  if (limitedEntries.length <= 5 ||
                      value == 0 ||
                      value == limitedEntries.length - 1 ||
                      value % (limitedEntries.length ~/ 3) == 0) {
                    final entry = limitedEntries[value.toInt()];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('h:mm a').format(entry.timestamp),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(limitedEntries.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  limitedEntries[index].calories.toDouble(),
                );
              }),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: limitedEntries.length <
                    10, // Only show dots if we have few points
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: Colors.blue,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final entry = limitedEntries[spot.x.toInt()];
                  return LineTooltipItem(
                    '${entry.calories} cal\n${DateFormat('h:mm a').format(entry.timestamp)}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  // Sample entries evenly across the time range to reduce memory usage
  List<CalorieEntry> _sampleEntries(
      List<CalorieEntry> sortedEntries, int maxCount) {
    if (sortedEntries.length <= maxCount) {
      return sortedEntries;
    }

    final result = <CalorieEntry>[];
    final step = sortedEntries.length / maxCount;

    // Always include first and last entry
    result.add(sortedEntries.first);

    // Sample entries in the middle
    for (int i = 1; i < maxCount - 1; i++) {
      final index = (i * step).round();
      if (index < sortedEntries.length) {
        result.add(sortedEntries[index]);
      }
    }

    // Add the last entry if we have enough entries
    if (sortedEntries.length > 1) {
      result.add(sortedEntries.last);
    }

    return result;
  }
}
