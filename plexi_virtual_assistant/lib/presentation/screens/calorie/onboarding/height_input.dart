import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../widgets/common/custom_text_field.dart';

class HeightInputPage extends StatefulWidget {
  final Function(double height) onHeightSubmitted;

  const HeightInputPage({
    Key? key,
    required this.onHeightSubmitted,
  }) : super(key: key);

  @override
  HeightInputPageState createState() => HeightInputPageState();
}

class HeightInputPageState extends State<HeightInputPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController heightController = TextEditingController();
  bool isNextButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    heightController.addListener(_updateNextButtonState);
  }

  @override
  void dispose() {
    heightController.removeListener(_updateNextButtonState);
    heightController.dispose();
    super.dispose();
  }

  void _updateNextButtonState() {
    setState(() {
      isNextButtonEnabled = heightController.text.trim().isNotEmpty;
    });
  }

  void submitForm() {
    if (heightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your height')),
      );
      return;
    }

    try {
      final height = double.parse(heightController.text.trim());
      if (height <= 0 || height > 250) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a valid height (1-250 cm)')),
        );
        return;
      }
      widget.onHeightSubmitted(height);
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
              'What is your height?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              hintText: 'Height (cm)',
              controller: heightController,
              keyboardType: TextInputType.number,
              fillColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
