import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors based on DESIGN.md
  static const Color primary = Color(0xFF1A1C1E);
  static const Color secondary = Color(0xFF6C7278);
  static const Color tertiary = Color(0xFFB8422E);
  static const Color neutral = Color(0xFFF7F5F2);

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: neutral,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: neutral,
        error: tertiary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.publicSans(
          fontSize: 48, // 3rem
          fontWeight: FontWeight.bold,
          color: primary,
          height: 1.1,
        ),
        titleMedium: GoogleFonts.publicSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyMedium: GoogleFonts.publicSans(
          fontSize: 16, // 1rem
          color: primary,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontSize: 12, // 0.75rem
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: primary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: GoogleFonts.publicSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // rounded md
          borderSide: const BorderSide(color: secondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.publicSans(color: secondary),
        // ignore: deprecated_member_use
        hintStyle: GoogleFonts.publicSans(color: secondary.withOpacity(0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tertiary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // rounded md
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tertiary,
          textStyle: GoogleFonts.publicSans(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AppSpacing {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
