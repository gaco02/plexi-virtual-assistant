import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // A single dark color or a subtle two-color gradient
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 0, 1, 3), // Dark Navy
            Color.fromARGB(255, 1, 1, 1), // Slightly Lighter Navy
          ],
        ),
      ),
      // Ensure the container fills the available space
      constraints:
          const BoxConstraints.expand(), // Added to fill the available space
      child: child,
    );
  }
}
