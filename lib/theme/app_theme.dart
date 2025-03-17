
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Define common colors
  static const Color primaryColor = Color(0xFF607D8B); // BlueGrey
  static const Color accentColor = Color(0xFF78909C); // BlueGrey 400
  static final Color errorColor = Colors.red.shade700;
  
  // Text colors
  static const Color _lightTextPrimary = Color(0xFF263238); // BlueGrey 900
  static const Color _darkTextPrimary = Color(0xFFECEFF1); // BlueGrey 50
  
  // Reading themes
  static final Map<String, ReaderTheme> readerThemes = {
    'Default': ReaderTheme(
      name: 'Default',
      backgroundColor: Colors.white,
      textColor: _lightTextPrimary,
      accentColor: primaryColor,
      brightness: Brightness.light,
    ),
    'Sepia': ReaderTheme(
      name: 'Sepia', 
      backgroundColor: const Color(0xFFF5E9D0),
      textColor: const Color(0xFF5B4636),
      accentColor: Colors.brown[400]!,
      brightness: Brightness.light,
    ),
    'Night': ReaderTheme(
      name: 'Night',
      backgroundColor: const Color(0xFF263238),
      textColor: _darkTextPrimary,
      accentColor: Colors.blueGrey[200]!,
      brightness: Brightness.dark,
    ),
    'Solarized': ReaderTheme(
      name: 'Solarized',
      backgroundColor: const Color(0xFFFDF6E3),
      textColor: const Color(0xFF586E75),
      accentColor: const Color(0xFF2AA198),
      brightness: Brightness.light,
    ),
    'Amoled': ReaderTheme(
      name: 'Amoled',
      backgroundColor: Colors.black,
      textColor: const Color(0xFFBDBDBD),
      accentColor: Colors.blueGrey[400]!,
      brightness: Brightness.dark,
    ),
  };

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      background: const Color(0xFFF5F5F5),
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _lightTextPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _lightTextPrimary),
      bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: _lightTextPrimary),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: _lightTextPrimary),
      bodySmall: TextStyle(fontSize: 14, height: 1.4, color: _lightTextPrimary),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      space: 32,
      color: Color(0xFFE0E0E0),
    ),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      background: const Color(0xFF121212),
      surface: const Color(0xFF1E1E1E),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardTheme(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF262626),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: accentColor,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: accentColor,
      ),
    ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _darkTextPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _darkTextPrimary),
      bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: _darkTextPrimary),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: _darkTextPrimary),
      bodySmall: TextStyle(fontSize: 14, height: 1.4, color: _darkTextPrimary),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      space: 32,
      color: Color(0xFF424242),
    ),
  );
}

class ReaderTheme {
  final String name;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final Brightness brightness;

  const ReaderTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.brightness,
  });
}