// File: app_theme.dart
// Mendefinisikan tema global untuk aplikasi, termasuk warna, tipografi, dan gaya komponen.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kelas [AppTheme] menyediakan pengaturan tema untuk aplikasi.
class AppTheme {
  // Warna utama yang digunakan di aplikasi, merujuk pada DESIGN.md
  static const Color primary = Color(0xFF1A1C1E);
  static const Color secondary = Color(0xFF6C7278);
  static const Color tertiary = Color(0xFFB8422E);
  static const Color neutral = Color(0xFFF7F5F2);

  /// Menghasilkan tema terang (light theme) untuk aplikasi.
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
      // Pengaturan tipografi menggunakan font dari Google Fonts
      textTheme: TextTheme(
        displayLarge: GoogleFonts.publicSans(
          fontSize: 48, // Setara dengan 3rem
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
          fontSize: 16, // Setara dengan 1rem
          color: primary,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontSize: 12, // Setara dengan 0.75rem
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: primary,
        ),
      ),
      // Pengaturan gaya AppBar
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
      // Pengaturan gaya untuk input form (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // Menggunakan rounded md
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
      // Pengaturan gaya untuk ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tertiary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Menggunakan rounded md
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      // Pengaturan gaya untuk TextButton
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

  /// Menghasilkan tema gelap (dark theme) untuk aplikasi.
  static ThemeData get darkTheme {
    const Color darkBg = primary;
    const Color darkSurface = Color(0xFF2D3035);
    const Color darkText = neutral;

    return ThemeData(
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkText,
      colorScheme: const ColorScheme.dark(
        primary: darkText,
        secondary: secondary,
        surface: darkSurface,
        error: tertiary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.publicSans(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: darkText,
          height: 1.1,
        ),
        titleMedium: GoogleFonts.publicSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        bodyMedium: GoogleFonts.publicSans(
          fontSize: 16,
          color: darkText,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: darkText,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 1,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: GoogleFonts.publicSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: secondary, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkText, width: 2),
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
            borderRadius: BorderRadius.circular(8),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkText),
        ),
      ),
      dividerColor: secondary.withOpacity(0.3), // ignore: deprecated_member_use
    );
  }
}

/// Kelas konstanta untuk spasi dan jarak (padding/margin) yang standar di aplikasi.
class AppSpacing {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
