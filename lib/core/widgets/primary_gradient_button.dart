import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrimaryGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;
  final bool expand;

  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56.0,
    this.borderRadius = 16.0,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.primaryShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}
