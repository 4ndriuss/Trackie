// File: signup_page.dart
// Halaman untuk pendaftaran pengguna baru (Sign Up).
// Mengumpulkan data pengguna seperti nama lengkap, email, kata sandi, dan info kendaraan.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';
import 'main_page.dart';

/// [SignupPage] adalah widget stateful yang menampilkan form pendaftaran akun.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Key form untuk keperluan validasi sebelum proses pendaftaran
  final _formKey = GlobalKey<FormState>();
  
  // Controller untuk masing-masing field input
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleController = TextEditingController(); // Opsional

  @override
  void dispose() {
    // Membersihkan controller untuk membebaskan sumber daya
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  /// Menangani aksi pendaftaran ketika tombol ditekan.
  /// Memvalidasi semua input, dan jika berhasil, menavigasi ke [MainPage] 
  /// sekaligus menghapus riwayat navigasi (supaya tidak bisa back ke halaman signup).
  void _handleSignup() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement actual signup logic
      // Contoh: authService.signUp(_emailController.text, _passwordController.text, ...)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
        (route) => false, // Menghapus rute sebelumnya dari stack
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar transparan agar menyatu dengan latar belakang dan hanya menampilkan tombol back
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Judul Halaman
                Text(
                  'Join Trackie',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Subjudul deskripsi
                Text(
                  'Create an account to start tracking.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Input Nama Lengkap
                CustomTextField(
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Input Email
                CustomTextField(
                  label: 'Email',
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!value.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Input Kata Sandi (Password)
                CustomTextField(
                  label: 'Password',
                  hint: 'Create a password',
                  isPassword: true,
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Input Info Kendaraan (Opsional)
                CustomTextField(
                  label: 'Vehicle Info (Optional)',
                  hint: 'e.g. NMAX Hitam',
                  controller: _vehicleController,
                ),
                const SizedBox(height: AppSpacing.xl),
                // Tombol aksi pendaftaran
                ElevatedButton(
                  onPressed: _handleSignup,
                  child: const Text('SIGN UP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
