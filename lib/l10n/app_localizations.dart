import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'Trackie.'**
  String get appTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Login untuk melanjutkan perjalanan dan bergabung dengan grupmu.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In id, this message translates to:
  /// **'nama@contoh.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In id, this message translates to:
  /// **'Kata Sandi'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In id, this message translates to:
  /// **'Masukkan kata sandimu'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In id, this message translates to:
  /// **'Lupa Kata Sandi?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In id, this message translates to:
  /// **'MASUK'**
  String get loginButton;

  /// No description provided for @noAccount.
  ///
  /// In id, this message translates to:
  /// **'Belum punya akun?'**
  String get noAccount;

  /// No description provided for @signUp.
  ///
  /// In id, this message translates to:
  /// **'Daftar'**
  String get signUp;

  /// No description provided for @preferencesTitle.
  ///
  /// In id, this message translates to:
  /// **'Preferensi'**
  String get preferencesTitle;

  /// No description provided for @languageSection.
  ///
  /// In id, this message translates to:
  /// **'BAHASA'**
  String get languageSection;

  /// No description provided for @languageChanged.
  ///
  /// In id, this message translates to:
  /// **'Bahasa diubah ke {language}'**
  String languageChanged(String language);

  /// No description provided for @appearanceSection.
  ///
  /// In id, this message translates to:
  /// **'TAMPILAN'**
  String get appearanceSection;

  /// No description provided for @lightMode.
  ///
  /// In id, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @lightModeDesc.
  ///
  /// In id, this message translates to:
  /// **'Tampilan terang'**
  String get lightModeDesc;

  /// No description provided for @darkMode.
  ///
  /// In id, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @darkModeDesc.
  ///
  /// In id, this message translates to:
  /// **'Tampilan gelap'**
  String get darkModeDesc;

  /// No description provided for @systemMode.
  ///
  /// In id, this message translates to:
  /// **'Ikuti Sistem'**
  String get systemMode;

  /// No description provided for @systemModeDesc.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti pengaturan perangkat'**
  String get systemModeDesc;

  /// No description provided for @navHome.
  ///
  /// In id, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get navHistory;

  /// No description provided for @navProfile.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @homeGreeting.
  ///
  /// In id, this message translates to:
  /// **'Halo, {name}! 👋'**
  String homeGreeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Siap untuk perjalanan hari ini?'**
  String get homeSubtitle;

  /// No description provided for @homeActiveTrip.
  ///
  /// In id, this message translates to:
  /// **'Sedang dalam perjalanan'**
  String get homeActiveTrip;

  /// No description provided for @homeCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat Trip'**
  String get homeCreate;

  /// No description provided for @homeJoin.
  ///
  /// In id, this message translates to:
  /// **'Gabung dengan Kode'**
  String get homeJoin;

  /// No description provided for @homeUpcoming.
  ///
  /// In id, this message translates to:
  /// **'Jadwal Mendatang'**
  String get homeUpcoming;

  /// No description provided for @homeSeeAll.
  ///
  /// In id, this message translates to:
  /// **'Lihat Semua'**
  String get homeSeeAll;

  /// No description provided for @homeCreateTripTitle.
  ///
  /// In id, this message translates to:
  /// **'Buat Perjalanan Baru'**
  String get homeCreateTripTitle;

  /// No description provided for @homeJoinTripTitle.
  ///
  /// In id, this message translates to:
  /// **'Gabung Perjalanan'**
  String get homeJoinTripTitle;

  /// No description provided for @profileTitle.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileTotalDistance.
  ///
  /// In id, this message translates to:
  /// **'Total Jarak'**
  String get profileTotalDistance;

  /// No description provided for @profileTouring.
  ///
  /// In id, this message translates to:
  /// **'Touring'**
  String get profileTouring;

  /// No description provided for @profileRank.
  ///
  /// In id, this message translates to:
  /// **'Rank'**
  String get profileRank;

  /// No description provided for @profileGhostMode.
  ///
  /// In id, this message translates to:
  /// **'Mode Hantu (Ghost Mode)'**
  String get profileGhostMode;

  /// No description provided for @profileGhostModeDesc.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan lokasimu dari peta grup'**
  String get profileGhostModeDesc;

  /// No description provided for @profileSettings.
  ///
  /// In id, this message translates to:
  /// **'PENGATURAN'**
  String get profileSettings;

  /// No description provided for @profilePreferences.
  ///
  /// In id, this message translates to:
  /// **'Preferensi'**
  String get profilePreferences;

  /// No description provided for @profilePreferencesDesc.
  ///
  /// In id, this message translates to:
  /// **'Bahasa, tampilan'**
  String get profilePreferencesDesc;

  /// No description provided for @profileAccount.
  ///
  /// In id, this message translates to:
  /// **'Akun'**
  String get profileAccount;

  /// No description provided for @profileAccountDesc.
  ///
  /// In id, this message translates to:
  /// **'Profil, password'**
  String get profileAccountDesc;

  /// No description provided for @profilePrivacy.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan Privasi'**
  String get profilePrivacy;

  /// No description provided for @profilePrivacyDesc.
  ///
  /// In id, this message translates to:
  /// **'Baca kebijakan privasi kami'**
  String get profilePrivacyDesc;

  /// No description provided for @profileLogout.
  ///
  /// In id, this message translates to:
  /// **'Log Out'**
  String get profileLogout;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
