import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetSummaryText extends StatelessWidget {
  final double? spentAmount;
  final double? totalBudget;
  final String period;
  final double titleFontSize;
  final double amountFontSize;
  final bool showPeriodTitle;
  final bool showComparisonText;
  
  const BudgetSummaryText({
    Key? key,
    this.spentAmount,
    this.totalBudget,
    this.period = 'Month',
    this.titleFontSize = 14.0,
    this.amountFontSize = 24.0,
    this.showPeriodTitle = true,
    this.showComparisonText = true,
  }) : assert(
         (!showPeriodTitle || spentAmount != null) && 
         (!showComparisonText || (spentAmount != null && totalBudget != null)),
         'spentAmount is required when showPeriodTitle is true, and both spentAmount and totalBudget are required when showComparisonText is true'
       ),
       super(key: key);

  // Format number with commas
  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,###.##');
    return formatter.format(amount);
  }

  String _getPeriodText() {
    switch (period) {
      case 'Today':
        return "Today's Spending";
      case 'Week':
        return "This Week's Spending";
      case 'Month':
        return "This Month's Spending";
      default:
        return "Current Spending";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period text - only show if showPeriodTitle is true
        if (showPeriodTitle) ...[
          Text(
            _getPeriodText(),
            style: TextStyle(
              color: Colors.white70,
              fontSize: titleFontSize,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Current period amount - only show if showPeriodTitle is true
        if (showPeriodTitle && spentAmount != null) ...[
          Text(
            "\$${_formatAmount(spentAmount!)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: amountFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Comparison text - only show if showComparisonText is true
        if (showComparisonText && spentAmount != null && totalBudget != null) ...[
          Text(
            '\$${_formatAmount(spentAmount!)} of \$${_formatAmount(totalBudget!)} spent',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}
