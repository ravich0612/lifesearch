import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color deepIndigo = Color(0xFF4F46E5);
  static const Color indigoAccent = Color(0xFF6366F1);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
      Color(0xFFD946EF), // Pink
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Map<String, Color> get moodColors => {
    'GALLERY': const Color(0xFFF59E0B), // Warm Orange
    'DOCUMENTS': const Color(0xFF6366F1), // Focused Indigo
    'RECEIPTS': const Color(0xFF10B981), // Wealth Green
    'TRAVEL': const Color(0xFF0EA5E9), // Sky Blue
    'GENERAL': const Color(0xFF4F46E5), // Deep Indigo
  };
  
  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: const Color(0xFF4AC7FA).withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Backgrounds
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundElevated = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  // Accent Colors
  static const Color cyanAccent = Color(0xFF22D3EE);
  static const Color softPurpleAccent = Color(0xFF8B5CF6);

  // Neutrals
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFF1F5F9);
  
  // States
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}
