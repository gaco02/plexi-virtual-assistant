import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../widgets/common/custom_text_field.dart';

class AgeInputPage extends StatefulWidget {
  final Function(int age) onAgeSubmitted;

  const AgeInputPage({
    Key? key,
    required this.onAgeSubmitted,
  }) : super(key: key);

  @override
  AgeInputPageState createState() => AgeInputPageState();
}

class AgeInputPageState extends State<AgeInputPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController ageController = TextEditingController();

  /// Validate and submit the form. The parent screen calls this when the user taps "Next."
  void submitForm() {
    // Manual validation since CustomTextField doesn't support validator
    if (ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your age')),
      );
      return;
    }

    try {
      final age = int.parse(ageController.text.trim());
      if (age <= 0 || age > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid age (1-120)')),
        );
        return;
      }
      widget.onAgeSubmitted(age);
    } catch (e) {
      // Handle parsing error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number')),
      );
    }
  }

  @override
  void dispose() {
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'What\'s your age?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            // Age input field (visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomTextField(
                hintText: 'Age',
                controller: ageController,
                keyboardType: TextInputType.number,
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 8),
            // Any additional instructions or spacing can go here
          ],
        ),
      ),
    );
  }
}
