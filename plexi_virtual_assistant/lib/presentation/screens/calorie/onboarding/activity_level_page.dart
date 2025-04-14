import 'package:flutter/material.dart';
import 'package:plexi_virtual_assistant/data/models/user_preferences.dart';

class ActivityLevelPage extends StatefulWidget {
  final Function(ActivityLevel) onActivityLevelSelected;

  const ActivityLevelPage({
    Key? key,
    required this.onActivityLevelSelected,
  }) : super(key: key);

  @override
  State<ActivityLevelPage> createState() => ActivityLevelPageState();
}

class ActivityLevelPageState extends State<ActivityLevelPage> {
  ActivityLevel selectedLevel = ActivityLevel.moderatelyActive;

  /// The parent can call this when the user taps "Next" to finalize selection.
  void submitActivityLevel() {
    widget.onActivityLevelSelected(selectedLevel);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Prevents bottom overflow by making the content scrollable.
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your activity level',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select your typical activity level to help us calculate your daily calorie needs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                _buildActivityOption(
                  ActivityLevel.sedentary,
                  'Sedentary',
                  'Little or no exercise',
                ),
                _buildActivityOption(
                  ActivityLevel.lightlyActive,
                  'Lightly active',
                  'Light exercise 1-3 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.moderatelyActive,
                  'Moderately active',
                  'Moderate exercise 3-5 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.veryActive,
                  'Very active',
                  'Hard exercise 6-7 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.extraActive,
                  'Extra active',
                  'Very hard exercise & physical job',
                ),
              ],
            ),
            const SizedBox(height: 32),
            // No "Continue" button here.
            // We rely on the parent's Next button, which calls submitActivityLevel().
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOption(
    ActivityLevel level,
    String title,
    String description,
  ) {
    final isSelected = selectedLevel == level;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedLevel = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Radio<ActivityLevel>(
                value: level,
                groupValue: selectedLevel,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedLevel = value;
                    });
                  }
                },
                activeColor: Colors.blue,
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
