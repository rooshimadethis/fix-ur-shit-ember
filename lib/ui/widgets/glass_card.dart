import 'package:flutter/material.dart';

/// A reusable frosted glass card used for control sections and widgets.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
