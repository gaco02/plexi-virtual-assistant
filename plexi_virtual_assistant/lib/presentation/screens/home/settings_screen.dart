import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:plexi_virtual_assistant/presentation/screens/home/edit_preference_screen.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../widgets/common/app_background.dart';
import '../../../data/models/user_preferences.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Future<UserPreferences> userPreferencesFuture;

  const SettingsScreen({Key? key, required this.userPreferencesFuture})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _tempValue;
  final NumberFormat currencyFormat =
      NumberFormat.currency(symbol: "\$"); // Currency Formatter

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        extendBodyBehindAppBar: true,
        body: AppBackground(
          child: SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildUserPreferencesSection(),
                          const SizedBox(height: 16),
                          _buildLogoutButton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPreferencesSection() {
    return BlocBuilder<PreferencesBloc, PreferencesState>(
      builder: (context, state) {
        if (state is! PreferencesLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final prefs = state.preferences;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreferenceRow(
                      context,
                      "Preferred Name",
                      prefs.preferredName ?? "Not set",
                      prefs.preferredName,
                      'preferredName'),
                  _buildPreferenceRow(
                      context,
                      "Monthly Salary",
                      prefs.monthlySalary != null
                          ? currencyFormat.format(prefs.monthlySalary)
                          : "Not set",
                      prefs.monthlySalary,
                      'monthlySalary'),
                  _buildPreferenceRow(
                      context,
                      "Current Weight",
                      prefs.currentWeight?.toStringAsFixed(1) ?? "Not set",
                      prefs.currentWeight,
                      'currentWeight'),
                  _buildPreferenceRow(
                      context,
                      "Height",
                      prefs.height?.toStringAsFixed(1) ?? "Not set",
                      prefs.height,
                      'height'),
                  _buildPreferenceRow(context, "Age",
                      prefs.age?.toString() ?? "Not set", prefs.age, 'age'),
                  _buildPreferenceRow(
                      context,
                      "Sex",
                      prefs.sex != null
                          ? prefs.sex.toString().split('.').last
                          : "Not set",
                      prefs.sex,
                      'sex'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("Edit Preferences",
                    style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditPreferencesScreen()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreferenceRow(BuildContext context, String title, String value,
      dynamic currentValue, String field) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(color: Colors.white70, fontSize: 16)),
      trailing: Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      onTap: () => _editPreference(context, title, currentValue, field),
    );
  }

  void _editPreference(
      BuildContext context, String title, dynamic currentValue, String field) {
    // For sex field, show a dropdown instead of a text field
    if (field == 'sex') {
      _showSexSelectionDialog(context, currentValue);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Edit $title', style: const TextStyle(color: Colors.white)),
        content: TextFormField(
          initialValue: currentValue?.toString() ?? '',
          style: const TextStyle(color: Colors.white),
          keyboardType: field == 'preferredName'
              ? TextInputType.text
              : TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter $title',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          onChanged: (value) => _tempValue = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.read<PreferencesBloc>().state is PreferencesLoaded) {
                final currentPrefs =
                    (context.read<PreferencesBloc>().state as PreferencesLoaded)
                        .preferences;

                // Properly handle type conversion for each field
                dynamic convertedValue;
                if (_tempValue == null || _tempValue!.isEmpty) {
                  convertedValue = null;
                } else {
                  switch (field) {
                    case 'preferredName':
                      convertedValue = _tempValue;
                      break;
                    case 'age':
                      convertedValue = int.tryParse(_tempValue!);
                      break;
                    case 'monthlySalary':
                    case 'currentWeight':
                    case 'height':
                      convertedValue = double.tryParse(_tempValue!);
                      break;
                  }
                }

                final updatedPrefs = currentPrefs.copyWith(
                  preferredName: field == 'preferredName'
                      ? convertedValue
                      : currentPrefs.preferredName,
                  monthlySalary: field == 'monthlySalary'
                      ? convertedValue
                      : currentPrefs.monthlySalary,
                  currentWeight: field == 'currentWeight'
                      ? convertedValue
                      : currentPrefs.currentWeight,
                  height:
                      field == 'height' ? convertedValue : currentPrefs.height,
                  age: field == 'age' ? convertedValue : currentPrefs.age,
                );
                context
                    .read<PreferencesBloc>()
                    .add(SavePreferences(updatedPrefs));

                // Also save to SharedPreferences for the transaction repository
                if (field == 'monthlySalary' && convertedValue != null) {
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setDouble('monthly_salary', convertedValue);
                  });
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSexSelectionDialog(BuildContext context, Sex? currentSex) {
    Sex selectedSex = currentSex ?? Sex.other;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Sex', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: Sex.values.map((sex) {
                return RadioListTile<Sex>(
                  title: Text(
                    sex.toString().split('.').last,
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: sex,
                  groupValue: selectedSex,
                  onChanged: (value) {
                    setState(() {
                      selectedSex = value!;
                    });
                  },
                  activeColor: Colors.blue,
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.read<PreferencesBloc>().state is PreferencesLoaded) {
                final currentPrefs =
                    (context.read<PreferencesBloc>().state as PreferencesLoaded)
                        .preferences;

                final updatedPrefs = currentPrefs.copyWith(
                  sex: selectedSex,
                );
                context
                    .read<PreferencesBloc>()
                    .add(SavePreferences(updatedPrefs));
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Logout button with a glassmorphic effect
  Widget _buildLogoutButton(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ListTile(
          onTap: () => _showLogoutDialog(context),
          leading: const Icon(Icons.logout, color: Colors.white),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white),
          ),
          tileColor: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(SignOutRequested());
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
