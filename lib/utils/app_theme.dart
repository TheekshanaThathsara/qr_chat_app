import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color primaryVariant = Color(0xFF3700B3);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryVariant = Color(0xFF018786);

  // Light theme colors
  static const Color lightBackground = Color(0xFFFFFBFE);
  static const Color lightSurface = Color(0xFFFFFBFE);
  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnSecondary = Color(0xFF000000);
  static const Color lightOnBackground = Color(0xFF1C1B1F);
  static const Color lightOnSurface = Color(0xFF1C1B1F);
  static const Color lightOnError = Color(0xFFFFFFFF);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF1C1B1F);
  static const Color darkSurface = Color(0xFF1C1B1F);
  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnPrimary = Color(0xFF000000);
  static const Color darkOnSecondary = Color(0xFF000000);
  static const Color darkOnBackground = Color(0xFFE6E1E5);
  static const Color darkOnSurface = Color(0xFFE6E1E5);
  static const Color darkOnError = Color(0xFF601410);

  // Chat specific colors
  static const Color myMessageColor = Color(0xFF6200EE);
  static const Color otherMessageColor = Color(0xFFE0E0E0);
  static const Color onlineIndicator = Color(0xFF4CAF50);
  static const Color offlineIndicator = Color(0xFF9E9E9E);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryVariant,
        secondary: secondary,
        secondaryContainer: secondaryVariant,
        surface: lightSurface,
        error: lightError,
        onPrimary: lightOnPrimary,
        onSecondary: lightOnSecondary,
        onSurface: lightOnSurface,
        onError: lightOnError,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: lightOnPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightOnPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: lightOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: lightOnPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryVariant,
        secondary: secondary,
        secondaryContainer: secondaryVariant,
        surface: darkSurface,
        error: darkError,
        onPrimary: darkOnPrimary,
        onSecondary: darkOnSecondary,
        onSurface: darkOnSurface,
        onError: darkOnError,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: darkOnPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightOnPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: lightOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: lightOnPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
