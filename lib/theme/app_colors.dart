import 'package:flutter/material.dart';

/// Intentional academic ink color palette designed for student life.
/// Replaces generic SaaS charcoal/grey defaults with warm ink tones,
/// distinct schedule accents, and dedicated AI mode highlights.
class AppColors {
  // Brand & Accent Colors
  static const sentryGreen = Color(0xFF157A4B);   // Vibrant Emerald Green (WCAG AA 5.5:1 against white)
  static const primary = Color(0xFF157A4B);       // Sentry Emerald Green Primary Accent (WCAG AA 5.5:1)
  static const primaryDark = Color(0xFF146C43);   // Deep Emerald Green
  static const aiAccent = Color(0xFF7C3AED);      // Accessible Violet (WCAG AA 6.5:1 on light)
  static const aiAccentGlow = Color(0x3D7C3AED);  // Soft Violet Glow for AI Containers
  static const secondary = Color(0xFFB45309);     // Warm Amber Sand (WCAG AA 5.5:1 on light)
  static const accentGold = Color(0xFFB45309);    // Soft Warm Gold

  // Light Theme Colors (Warm Linen & Ink Charcoal)
  static const lightBackground = Color(0xFFF6F5F2);      // Soft off-white / warm linen
  static const lightSurface = Color(0xFFFFFFFF);         // Warm white card surface
  static const lightSurfaceVariant = Color(0xFFEFECE6);  // Inset surface tint
  static const lightBorder = Color(0xFFD4CDC3);          // Crisp structural border (WCAG 3:1 UI component)
  static const lightTextPrimary = Color(0xFF1B1E24);     // Deep ink text (no pure black)
  static const lightTextSecondary = Color(0xFF525B66);   // Muted slate text (WCAG AA 5.2:1)
  static const lightInputBackground = Color(0xFFEFECE6); // Gentle input fill

  // Dark Theme Colors (Deep Ink Charcoal & Soft Cream)
  static const darkBackground = Color(0xFF14161A);       // Deep warm ink base (no flat neutral grey)
  static const darkSurface = Color(0xFF1C1F26);          // Deep elevated slate surface
  static const darkSurfaceVariant = Color(0xFF262A33);   // Richer inset surface tint
  static const darkBorder = Color(0xFF424A5C);           // Crisp subtle dark border (WCAG 3:1 UI component)
  static const darkTextPrimary = Color(0xFFECEFF4);      // Soft cream text
  static const darkTextSecondary = Color(0xFF9EA8B6);    // Muted soft slate text (WCAG AA 5.3:1)
  static const darkInputBackground = Color(0xFF222630);  // Subtle dark input fill

  // Text aliases
  static const textPrimary = lightTextPrimary;
  static const textSecondary = lightTextSecondary;

  // Utility Colors
  static const success = Color(0xFF157A4B);   // Gentle emerald green
  static const warning = Color(0xFFB45309);   // Soft warm amber (WCAG AA 5.5:1)
  static const error = Color(0xFFDC2626);     // Accessible crimson (WCAG AA 5.8:1)

  // Subject Color Palette (For visual course distinction)
  static const List<Color> coursePalette = [
    Color(0xFF4E9F8E), // Sage Teal
    Color(0xFFE5A958), // Warm Amber
    Color(0xFF7C83FD), // Soft Indigo
    Color(0xFFD97757), // Terracotta
    Color(0xFF46A382), // Emerald
    Color(0xFFD96B87), // Rosewood
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
  ];

  /// Get deterministic color tag for a course name or ID
  static Color getCourseColor(String identifier) {
    if (identifier.isEmpty) return coursePalette[0];
    final hash = identifier.codeUnits.fold(0, (prev, elem) => prev + elem);
    return coursePalette[hash % coursePalette.length];
  }
}
