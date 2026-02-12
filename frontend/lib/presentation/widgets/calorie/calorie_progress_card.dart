import 'package:flutter/material.dart';
import '../common/transparent_card.dart';

class CalorieProgressCard extends StatelessWidget {
  final int currentCalories;
  final int targetCalories;
  final bool showTarget;
  final Color progressColor;

  const CalorieProgressCard({
    Key? key,
    required this.currentCalories,
    this.targetCalories = 0,
    this.showTarget = true,
    this.progressColor = Colors.green,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showProgress = targetCalories > 0 && showTarget;
    final isOverTarget = currentCalories > targetCalories;
    final actualProgressColor = isOverTarget ? Colors.red : progressColor;

    return TransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '$currentCalories cal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            Text(
              'of $targetCalories cal',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: targetCalories > 0 ? currentCalories / targetCalories : 0,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(actualProgressColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
  }
}
