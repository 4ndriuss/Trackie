// File: main.dart
// Titik masuk utama (entry point) untuk aplikasi Trackie.
// File ini menginisialisasi aplikasi Flutter dan mengatur tema utama.
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';

/// Fungsi utama yang dijalankan pertama kali saat aplikasi dimulai.
void main() {
  runApp(const TrackieApp());
}

/// State global sederhana untuk mengatur tema (MVP)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Kelas utama aplikasi Trackie.
/// Merupakan root widget dari seluruh aplikasi.
class TrackieApp extends StatelessWidget {
  const TrackieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'Trackie',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: true,
          home: const LoginPage(),
        );
      },
    );
  }
}
