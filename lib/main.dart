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

/// Kelas utama aplikasi Trackie.
/// Merupakan root widget dari seluruh aplikasi.
class TrackieApp extends StatelessWidget {
  const TrackieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trackie',
      // Menggunakan tema yang didefinisikan di AppTheme
      theme: AppTheme.lightTheme,
      // Aktifkan banner debug untuk membantu memastikan apakah Flutter berhasil merender UI
      debugShowCheckedModeBanner: true,
      // Halaman pertama yang dimuat saat aplikasi dijalankan
      home: const LoginPage(),
    );
  }
}
