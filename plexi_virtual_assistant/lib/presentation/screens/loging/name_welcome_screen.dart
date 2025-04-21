import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../data/models/user_preferences.dart';
import '../../widgets/common/custom_text_field.dart';
import '../home/home_screen.dart';

class NameWelcomeScreen extends StatefulWidget {
  const NameWelcomeScreen({Key? key}) : super(key: key);

  @override
  State<NameWelcomeScreen> createState() => _NameWelcomeScreenState();
}

class _NameWelcomeScreenState extends State<NameWelcomeScreen> {
  String _name = '';
  bool _canProceed = false;

  void _updateName(String value) {
    setState(() {
      _name = value;
      _canProceed = _name.trim().isNotEmpty;
    });
  }

  void _saveAndProceed(BuildContext context) {
    final preferences = UserPreferences(preferredName: _name.trim());
    context.read<PreferencesBloc>().add(SavePreferences(preferences));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        if (state is PreferencesLoaded && _canProceed) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (state is PreferencesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFfd7835),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'What is your name?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        hintText: 'Name',
                        onChanged: _updateName,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                right: 24,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _canProceed ? () => _saveAndProceed(context) : null,
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
