import 'package:flutter/material.dart';
import '../common/transparent_card.dart';

class MacroStatsCard extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double proteinTarget;
  final double carbsTarget;
  final double fatTarget;

  const MacroStatsCard({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.proteinTarget = 100,
    this.carbsTarget = 200,
    this.fatTarget = 70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Macronutrients',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroStat('Protein', protein.round(), 'g', Colors.orange,
                  proteinTarget),
              _buildMacroStat(
                  'Carbs', carbs.round(), 'g', Colors.teal, carbsTarget),
              _buildMacroStat(
                  'Fats', fat.round(), 'g', Colors.purple, fatTarget),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(
      String label, int value, String unit, Color color, double target) {
    final double percentage = value / target;
    final double progressValue = percentage > 1.0 ? 1.0 : percentage;
    final int displayPercentage = (percentage * 100).round();

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey[300],
                color: color,
                strokeWidth: 8,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value$unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$displayPercentage%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
