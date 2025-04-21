import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _showNextButton = false;

  // Streaming text animation properties
  final String _headerText = 'Get Smart Insights';
  String _visibleHeader = '';
  int _headerCharIndex = 0;
  Timer? _headerTimer;

  @override
  void initState() {
    super.initState();
    _startHeaderAnimation();
  }

  void _startHeaderAnimation() {
    _headerTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_headerCharIndex < _headerText.length) {
        setState(() {
          _visibleHeader = _headerText.substring(0, _headerCharIndex + 1);
          _headerCharIndex++;
        });
      } else {
        timer.cancel();
        // Show the Next button after a short delay for a subtle effect
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

  @override
  void dispose() {
    _headerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfd7835),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      _visibleHeader,
                      style: const TextStyle(
                        color: Color(0xFF440d06),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/onboarding/monthly_spending.png',
                          height: 228,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/onboarding/todays_calories.png',
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                      MaterialPageRoute(builder: (context) => LoginScreen()),
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
}
