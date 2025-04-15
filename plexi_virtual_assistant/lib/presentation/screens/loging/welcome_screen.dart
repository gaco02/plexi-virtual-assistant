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
  late Timer _timer;
  int _dotsCount = 0;

  // Text animation properties
  final String _greetingText = "Hi, I'm Plexi";
  final String _subtitleText = "Your AI assistant";
  String _visibleGreeting = "";
  String _visibleSubtitle = "";
  int _greetingCharIndex = 0;
  int _subtitleCharIndex = 0;
  bool _isGreetingComplete = false;
  bool _isSubtitleComplete = false;
  bool _hasVibrationSupport = false;

  @override
  void initState() {
    super.initState();

    // Check if vibration is supported
    _checkVibrationSupport();

    // Start the dots animation sequence
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        if (_dotsCount < 3) {
          _dotsCount++;
        } else {
          _showDots = false;
          _timer.cancel();

          // Start text animation after dots complete
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
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_greetingCharIndex < _greetingText.length) {
        setState(() {
          _visibleGreeting = _greetingText.substring(0, _greetingCharIndex + 1);
          _greetingCharIndex++;
          _vibrateIfSupported(); // Vibrate with each new letter
        });
      } else {
        timer.cancel();
        _isGreetingComplete = true;

        // Start subtitle animation after greeting completes
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (_subtitleCharIndex < _subtitleText.length) {
            setState(() {
              _visibleSubtitle =
                  _subtitleText.substring(0, _subtitleCharIndex + 1);
              _subtitleCharIndex++;
              _vibrateIfSupported(); // Vibrate with each new letter
            });
          } else {
            timer.cancel();
            _isSubtitleComplete = true;

            // Show maskot after text animation completes
            setState(() {
              _showMaskot = true;
            });

            // Navigate to LoginScreen after 2 seconds of showing the final state
            Timer(const Duration(milliseconds: 2000), () {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => ChatWelcomeScreen()),
                );
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_showDots) _buildDots() else _buildContent(),
            ],
          ),
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
        color:
            Color(0xFFFAA61A), // Orange color similar to the maskot chat bubble
        fontSize: 40,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Text(
          _visibleGreeting,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _visibleSubtitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 40),
        if (_showMaskot)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 800),
            child: Image.asset(
              'assets/images/common/plexi_maskot1.png',
              width: 80,
              height: 80,
            ),
          ),
      ],
    );
  }
}
