// File: auth_provider.dart
// Provider untuk mengelola state autentikasi pengguna.
// Menghubungkan UI dengan AuthService dan menyimpan data user yang sedang login.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

// Re-export agar halaman yang meng-import AuthProvider bisa memakai
// `user.uid` / `user.displayName` pada objek User Supabase.
export '../services/auth_service.dart' show SupabaseUserExtension;

/// [AuthProvider] mengelola state autentikasi dan profil pengguna.
/// Digunakan oleh AuthWrapper untuk menentukan tampilan (Login vs MainPage).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  StreamSubscription<User?>? _authSubscription;
  User? _user;
  UserModel? _userProfile;
  bool _isLoading = true; // Mulai dengan loading saat cek auth state
  bool _isRegistering = false;
  String? _error;

  User? get user => _user;
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && !_isRegistering;
  String? get error => _error;

  /// Inisialisasi: mulai mendengarkan perubahan status autentikasi.
  void init() {
    _authSubscription?.cancel();
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      if (_isRegistering) return;
      _user = user;
      if (user != null) {
        await _loadUserProfile(user.uid);
      } else {
        _userProfile = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Login dengan email dan password.
  /// Mengembalikan true jika berhasil, false jika gagal.
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signIn(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Terjadi kesalahan. Silakan coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mendaftarkan user baru.
  /// Mengembalikan true jika berhasil, false jika gagal.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String vehicle = '',
    String? phone,
    DateTime? birthDate,
  }) async {
    try {
      _isLoading = true;
      _isRegistering = true;
      _error = null;
      notifyListeners();

      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        vehicle: vehicle,
        phone: phone,
        birthDate: birthDate,
      );
      // Nama sudah dikirim sebagai metadata saat signUp. Jangan panggil
      // updateUser di sini: bila konfirmasi email aktif, belum ada sesi.
      await _authService.signOut(); // Sign out to prevent auto-login

      _user = null;
      _userProfile = null;
      _isRegistering = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isRegistering = false;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Terjadi kesalahan. Silakan coba lagi.';
      _isRegistering = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.signInWithGoogle();

      _isLoading = false;
      notifyListeners();
      return credential != null;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal masuk dengan Google. Pastikan konfigurasi Google Sign-In aktif.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithFacebook() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.signInWithFacebook();

      _isLoading = false;
      notifyListeners();
      return credential != null;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal masuk dengan Facebook. Pastikan konfigurasi Facebook Login aktif.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mengunggah dan memperbarui foto profil pengguna.
  Future<bool> updateProfilePicture(Uint8List fileBytes, String ext) async {
    if (_user == null) return false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final downloadUrl = await _authService.uploadProfilePicture(_user!.uid, fileBytes, ext);
      if (downloadUrl != null) {
        if (_userProfile != null) {
          _userProfile = _userProfile!.copyWith(photoUrl: downloadUrl);
        } else {
          await _loadUserProfile(_user!.uid);
        }
        return true;
      }
      _error = 'Gagal mengunggah foto profil.';
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Alias untuk [updateProfilePicture].
  Future<bool> uploadProfilePicture(Uint8List fileBytes, String ext) =>
      updateProfilePicture(fileBytes, ext);

  /// Keluar dari akun.
  Future<void> logout() async {
    await _authService.signOut();
  }

  /// Menghapus akun pengguna saat ini.
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.deleteAccount();
      _user = null;
      _userProfile = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal menghapus akun.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Kirim email reset password.
  /// Mengembalikan true jika berhasil, false jika gagal.
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _getAuthErrorMessage(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Terjadi kesalahan. Silakan coba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Memuat profil user dari Supabase.
  Future<void> _loadUserProfile(String uid) async {
    try {
      _userProfile = await _authService.getUserProfile(uid);
    } catch (e) {
      _error = 'Gagal memuat profil.';
    }
  }

  /// Memperbarui profil user.
  Future<bool> updateProfile({String? name, String? vehicle}) async {
    if (_user == null) return false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.updateUserProfile(_user!.uid, name: name, vehicle: vehicle);
      await _loadUserProfile(_user!.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal memperbarui profil.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Menghapus pesan error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _getAuthErrorMessage(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox email Anda atau matikan opsi Confirm Email di Dashboard Supabase.';
    } else if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('wrong password')) {
      return 'Email atau kata sandi salah.';
    } else if (lower.contains('already registered') || lower.contains('user already exists')) {
      return 'Email ini sudah terdaftar.';
    } else if (lower.contains('password should be at least 6 characters') ||
        lower.contains('weak password')) {
      return 'Kata sandi minimal 6 karakter.';
    } else if (lower.contains('invalid email') || lower.contains('unable to validate email')) {
      return 'Format email tidak valid.';
    } else if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Terlalu banyak percobaan. Silakan coba sesaat lagi.';
    } else if (lower.contains('network') || lower.contains('connection')) {
      return 'Tidak ada koneksi internet.';
    }
    return msg;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
