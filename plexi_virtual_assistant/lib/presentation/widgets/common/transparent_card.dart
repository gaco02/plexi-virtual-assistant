import 'package:flutter/material.dart';

class TransparentCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;
  final VoidCallback? onTap;
  final double? width; // <-- Optional width
  final double? height; // <-- Optional height
  final EdgeInsetsGeometry? margin; // <-- Optional margin
  final EdgeInsetsGeometry? padding; // <-- Optional padding

  const TransparentCard({
    Key? key,
    required this.child,
    this.borderRadius = 35.0,
    this.opacity = 0.1,
    this.onTap,
    this.width,
    this.height,
    this.margin,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Colors.white.withAlpha(10),
        highlightColor: Colors.white.withAlpha(10),
        child: Container(
          width: width,
          height: height,
          margin:
              margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            // border: Border.all(color: const Color.fromARGB(255, 38, 38, 38)),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
