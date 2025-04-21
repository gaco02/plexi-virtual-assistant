import 'package:flutter/material.dart';
import 'dart:async';
import 'insights_screen.dart';
import 'package:vibration/vibration.dart';

class ChatWelcomeScreen extends StatefulWidget {
  const ChatWelcomeScreen({Key? key}) : super(key: key);

  @override
  State<ChatWelcomeScreen> createState() => _ChatWelcomeScreenState();
}

class _ChatWelcomeScreenState extends State<ChatWelcomeScreen> {
  bool _hasVibrationSupport = false;

  // Header text animation properties
  final String _headerText =
      "Track spending, calories, and more — just by texting Plexi.";
  String _visibleHeader = "";
  int _headerCharIndex = 0;
  bool _isHeaderComplete = false;

  // Chat bubbles
  bool _showUserBubble1 = false;
  bool _showPlexiBubble1 = false;
  bool _showUserBubble2 = false;
  bool _showPlexiBubble2 = false;
  bool _showNextButton = false;

  @override
  void initState() {
    super.initState();

    // Check if vibration is supported
    _checkVibrationSupport();

    // Start the header animation
    _startHeaderAnimation();
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

  void _startHeaderAnimation() {
    // Animate header text one character at a time
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_headerCharIndex < _headerText.length) {
        setState(() {
          _visibleHeader = _headerText.substring(0, _headerCharIndex + 1);
          _headerCharIndex++;
          _vibrateIfSupported(); // Vibrate with each new letter
        });
      } else {
        timer.cancel();
        _isHeaderComplete = true;

        // Start showing chat bubbles after header completes
        _startChatBubblesAnimation();
      }
    });
  }

  void _startChatBubblesAnimation() {
    // Show first user message
    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _showUserBubble1 = true;
      });

      // Show first Plexi response after 1 second
      Timer(const Duration(milliseconds: 1000), () {
        setState(() {
          _showPlexiBubble1 = true;
        });

        // Show second user message
        Timer(const Duration(milliseconds: 1000), () {
          setState(() {
            _showUserBubble2 = true;
          });

          // Show second Plexi response
          Timer(const Duration(milliseconds: 1000), () {
            setState(() {
              _showPlexiBubble2 = true;
              _showNextButton = true; // Show Next button after all bubbles
            });
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFfd7835),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header text that animates character by character
                  Text(
                    _visibleHeader,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 80),
                  // Chat bubbles appearing one after another
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_showUserBubble1)
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildUserBubble(
                                  "I spent \$100 on new shoes"),
                            ),
                          const SizedBox(height: 16),
                          if (_showPlexiBubble1)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _buildPlexiBubble(
                                  "Noted 🛍️ — total shopping is now \$300."),
                            ),
                          const SizedBox(height: 16),
                          if (_showUserBubble2)
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildUserBubble(
                                  "I just ate a tuna sandwich"),
                            ),
                          const SizedBox(height: 16),
                          if (_showPlexiBubble2)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _buildPlexiBubble(
                                  "Oh! you just ate 450 calories🥪"),
                            ),
                        ],
                      ),
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
                      MaterialPageRoute(builder: (context) => InsightsScreen()),
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

  // User message bubble with coral background
  Widget _buildUserBubble(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFA3333D), // Coral color for user messages
        borderRadius: BorderRadius.circular(20),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  // Plexi message bubble with cream background
  Widget _buildPlexiBubble(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E8A7), // Cream color for Plexi messages
        borderRadius: BorderRadius.circular(20),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }
}
