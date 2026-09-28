// File: login_page.dart
// Halaman untuk pengguna masuk (login) ke dalam aplikasi.
// Meminta email dan kata sandi dari pengguna, serta menyediakan navigasi ke halaman pendaftaran.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'signup_page.dart';
import '../widgets/custom_textfield.dart';
import 'main_page.dart';

/// [LoginPage] merupakan widget stateful yang menampilkan form login.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Key form untuk validasi input
  final _formKey = GlobalKey<FormState>();
  
  // Controller untuk membaca nilai dari input email dan password
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Membersihkan controller saat widget dihancurkan untuk mencegah memory leak
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Menangani aksi login ketika tombol ditekan.
  /// Memvalidasi form, dan jika berhasil, akan berpindah ke [MainPage].
  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement actual authentication (e.g., authService.login)
      // Sementara ini, langsung berpindah ke MainPage tanpa otentikasi nyata
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Tambahan untuk debug
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 64),
                // Judul / Logo teks aplikasi
                Text(
                  'Trackie.',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                // Subjudul deskripsi
                Text(
                  'Login to continue your journey and join your group.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 64),
                // Input untuk Email
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
                // Input untuk Kata Sandi (Password)
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  isPassword: true,
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                // Tombol "Lupa Kata Sandi" (Forgot Password)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Tombol aksi Login
                ElevatedButton(
                  onPressed: _handleLogin,
                  child: const Text('LOGIN'),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Teks dan tombol untuk beralih ke halaman pendaftaran (Sign Up)
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        // Berpindah ke SignupPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupPage()),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
