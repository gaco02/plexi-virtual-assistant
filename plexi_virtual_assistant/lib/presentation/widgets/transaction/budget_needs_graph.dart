import 'package:flutter/material.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../../utils/formatting_utils.dart';

class BudgetGraphWidget extends StatelessWidget {
  final TransactionAllocation actual;
  final TransactionAllocation ideal;

  const BudgetGraphWidget({
    Key? key,
    required this.actual,
    required this.ideal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBudgetBar(
          'Needs (50%)',
          actual.needs,
          ideal.needs,
          Colors.blue,
          context,
        ),
        _buildBudgetBar(
          'Wants (30%)',
          actual.wants,
          ideal.wants,
          Colors.orange,
          context,
        ),
        _buildBudgetBar(
          'Savings (20%)',
          actual.savings,
          ideal.savings,
          Colors.green,
          context,
        ),
      ],
    );
  }

  Widget _buildBudgetBar(String label, double actual, double target,
      Color color, BuildContext context) {
    final percentage = target > 0 ? (actual / target).clamp(0.0, 2.0) : 0.0;
    final isOverBudget = percentage > 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '${FormattingUtils.formatCurrency(actual)} / ${FormattingUtils.formatCurrency(target)}',
              style: TextStyle(
                color: isOverBudget ? Colors.red : Colors.white70,
                fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage > 1.0 ? 1.0 : percentage, // Cap at 100% for visual
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOverBudget ? Colors.red : color,
          ),
          borderRadius: BorderRadius.circular(12),
          minHeight: 12,
        ),
        Text(
          isOverBudget
              ? '${(percentage * 100).toStringAsFixed(1)}% of budget (Over budget!)'
              : '${(percentage * 100).toStringAsFixed(1)}% of budget',
          style: TextStyle(
            color: isOverBudget ? Colors.red : Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
