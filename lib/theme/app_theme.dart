import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFFB347),
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFFB347),
      secondary: Color(0xFFE71D36),
      surface: Color(0xFF1E1E1E),
    ),
    useMaterial3: true,
    fontFamily: 'StackSansText',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
    ),
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  );

  static const Color emberOrange = Color(0xFFFFB347);
}
