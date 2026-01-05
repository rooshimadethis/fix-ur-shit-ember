import 'dart:math';
import 'package:flutter/material.dart';

class LiquidFillBackground extends StatefulWidget {
  final double fillLevel; // Target fill level (0.0 to 1.0)
  final Color baseColor; // Target base color

  const LiquidFillBackground({
    super.key,
    required this.fillLevel,
    required this.baseColor,
  });

  @override
  State<LiquidFillBackground> createState() => _LiquidFillBackgroundState();
}

class _LiquidFillBackgroundState extends State<LiquidFillBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use TweenAnimationBuilder to smoothly interpolate values
    // to match the 1000ms EaseInOut timing of the other UI elements.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: widget.fillLevel, end: widget.fillLevel),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, animatedFill, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: widget.baseColor, end: widget.baseColor),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          builder: (context, animatedColor, _) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return RepaintBoundary(
                  child: CustomPaint(
                    painter: _WavePainter(
                      progress: _controller.value,
                      fillLevel: animatedFill,
                      color: animatedColor ?? Colors.blue,
                    ),
                    child: Container(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double fillLevel;
  final Color color;

  _WavePainter({
    required this.progress,
    required this.fillLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0.001) return;

    final double height = size.height;
    final double width = size.width;

    // Cap visual level at 95% so waves are always visible at the top
    final double visualFillLevel = fillLevel * 0.98;
    final double baseHeight = height * (1 - visualFillLevel);

    // Static wave height
    final double waveHeight = 15.0;

    // First Wave (Back)
    final backPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final backPath = Path();
    backPath.moveTo(0, baseHeight);

    for (double i = 0; i <= width; i++) {
      backPath.lineTo(
        i,
        baseHeight +
            sin((i / width * 2 * pi) + (progress * 2 * pi)) * waveHeight,
      );
    }
    backPath.lineTo(width, height);
    backPath.lineTo(0, height);
    backPath.close();
    canvas.drawPath(backPath, backPaint);

    // Second Wave (Front)
    final frontPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    frontPath.moveTo(0, baseHeight);

    for (double i = 0; i <= width; i++) {
      frontPath.lineTo(
        i,
        baseHeight +
            cos((i / width * 2 * pi) - (progress * 2 * pi)) *
                (waveHeight * 0.7),
      );
    }
    frontPath.lineTo(width, height);
    frontPath.lineTo(0, height);
    frontPath.close();
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillLevel != fillLevel ||
        oldDelegate.color != color;
  }
}
