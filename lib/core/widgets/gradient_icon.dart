import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double? size;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
