import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/models/transaction.dart';

class TransactionChart extends StatelessWidget {
  final Map<TransactionCategory, double> categoryTotals;
  final double totalAmount;

  const TransactionChart({
    Key? key,
    required this.categoryTotals,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: _generateSections(),
              ),
            ),
            const Text(
              'Expenses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateSections() {
    // Example colors for up to 7 categories
    final colors = [
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
    ];

    return categoryTotals.entries.map((entry) {
      final index = TransactionCategory.values.indexOf(entry.key);
      final percentage = (entry.value / totalAmount) * 100;

      return PieChartSectionData(
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        value: entry.value,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
