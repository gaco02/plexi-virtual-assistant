import 'package:flutter/material.dart';
import 'package:plexi_virtual_assistant/data/models/user_preferences.dart';

/// Choose gender
class SexSelectionPage extends StatefulWidget {
  final Function(Sex) onSexSelected;

  const SexSelectionPage({
    Key? key,
    required this.onSexSelected,
  }) : super(key: key);

  @override
  State<SexSelectionPage> createState() => SexSelectionPageState();
}

class SexSelectionPageState extends State<SexSelectionPage> {
  Sex? selectedSex;

  void submitForm() {
    if (selectedSex != null) {
      widget.onSexSelected(selectedSex!);
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
            'How should I personalize your plan?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          const Text(
            'This helps me calculate your calorie needs more accurately.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGenderOption(
                Sex.female,
                'Female',
                isSelected: selectedSex == Sex.female,
              ),
              const SizedBox(width: 16),
              _buildGenderOption(
                Sex.male,
                'Male',
                isSelected: selectedSex == Sex.male,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPreferNotToSayOption(
            isSelected: selectedSex == Sex.other,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGenderOption(Sex sex, String label, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSex = sex;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withAlpha(77) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              sex == Sex.female ? Icons.female : Icons.male,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferNotToSayOption({required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSex = Sex.other;
        });
      },
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withAlpha(77) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: const Center(
          child: Text(
            'Prefer not to say',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
