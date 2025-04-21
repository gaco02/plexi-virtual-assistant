import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';
import 'package:vibration/vibration.dart';
import 'chat_welcome_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _showDots = true;
  bool _showMaskot = false;
  bool _showNextButton = false;
  late Timer _timer;
  int _dotsCount = 0;

  // Text animation properties
  final String _greetingText = "Hi, I'm Plexi";
  final String _subtitleText = "Your AI assistant";
  String _visibleGreeting = "";
  String _visibleSubtitle = "";
  bool _hasVibrationSupport = false;
  int _greetingCharIndex = 0;
  int _subtitleCharIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkVibrationSupport();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_dotsCount < 3) {
          _dotsCount++;
        } else {
          _showDots = false;
          _timer.cancel();
          // Start streaming text animation after dots
          _startTextAnimation();
        }
      });
    });
  }

  Future<void> _checkVibrationSupport() async {
    try {
      _hasVibrationSupport = await Vibration.hasVibrator() ?? false;
    } catch (e) {
      _hasVibrationSupport = false;
    }
  }

  void _vibrateIfSupported() {
    if (_hasVibrationSupport) {
      // Short, subtle vibration for each letter
      Vibration.vibrate(duration: 10, amplitude: 20);
    }
  }

  void _startTextAnimation() {
    // Animate greeting text one character at a time
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_greetingCharIndex < _greetingText.length) {
        setState(() {
          _visibleGreeting = _greetingText.substring(0, _greetingCharIndex + 1);
          _greetingCharIndex++;
        });
      } else {
        timer.cancel();
        // Start subtitle animation after greeting completes
        Timer.periodic(const Duration(milliseconds: 60), (timer) {
          if (_subtitleCharIndex < _subtitleText.length) {
            setState(() {
              _visibleSubtitle =
                  _subtitleText.substring(0, _subtitleCharIndex + 1);
              _subtitleCharIndex++;
            });
          } else {
            timer.cancel();
            // Show mascot after text animation completes
            setState(() {
              _showMaskot = true;
            });
            // Show Next button after mascot appears
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() {
                  _showNextButton = true;
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfd7835),
      body: SafeArea(
        child: Stack(
          children: [
            // Centered content (dots or greeting/subtitle/mascot)
            Center(
              child: _showDots
                  ? _buildDots()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _visibleGreeting,
                          style: const TextStyle(
                            color: Color(0xFF440d06),
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _visibleSubtitle,
                          style: const TextStyle(
                            color: Color(0xFF440d06),
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        if (_showMaskot)
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 1000),
                            child: Image.asset(
                              'assets/images/onboarding/plexi_white_maskot.png',
                              width: 150,
                              height: 150,
                            ),
                          ),
                      ],
                    ),
            ),
            // Bottom right Next button
            if (_showNextButton)
              Positioned(
                bottom: 32,
                right: 24,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => ChatWelcomeScreen()),
                    );
                  },
                  child: const Text(
                    'Next',
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
    );
  }

  Widget _buildDots() {
    String dots = '';
    for (int i = 0; i < _dotsCount; i++) {
      dots += '•';
    }

    return Text(
      dots,
      style: const TextStyle(
        color: Color.fromARGB(255, 252, 252,
            252), // Orange color similar to the maskot chat bubble
        fontSize: 40,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
