import 'package:flutter/material.dart';
import '../common/transparent_card.dart';

// Define NutritionStatus enum for the UI
enum NutritionStatus {
  good,
  warning,
  bad,
}

// Map to store emojis for each nutrition goal type
Map<String, String> nutritionEmojis = {
  'Calorie Goal': '🔥 ',
  'Protein Goal': '💪 ',
  'Carbs Goal': '🍚 ',
  'Fat Goal': '🥑 ',
};

NutritionStatus determineStatus(double percentage) {
  if (percentage >= 90 && percentage <= 110) {
    return NutritionStatus.good;
  } else if ((percentage >= 75 && percentage < 90) ||
      (percentage > 110 && percentage <= 125)) {
    return NutritionStatus.warning;
  } else {
    return NutritionStatus.bad;
  }
}

class NutritionGoalCard extends StatelessWidget {
  final String title;
  final String value;
  final NutritionStatus status;
  final double percentage;

  const NutritionGoalCard({
    Key? key,
    required this.title,
    required this.value,
    required this.status,
    required this.percentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case NutritionStatus.good:
        statusColor = Colors.green;
        break;
      case NutritionStatus.warning:
        statusColor = Color(0xFFfd7835);
        break;
      case NutritionStatus.bad:
        statusColor = Colors.red;
        break;
    }

    // Get emoji for the title or use empty string if not found
    final emoji = nutritionEmojis[title] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                emoji + title,
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.round()}% of goal',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionGoalsSection extends StatelessWidget {
  final String title;
  final List<NutritionGoalCard> goals;

  const NutritionGoalsSection({
    Key? key,
    required this.title,
    required this.goals,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TransparentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...goals.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: goal,
            );
          }).toList(),
        ],
      ),
    );
  }
}
