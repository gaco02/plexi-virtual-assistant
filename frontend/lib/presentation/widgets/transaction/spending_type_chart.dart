import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/models/transaction.dart';

class SpendingTypeChart extends StatelessWidget {
  final Map<TransactionCategory, double> categoryTotals;
  final double totalAmount;

  const SpendingTypeChart({
    Key? key,
    required this.categoryTotals,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate totals for needs, wants, and savings
    final spendingTypeTotals = _calculateSpendingTypeTotals();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.5,
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
                    sections: _generateSections(spendingTypeTotals),
                  ),
                ),
                const Text(
                  'Spending Types',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildLegend(spendingTypeTotals),
      ],
    );
  }

  Widget _buildLegend(Map<String, double> spendingTypeTotals) {
    // Fixed colors for needs, wants, and savings
    final colors = {
      'needs': Colors.blue,
      'wants': Colors.orange,
      'savings': Colors.green,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: spendingTypeTotals.entries.map((entry) {
          final percentage =
              totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0;
          final color = colors[entry.key] ?? Colors.grey;

          return Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.key.substring(0, 1).toUpperCase()}${entry.key.substring(1)}: ${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Map<String, double> _calculateSpendingTypeTotals() {
    final spendingTypeTotals = <String, double>{
      'needs': 0.0,
      'wants': 0.0,
      'savings': 0.0,
    };

    categoryTotals.forEach((category, amount) {
      final spendingType = category.spendingType;
      spendingTypeTotals[spendingType] =
          (spendingTypeTotals[spendingType] ?? 0) + amount;
    });

    return spendingTypeTotals;
  }

  List<PieChartSectionData> _generateSections(
      Map<String, double> spendingTypeTotals) {
    // Fixed colors for needs, wants, and savings
    final colors = {
      'needs': Colors.blue,
      'wants': Colors.orange,
      'savings': Colors.green,
    };

    return spendingTypeTotals.entries.map((entry) {
      final percentage =
          totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0;

      return PieChartSectionData(
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[entry.key] ?? Colors.grey,
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
