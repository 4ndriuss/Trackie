// File: auth_provider.dart
// Provider untuk mengelola state autentikasi pengguna.
// Menghubungkan UI dengan AuthService dan menyimpan data user yang sedang login.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

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
    String? phone,
    DateTime? birthDate,
  }) async {
    try {
      _isLoading = true;
      _isRegistering = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        vehicle: vehicle,
        phone: phone,
        birthDate: birthDate,
      );
      await credential.user?.updateDisplayName(name);
      await _authService.signOut(); // Sign out to prevent auto-login

      _user = null;
      _userProfile = null;
      _isRegistering = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
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
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _error = 'Silakan keluar dan login kembali sebelum menghapus akun demi keamanan.';
      } else {
        _error = _getAuthErrorMessage(e.code);
      }
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

  /// Menghapus pesan error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'The email format is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
