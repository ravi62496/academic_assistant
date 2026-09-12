import 'package:flutter/material.dart';

/// Intentional academic ink color palette designed for student life.
/// Replaces generic SaaS charcoal/grey defaults with warm ink tones,
/// distinct schedule accents, and dedicated AI mode highlights.
class AppColors {
  // Brand & Accent Colors
  static const primary = Color(0xFF4E9F8E);       // Serene Warm Sage Teal (Schedule & Timetable Accent)
  static const primaryDark = Color(0xFF356B60);   // Deep Muted Sage
  static const aiAccent = Color(0xFF9D7BFF);      // Electric Violet / Indigo Node (Dedicated AI Mode Accent)
  static const aiAccentGlow = Color(0x3D9D7BFF);  // Soft Violet Glow for AI Containers
  static const secondary = Color(0xFFE5A958);     // Warm Amber Sand
  static const accentGold = Color(0xFFE9C46A);    // Soft Warm Gold

  // Light Theme Colors (Warm Linen & Ink Charcoal)
  static const lightBackground = Color(0xFFF6F5F2);      // Soft off-white / warm linen
  static const lightSurface = Color(0xFFFFFFFF);         // Warm white card surface
  static const lightSurfaceVariant = Color(0xFFEFECE6);  // Inset surface tint
  static const lightBorder = Color(0xFFE2DDD5);          // Crisp structural border
  static const lightTextPrimary = Color(0xFF1B1E24);     // Deep ink text (no pure black)
  static const lightTextSecondary = Color(0xFF636C77);   // Muted slate text
  static const lightInputBackground = Color(0xFFEFECE6); // Gentle input fill

  // Dark Theme Colors (Deep Ink Charcoal & Soft Cream)
  static const darkBackground = Color(0xFF14161A);       // Deep warm ink base (no flat neutral grey)
  static const darkSurface = Color(0xFF1C1F26);          // Deep elevated slate surface
  static const darkSurfaceVariant = Color(0xFF262A33);   // Richer inset surface tint
  static const darkBorder = Color(0xFF323846);           // Crisp subtle dark border
  static const darkTextPrimary = Color(0xFFECEFF4);      // Soft cream text
  static const darkTextSecondary = Color(0xFF8C96A6);    // Muted soft slate text
  static const darkInputBackground = Color(0xFF222630);  // Subtle dark input fill

  // Text aliases
  static const textPrimary = lightTextPrimary;
  static const textSecondary = lightTextSecondary;

  // Utility Colors
  static const success = Color(0xFF46A382);   // Gentle emerald green
  static const warning = Color(0xFFE5A958);   // Soft warm amber
  static const error = Color(0xFFE05D5D);     // Desaturated crimson (strictly for cancellations/overrides)

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
