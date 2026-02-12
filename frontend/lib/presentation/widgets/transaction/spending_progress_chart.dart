import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'budget_pie_chart.dart';
import 'budget_summary_text.dart';

class SpendingProgressChart extends StatelessWidget {
  final double todaySpent;
  final double monthlySpent;
  final double weeklySpent;
  final double monthlyBudget;
  final Color progressColor;
  final Color backgroundColor;
  final double height;
  final String period;
  final double chartSize;
  final double centerFontSize;
  final double labelFontSize;
  final bool showPeriodText;

  const SpendingProgressChart({
    Key? key,
    required this.todaySpent,
    required this.monthlySpent,
    required this.weeklySpent,
    required this.monthlyBudget,
    required this.period,
    this.progressColor = const Color(0xFF7C4DFF),
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.height = 8.0,
    this.chartSize = 250.0,
    this.centerFontSize = 36.0,
    this.labelFontSize = 16.0,
    this.showPeriodText = true,
  }) : super(key: key);

  double _getCurrentPeriodAmount() {
    switch (period) {
      case 'Today':
        return todaySpent;
      case 'Week':
        return weeklySpent;
      case 'Month':
        return monthlySpent;
      default:
        return todaySpent;
    }
  }

  // Format number with commas
  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount.round());
  }

  @override
  Widget build(BuildContext context) {
    // Handle edge cases for budget
    if (monthlyBudget <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget not set',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: BudgetPieChart(
              // Use the new BudgetPieChart widget
              spentAmount: monthlySpent,
              totalBudget: monthlyBudget,
              chartSize: 200,
              centerFontSize: 24,
              labelFontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '\$${_formatAmount(monthlySpent)} spent this month',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      );
    }

    final currentPeriodAmount = _getCurrentPeriodAmount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period text and amount using BudgetSummaryText
        if (showPeriodText)
          BudgetSummaryText(
            spentAmount: currentPeriodAmount,
            totalBudget: monthlyBudget,
            period: period,
            titleFontSize: 14.0,
            amountFontSize: 24.0,
            showPeriodTitle: true,
            showComparisonText: false,
          ),

        // Pie chart with amount left inside
        Center(
          child: BudgetPieChart(
            // Use the new BudgetPieChart widget
            spentAmount: monthlySpent,
            totalBudget: monthlyBudget,
            chartSize: chartSize,
            centerFontSize: centerFontSize,
            labelFontSize: labelFontSize,
          ),
        ),
        const SizedBox(height: 16),

        // Monthly spent amount text
        Center(
          child: BudgetSummaryText(
            spentAmount: monthlySpent,
            totalBudget: monthlyBudget,
            period: period,
            titleFontSize: 14.0,
            amountFontSize: 24.0,
            showPeriodTitle: false,
            showComparisonText: true,
          ),
        ),
      ],
    );
  }
}
