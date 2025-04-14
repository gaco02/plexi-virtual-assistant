import 'package:flutter/material.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_preferences.dart';

class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _salaryController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  Sex? _selectedSex;

  @override
  void initState() {
    final prefs = (context.read<PreferencesBloc>().state as PreferencesLoaded)
        .preferences;

    _nameController = TextEditingController(text: prefs.preferredName);
    _salaryController =
        TextEditingController(text: prefs.monthlySalary?.toString());
    _weightController =
        TextEditingController(text: prefs.currentWeight?.toString());
    _heightController = TextEditingController(text: prefs.height?.toString());
    _ageController = TextEditingController(text: prefs.age?.toString());
    _selectedSex = prefs.sex;

    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _savePreferences() {
    if (_formKey.currentState!.validate()) {
      final updatedPrefs = UserPreferences(
        preferredName: _nameController.text,
        monthlySalary: double.tryParse(_salaryController.text),
        currentWeight: double.tryParse(_weightController.text),
        height: double.tryParse(_heightController.text),
        age: int.tryParse(_ageController.text),
        sex: _selectedSex,
      );

      context.read<PreferencesBloc>().add(SavePreferences(updatedPrefs));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Preferences"),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(77),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInput("Preferred Name", _nameController),
                  _buildInput("Monthly Salary", _salaryController,
                      isNumber: true),
                  _buildInput("Current Weight", _weightController,
                      isNumber: true),
                  _buildInput("Height", _heightController, isNumber: true),
                  _buildInput("Age", _ageController, isNumber: true),
                  _buildSexDropdown(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(77),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _savePreferences,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child:
                          Text("Save", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38)),
        ),
        style: const TextStyle(color: Colors.white),
        validator: (value) =>
            value == null || value.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildSexDropdown() {
    return DropdownButtonFormField<Sex>(
      value: _selectedSex,
      decoration: const InputDecoration(
        labelText: "Sex",
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
      ),
      dropdownColor: Colors.grey[900],
      iconEnabledColor: Colors.white,
      style: const TextStyle(color: Colors.white),
      items: Sex.values.map((sex) {
        return DropdownMenuItem<Sex>(
          value: sex,
          child: Text(sex.toString().split('.').last),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedSex = val),
    );
  }
}
