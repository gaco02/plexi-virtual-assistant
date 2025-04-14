import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  double sliderValue = 70.0; // Default weight in kg

  void submitForm() {
    // Always use the slider value since we removed the text input
    widget.onWeightSubmitted(sliderValue);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
          // Weight unit (kg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'kg',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          // Display the slider value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.2),
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
              min: 40,
              max: 200,
              divisions: 160,
              label: sliderValue.toStringAsFixed(0),
              value: sliderValue,
              onChanged: (value) {
                setState(() {
                  sliderValue = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
