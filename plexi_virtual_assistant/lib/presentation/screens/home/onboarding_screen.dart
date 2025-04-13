import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_preferences.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../widgets/common/gradient_background.dart';
import '../chat_screen.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart'; // Import the button widget

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  UserPreferences _preferences = UserPreferences();
  int _currentPage = 0;
  bool _canProceed = false;
  late final List<Widget> _pages;

  void _validatePreferences() {
    setState(() {
      _canProceed = _preferences.preferredName != null &&
          _preferences.preferredName!.isNotEmpty;
    });
  }

  void _updateName(String value) {
    setState(() {
      _preferences = _preferences.copyWith(preferredName: value);
      _validatePreferences();
    });
  }

  @override
  void initState() {
    super.initState();

    _pages = [
      _WelcomePage(onNext: () {
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }),
      _NamePage(onNameChanged: _updateName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        if (state is PreferencesLoaded && _canProceed) {
          if (_currentPage == _pages.length - 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          }
        } else if (state is PreferencesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) {
                      setState(() => _currentPage = page);
                    },
                    children: _pages,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        CustomButton(
                          text: 'Back',
                          color: Colors.transparent, // Transparent button
                          textColor: Colors.white,
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      const Spacer(),
                      CustomButton(
                        text: _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                        color: Colors.red, // Button color
                        onPressed: _currentPage == 0
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : _canProceed
                                ? () {
                                    context.read<PreferencesBloc>().add(
                                          SavePreferences(_preferences),
                                        );
                                  }
                                : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hi, I\'m Plexi!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          const _TypewriterText(
            text: 'Your Personal Assistant to Beat Overwhelm',
            textStyle: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontFamily: 'Roboto',
            ),
            duration: Duration(milliseconds: 500),
          ),
          const SizedBox(height: 100),
          const _TypewriterText(
            text: 'One assistant. Less overwhelm. More life.',
            textStyle: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontFamily: 'Roboto',
            ),
            duration: Duration(milliseconds: 500),
          ),
        ],
      ),
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final Duration duration;

  const _TypewriterText({
    required this.text,
    required this.textStyle,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  String _visibleText = '';
  int _charIndex = 0;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _visibleText = widget.text.substring(0, _charIndex);
        });
      } else {
        _ticker.stop();
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _visibleText,
      style: widget.textStyle,
      textAlign: TextAlign.center,
    );
  }
}

class _NamePage extends StatelessWidget {
  final Function(String) onNameChanged;
  const _NamePage({required this.onNameChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What is your name?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          SizedBox(height: 16),
          CustomTextField(
            hintText: 'Name',
            onChanged: onNameChanged,
          ),
        ],
      ),
    );
  }
}

class _SalaryPage extends StatelessWidget {
  final Function(String) onSalaryChanged;
  const _SalaryPage({required this.onSalaryChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What is your monthly salary?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          SizedBox(height: 16),
          CustomTextField(
            hintText: 'Enter your monthly salary',
            onChanged: onSalaryChanged,
            fillColor: Colors.white24, // Adjust color if needed
          ),
        ],
      ),
    );
  }
}

class _WeightDetailsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What are your weight details?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          const CustomTextField(
            hintText: 'Current weight (kg)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          const CustomTextField(
            hintText: 'Target weight (kg)',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
