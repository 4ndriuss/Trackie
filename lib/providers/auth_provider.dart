// File: auth_provider.dart
// Provider untuk mengelola state autentikasi pengguna.
// Menghubungkan UI dengan AuthService dan menyimpan data user yang sedang login.
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// [AuthProvider] mengelola state autentikasi dan profil pengguna.
/// Digunakan oleh AuthWrapper untuk menentukan tampilan (Login vs MainPage).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  UserModel? _userProfile;
  bool _isLoading = true; // Mulai dengan loading saat cek auth state
  String? _error;

  User? get user => _user;
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  /// Inisialisasi: mulai mendengarkan perubahan status autentikasi.
  void init() {
    _authService.authStateChanges.listen((User? user) async {
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
      // Auth state listener akan handle sisanya
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        vehicle: vehicle,
      );
      // Auth state listener akan handle sisanya
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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

  /// Keluar dari akun.
  Future<void> logout() async {
    await _authService.signOut();
    // Auth state listener akan handle sisanya
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
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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

  /// Memuat profil user dari Firestore.
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

  /// Mengunggah dan memperbarui foto profil pengguna.
  Future<bool> uploadProfilePicture(Uint8List fileBytes, String ext) async {
    if (_user == null) return false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final url = await _authService.uploadProfilePicture(_user!.uid, fileBytes, ext);
      if (url != null) {
        await _loadUserProfile(_user!.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Gagal mengunggah foto profil.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Gagal mengunggah foto profil.';
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

  /// Menerjemahkan kode error Firebase Auth ke pesan yang user-friendly.
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah (minimal 6 karakter).';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      default:
        return 'Terjadi kesalahan autentikasi.';
    }
  }
}
