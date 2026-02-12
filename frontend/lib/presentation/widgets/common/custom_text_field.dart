import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType; // ✅ Ensure this is added
  final Color fillColor;

  const CustomTextField({
    Key? key,
    this.hintText = 'Enter text',
    this.controller,
    this.onChanged,
    this.keyboardType = TextInputType.text, // ✅ Default value set
    this.fillColor = Colors.grey, // Default background color
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType, // ✅ Pass keyboardType to TextField
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: false, // No background fill
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      onChanged: onChanged,
      textInputAction: TextInputAction.done,
    );
  }
}
