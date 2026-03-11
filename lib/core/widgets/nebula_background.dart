import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A premium, cinematic background that feels like a living nebula.
/// Uses multiple shifting radial gradients to create depth and movement.
class NebulaBackground extends StatefulWidget {
  final Color? baseColor;
  const NebulaBackground({super.key, this.baseColor});

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor ?? AppColors.deepIndigo;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NebulaPainter(
            progress: _controller.value,
            color: color,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _NebulaPainter extends CustomPainter {
  final double progress;
  final Color color;

  _NebulaPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Draw base dark background
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.backgroundLight);

    // Layer 1: The Deep Glow (Slow, Large)
    _drawCloud(
      canvas, size, paint,
      centerOffset: Offset(
        size.width * 0.5 + math.sin(progress * 2 * math.pi) * 100,
        size.height * 0.3 + math.cos(progress * 2 * math.pi) * 100,
      ),
      radius: size.width * 1.2,
      colors: [
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.0),
      ],
    );

    // Layer 2: The Secondary Hue (Faster, Medium)
    _drawCloud(
      canvas, size, paint,
      centerOffset: Offset(
        size.width * 0.2 + math.cos(progress * 4 * math.pi) * 150,
        size.height * 0.7 + math.sin(progress * 4 * math.pi) * 150,
      ),
      radius: size.width * 0.8,
      colors: [
        const Color(0xFF4AC7FA).withValues(alpha: 0.12), // Electric Blue
        const Color(0xFF4AC7FA).withValues(alpha: 0.0),
      ],
    );

    // Layer 3: The Pulse (Fast, Small)
    _drawCloud(
      canvas, size, paint,
      centerOffset: Offset(
        size.width * 0.8 + math.sin(progress * 6 * math.pi) * 80,
        size.height * 0.5 + math.cos(progress * 6 * math.pi) * 80,
      ),
      radius: size.width * 0.5,
      colors: [
        const Color(0xFF7B66FF).withValues(alpha: 0.1), // Purple Pulse
        const Color(0xFF7B66FF).withValues(alpha: 0.0),
      ],
    );
  }

  void _drawCloud(Canvas canvas, Size size, Paint paint, {
    required Offset centerOffset,
    required double radius,
    required List<Color> colors,
  }) {
    paint.shader = RadialGradient(
      colors: colors,
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: centerOffset, radius: radius));
    
    canvas.drawCircle(centerOffset, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => true;
}
