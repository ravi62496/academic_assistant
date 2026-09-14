import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Intentional academic visual system with Space Grotesk display typography,
/// Plus Jakarta Sans body typography, and Fira Code for monospaced figures.
class AppTheme {
  static const double _borderRadius = 16.0;

  /// Helper for monospaced tabular class times
  static TextStyle monoTimeStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.firaCode(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        surfaceContainerHigh: AppColors.lightSurfaceVariant,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: AppColors.lightTextPrimary,
        onSurface: AppColors.lightTextPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: -0.1,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.lightTextSecondary,
          fontSize: 13.5,
          height: 1.45,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.lightTextSecondary.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.lightBackground, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurfaceVariant,
        error: AppColors.error,
        onPrimary: AppColors.darkBackground,
        onSecondary: AppColors.darkTextPrimary,
        onSurface: AppColors.darkTextPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: -0.1,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.darkTextSecondary,
          fontSize: 13.5,
          height: 1.45,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.darkTextSecondary.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.darkTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.darkTextPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.darkBackground, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
    );
  }
}
