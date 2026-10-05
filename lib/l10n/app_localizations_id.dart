// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Trackie.';

  @override
  String get loginSubtitle =>
      'Login untuk melanjutkan perjalanan dan bergabung dengan grupmu.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'nama@contoh.com';

  @override
  String get passwordLabel => 'Kata Sandi';

  @override
  String get passwordHint => 'Masukkan kata sandimu';

  @override
  String get forgotPassword => 'Lupa Kata Sandi?';

  @override
  String get loginButton => 'MASUK';

  @override
  String get noAccount => 'Belum punya akun?';

  @override
  String get signUp => 'Daftar';

  @override
  String get preferencesTitle => 'Preferensi';

  @override
  String get languageSection => 'BAHASA';

  @override
  String languageChanged(String language) {
    return 'Bahasa diubah ke $language';
  }

  @override
  String get appearanceSection => 'TAMPILAN';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get lightModeDesc => 'Tampilan terang';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeDesc => 'Tampilan gelap';

  @override
  String get systemMode => 'Ikuti Sistem';

  @override
  String get systemModeDesc => 'Mengikuti pengaturan perangkat';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'Riwayat';

  @override
  String get navProfile => 'Profil';

  @override
  String homeGreeting(String name) {
    return 'Halo, $name! 👋';
  }

  @override
  String get homeSubtitle => 'Siap untuk perjalanan hari ini?';

  @override
  String get homeActiveTrip => 'Sedang dalam perjalanan';

  @override
  String get homeCreate => 'Buat Trip';

  @override
  String get homeJoin => 'Gabung dengan Kode';

  @override
  String get homeUpcoming => 'Jadwal Mendatang';

  @override
  String get homeSeeAll => 'Lihat Semua';

  @override
  String get homeCreateTripTitle => 'Buat Perjalanan Baru';

  @override
  String get homeJoinTripTitle => 'Gabung Perjalanan';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileTotalDistance => 'Total Jarak';

  @override
  String get profileTouring => 'Touring';

  @override
  String get profileRank => 'Rank';

  @override
  String get profileGhostMode => 'Mode Hantu (Ghost Mode)';

  @override
  String get profileGhostModeDesc => 'Sembunyikan lokasimu dari peta grup';

  @override
  String get profileSettings => 'PENGATURAN';

  @override
  String get profilePreferences => 'Preferensi';

  @override
  String get profilePreferencesDesc => 'Bahasa, tampilan';

  @override
  String get profileAccount => 'Akun';

  @override
  String get profileAccountDesc => 'Profil, password';

  @override
  String get profilePrivacy => 'Kebijakan Privasi';

  @override
  String get profilePrivacyDesc => 'Baca kebijakan privasi kami';

  @override
  String get profileLogout => 'Log Out';
}
