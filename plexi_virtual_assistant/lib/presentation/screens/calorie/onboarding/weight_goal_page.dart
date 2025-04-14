import 'package:flutter/material.dart';
import 'package:plexi_virtual_assistant/data/models/user_preferences.dart';

class WeightGoalPage extends StatefulWidget {
  final Function(WeightGoal) onWeightGoalSelected;

  const WeightGoalPage({
    Key? key,
    required this.onWeightGoalSelected,
  }) : super(key: key);

  @override
  State<WeightGoalPage> createState() => WeightGoalPageState();
}

class WeightGoalPageState extends State<WeightGoalPage> {
  WeightGoal? _selectedGoal;

  void submitForm() {
    if (_selectedGoal != null) {
      widget.onWeightGoalSelected(_selectedGoal!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What goal do you have in mind?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          const Text(
            'This will help us calculate your optimal calorie and macronutrient targets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          _buildGoalOption(
            WeightGoal.lose,
            'Lose Weight',
            'Create a calorie deficit to lose weight',
            '🥗',
          ),
          const SizedBox(height: 16),
          _buildGoalOption(
            WeightGoal.maintain,
            'Maintain Weight',
            'Stay at your current weight',
            '⚖️',
          ),
          const SizedBox(height: 16),
          _buildGoalOption(
            WeightGoal.gain,
            'Gain Weight',
            'Create a calorie surplus to gain weight',
            '🍗',
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOption(
    WeightGoal goal,
    String title,
    String description,
    String emoji,
  ) {
    final isSelected = _selectedGoal == goal;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goal;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withAlpha(77)
              : Colors
                  .black26, // Updated to use withAlpha instead of withOpacity
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? Colors.orange
                : const Color.fromARGB(
                    255, 245, 177, 87), // Added contour for unselected buttons
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 4),
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
    );
  }

  // Widget _buildGoalOption(
  //   WeightGoal goal,
  //   String title,
  //   String description,
  //   IconData icon,
  // ) {
  //   final isSelected = _selectedGoal == goal;
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         _selectedGoal = goal;
  //       });
  //     },
  //     child: Container(
  //       width: double.infinity,
  //       margin: const EdgeInsets.symmetric(vertical: 8),
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(
  //         color: isSelected ? Colors.blue.withAlpha(77) : Colors.black26,
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(
  //           color: isSelected ? Colors.blue : Colors.white70,
  //           width: 2,
  //         ),
  //       ),
  //       child: Row(
  //         children: [
  //           Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: Colors.blue.withAlpha(77),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(
  //               icon,
  //               color: Colors.white,
  //               size: 24,
  //             ),
  //           ),
  //           const SizedBox(width: 16),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: const TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 4),
  //                 Text(
  //                   description,
  //                   style: const TextStyle(
  //                     color: Colors.white70,
  //                     fontSize: 14,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
