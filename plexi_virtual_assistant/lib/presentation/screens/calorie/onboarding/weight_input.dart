import 'package:flutter/material.dart';
import '../../../widgets/common/custom_text_field.dart';

class WeightInputPage extends StatefulWidget {
  final Function(double weight) onWeightSubmitted;

  const WeightInputPage({
    Key? key,
    required this.onWeightSubmitted,
  }) : super(key: key);

  @override
  WeightInputPageState createState() => WeightInputPageState();
}

class WeightInputPageState extends State<WeightInputPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController weightController = TextEditingController();
  bool isNextButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    weightController.addListener(_updateNextButtonState);
  }

  @override
  void dispose() {
    weightController.removeListener(_updateNextButtonState);
    weightController.dispose();
    super.dispose();
  }

  void _updateNextButtonState() {
    setState(() {
      isNextButtonEnabled = weightController.text.trim().isNotEmpty;
    });
  }

  void submitForm() {
    if (weightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your weight')),
      );
      return;
    }

    try {
      final weight = double.parse(weightController.text.trim());
      if (weight <= 0 || weight > 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a valid weight (1-200 kg)')),
        );
        return;
      }
      widget.onWeightSubmitted(weight);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number')),
      );
    }
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
              'What is your weight?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              hintText: 'Weight (kg)',
              controller: weightController,
              keyboardType: TextInputType.number,
              fillColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
