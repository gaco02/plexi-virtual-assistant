import 'package:flutter/material.dart';

class BudgetCategoryChart extends StatelessWidget {
  final double needs;
  final double needsTarget;
  final double wants;
  final double wantsTarget;
  final double savings;
  final double savingsTarget;
  final double barHeight;
  final Color needsColor;
  final Color wantsColor;
  final Color savingsColor;
  final Color backgroundColor;

  const BudgetCategoryChart({
    Key? key,
    required this.needs,
    required this.needsTarget,
    required this.wants,
    required this.wantsTarget,
    required this.savings,
    required this.savingsTarget,
    this.barHeight = 8.0,
    this.needsColor = Colors.blue,
    this.wantsColor = Colors.purple,
    this.savingsColor = Colors.green,
    this.backgroundColor = Colors.white24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Needs
        _buildCategoryItem('Needs', needs, needsTarget, needsColor),
        const SizedBox(height: 12),
        
        // Wants
        _buildCategoryItem('Wants', wants, wantsTarget, wantsColor),
        const SizedBox(height: 12),
        
        // Savings
        _buildCategoryItem('Savings', savings, savingsTarget, savingsColor),
      ],
    );
  }

  Widget _buildCategoryItem(String label, double value, double target, Color color) {
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
          '\$${value.round()}/\$${target.round()}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double value, double target, Color color) {
    final double progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
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
