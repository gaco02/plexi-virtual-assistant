import 'package:flutter/material.dart';
import '../../../widgets/common/custom_text_field.dart';

// Enum for height units
enum HeightUnit { cm, ft }

class HeightInputPage extends StatefulWidget {
  final Function(double heightInCm)
      onHeightSubmitted; // Ensure callback expects cm

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
  HeightUnit _selectedUnit = HeightUnit.cm; // Default unit

  // Conversion factors
  static const double _cmToFt = 0.0328084;
  static const double _ftToCm = 1 / _cmToFt;

  // Validation ranges (adjust as needed)
  static const double _minCm = 50.0;
  static const double _maxCm = 250.0;
  static const double _minFt = _minCm * _cmToFt;
  static const double _maxFt = _maxCm * _cmToFt;

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
      final heightInput = double.parse(heightController.text.trim());
      double heightInCm;
      String unitString = _selectedUnit == HeightUnit.cm ? 'cm' : 'ft';
      double minHeight = _selectedUnit == HeightUnit.cm ? _minCm : _minFt;
      double maxHeight = _selectedUnit == HeightUnit.cm ? _maxCm : _maxFt;

      if (heightInput <= 0 ||
          heightInput < minHeight ||
          heightInput > maxHeight) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Please enter a valid height (${minHeight.toStringAsFixed(1)}-${maxHeight.toStringAsFixed(1)} $unitString)')),
        );
        return;
      }

      if (_selectedUnit == HeightUnit.ft) {
        heightInCm = heightInput * _ftToCm; // Convert ft to cm
      } else {
        heightInCm = heightInput;
      }

      widget.onHeightSubmitted(heightInCm); // Submit height in cm
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
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    hintText:
                        'Height (${_selectedUnit == HeightUnit.cm ? 'cm' : 'ft'})',
                    controller: heightController,
                    keyboardType: TextInputType.numberWithOptions(
                        decimal: true), // Allow decimal input
                    fillColor: Colors.transparent,
                  ),
                ),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: [
                    _selectedUnit == HeightUnit.cm,
                    _selectedUnit == HeightUnit.ft,
                  ],
                  onPressed: (int index) {
                    setState(() {
                      _selectedUnit =
                          index == 0 ? HeightUnit.cm : HeightUnit.ft;
                      // Optional: Clear input or convert existing input when unit changes
                      // heightController.clear();
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
                      child: Text('cm'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('ft'),
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
