import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final EdgeInsets padding;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFFB03A2E), // Default reddish color
    this.textColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Rounded button
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
            color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
