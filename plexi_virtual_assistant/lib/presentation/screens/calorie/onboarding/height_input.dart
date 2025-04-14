import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  double sliderValue = 170.0; // Default height in cm

  void submitForm() {
    if (formKey.currentState?.validate() ?? false) {
      final height = double.parse(heightController.text);
      widget.onHeightSubmitted(height);
    } else {
      widget.onHeightSubmitted(sliderValue);
    }
  }

  @override
  void initState() {
    super.initState();
    heightController.text = sliderValue.toString();
  }

  @override
  void dispose() {
    heightController.dispose();
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
              'What is your height?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            // Height unit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'cm',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            // Display slider value
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  sliderValue.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.blue.withOpacity(0.3),
                valueIndicatorColor: Colors.blue,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                showValueIndicator: ShowValueIndicator.always,
              ),
              child: Slider(
                min: 120,
                max: 220,
                divisions: 100,
                label: sliderValue.toStringAsFixed(0),
                value: sliderValue,
                onChanged: (value) {
                  setState(() {
                    sliderValue = value;
                    heightController.text = value.toStringAsFixed(0);
                  });
                },
              ),
            ),
            // Markers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('120', style: TextStyle(color: Colors.white54)),
                  Text('145', style: TextStyle(color: Colors.white54)),
                  Text('170', style: TextStyle(color: Colors.white54)),
                  Text('195', style: TextStyle(color: Colors.white54)),
                  Text('220', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Hidden text form for validation
            Opacity(
              opacity: 0,
              child: TextFormField(
                controller: heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
