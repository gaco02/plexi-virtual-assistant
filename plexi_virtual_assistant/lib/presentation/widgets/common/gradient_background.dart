import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedDarkGradient(child: child);
  }
}

class _AnimatedDarkGradient extends StatefulWidget {
  final Widget child;
  const _AnimatedDarkGradient({required this.child});

  @override
  State<_AnimatedDarkGradient> createState() => _AnimatedDarkGradientState();
}

class _AnimatedDarkGradientState extends State<_AnimatedDarkGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _color1 = ColorTween(
      begin: const Color.fromARGB(255, 1, 28, 70), // deep navy
      end: Colors.white, // soft white
    ).animate(_controller);

    _color2 = ColorTween(
      begin: const Color(0xFF2C2C2E), // dark gray-blue
      end: Colors.white, // soft white
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Background remains dark
            Container(color: Colors.black),

            // Subtle animated glowing circles
            Positioned(
              top: -60,
              left: -40,
              child: _buildAnimatedBlob(_color1.value!, 200),
            ),
            Positioned(
              top: 100,
              right: -50,
              child: _buildAnimatedBlob(_color2.value!, 180),
            ),
            Positioned(
              bottom: 80,
              left: -30,
              child: _buildAnimatedBlob(_color1.value!, 220),
            ),
            Positioned(
              top: 100,
              right: -40,
              child: _buildAnimatedBlob(_color1.value!, 200),
            ),
            Positioned(
              top: 100,
              right: -50,
              child: _buildAnimatedBlob(_color2.value!, 180),
            ),
            Positioned(
              bottom: 60,
              left: -10,
              child: _buildAnimatedBlob(_color1.value!, 220),
            ),
            // Your content
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildAnimatedBlob(Color color, double size) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withOpacity(0.2), Colors.transparent],
            radius: 0.85,
          ),
        ),
      ),
    );
  }
}
