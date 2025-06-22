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
  bool _isLoading = false;

  void _updateName(String value) {
    setState(() {
      _name = value;
      _canProceed = _name.trim().isNotEmpty;
    });
  }

  void _saveAndProceed(BuildContext context) {
    if (_name.trim().isEmpty) return;

    print('DEBUG: _saveAndProceed called with name: "${_name.trim()}"');

    setState(() {
      _isLoading = true;
    });

    final preferences = UserPreferences(preferredName: _name.trim());
    print(
        'DEBUG: Created UserPreferences with name: ${preferences.preferredName}');

    context.read<PreferencesBloc>().add(SavePreferences(preferences));
    print('DEBUG: SavePreferences event added to bloc');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        print('DEBUG: NameWelcomeScreen received state: ${state.runtimeType}');
        if (state is PreferencesLoaded) {
          print(
              'DEBUG: PreferencesLoaded with name: ${state.preferences.preferredName}');
          // Only navigate if we have a valid name and we're currently loading
          if (state.preferences.preferredName != null &&
              state.preferences.preferredName!.isNotEmpty &&
              _isLoading) {
            print('DEBUG: Navigating to HomeScreen');
            setState(() {
              _isLoading = false;
            });
            // Use pushAndRemoveUntil to prevent back navigation to this screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        } else if (state is PreferencesError) {
          print('DEBUG: PreferencesError: ${state.message}');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving preferences: ${state.message}'),
              backgroundColor: Colors.red,
            ),
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
                    backgroundColor: _canProceed && !_isLoading
                        ? Colors.white.withOpacity(0.2)
                        : Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (_canProceed && !_isLoading)
                      ? () => _saveAndProceed(context)
                      : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
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
