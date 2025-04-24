import 'package:flutter/material.dart';
import '../../../widgets/common/custom_text_field.dart';

// Enum for weight units
enum WeightUnit { kg, lb }

class WeightInputPage extends StatefulWidget {
  final Function(double weightInKg)
      onWeightSubmitted; // Ensure callback expects kg

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
  WeightUnit _selectedUnit = WeightUnit.kg; // Default unit

  // Conversion factor
  static const double _kgToLb = 2.20462;
  static const double _lbToKg = 1 / _kgToLb;

  // Validation ranges
  static const double _minKg = 1.0;
  static const double _maxKg = 200.0;
  static const double _minLb = _minKg * _kgToLb;
  static const double _maxLb = _maxKg * _kgToLb;

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
      final weightInput = double.parse(weightController.text.trim());
      double weightInKg;
      String unitString = _selectedUnit == WeightUnit.kg ? 'kg' : 'lb';
      double minWeight = _selectedUnit == WeightUnit.kg ? _minKg : _minLb;
      double maxWeight = _selectedUnit == WeightUnit.kg ? _maxKg : _maxLb;

      if (weightInput <= 0 ||
          weightInput < minWeight ||
          weightInput > maxWeight) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Please enter a valid weight (${minWeight.toStringAsFixed(1)}-${maxWeight.toStringAsFixed(1)} $unitString)')),
        );
        return;
      }

      if (_selectedUnit == WeightUnit.lb) {
        weightInKg = weightInput * _lbToKg; // Convert lb to kg
      } else {
        weightInKg = weightInput;
      }

      widget.onWeightSubmitted(weightInKg); // Submit weight in kg
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
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    hintText:
                        'Weight (${_selectedUnit == WeightUnit.kg ? 'kg' : 'lb'})',
                    controller: weightController,
                    keyboardType: TextInputType.numberWithOptions(
                        decimal: true), // Allow decimal input
                    fillColor: Colors.transparent,
                  ),
                ),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: [
                    _selectedUnit == WeightUnit.kg,
                    _selectedUnit == WeightUnit.lb,
                  ],
                  onPressed: (int index) {
                    setState(() {
                      _selectedUnit =
                          index == 0 ? WeightUnit.kg : WeightUnit.lb;
                      // Optional: Clear input or convert existing input when unit changes
                      // weightController.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(30.0),
                  selectedColor: Colors.white,
                  color: Colors.white.withOpacity(0.7),
                  fillColor: Theme.of(context).primaryColor.withOpacity(0.5),
                  selectedBorderColor: Theme.of(context).primaryColor,
                  borderColor: Colors.white.withOpacity(0.5),
                  children: const <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('kg'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('lb'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
