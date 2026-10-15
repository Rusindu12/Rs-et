import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EduColors {
  static const purple = Color(0xff6C63FF);
  static const coral = Color(0xffFF6B6B);
  static const green = Color(0xff4CAF50);
  static const background = Color(0xffF8F9FE);
  static const ink = Color(0xff252641);
  static const muted = Color(0xff85869B);
  static const card = Colors.white;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EduColors.purple,
        primary: EduColors.purple,
        secondary: EduColors.coral,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: EduColors.background,
    );
    return base.copyWith(
      textTheme: GoogleFonts.notoSansSinhalaTextTheme(base.textTheme).apply(
        bodyColor: EduColors.ink,
        displayColor: EduColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EduColors.background,
        foregroundColor: EduColors.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffECECF5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: EduColors.purple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: EduColors.purple.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EduColors.purple,
        brightness: Brightness.dark,
        primary: const Color(0xffA19BFF),
        secondary: const Color(0xffff8585),
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.notoSansSinhalaTextTheme(base.textTheme),
      scaffoldBackgroundColor: const Color(0xff151522),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff151522),
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xff222232),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xff20202E),
        indicatorColor: Color(0x336C63FF),
        height: 70,
      ),
    );
  }
}
