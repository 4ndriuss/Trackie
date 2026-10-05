// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trackie.';

  @override
  String get loginSubtitle =>
      'Login to continue your journey and join your group.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get preferencesTitle => 'Preferences';

  @override
  String get languageSection => 'LANGUAGE';

  @override
  String languageChanged(String language) {
    return 'Language changed to $language';
  }

  @override
  String get appearanceSection => 'APPEARANCE';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get lightModeDesc => 'Light appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeDesc => 'Dark appearance';

  @override
  String get systemMode => 'System Default';

  @override
  String get systemModeDesc => 'Follows device settings';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navProfile => 'Profile';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name! 👋';
  }

  @override
  String get homeSubtitle => 'Ready for a trip today?';

  @override
  String get homeActiveTrip => 'Currently on a trip';

  @override
  String get homeCreate => 'Create Trip';

  @override
  String get homeJoin => 'Join with Code';

  @override
  String get homeUpcoming => 'Upcoming Trips';

  @override
  String get homeSeeAll => 'See All';

  @override
  String get homeCreateTripTitle => 'Create New Trip';

  @override
  String get homeJoinTripTitle => 'Join Trip';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileTotalDistance => 'Total Distance';

  @override
  String get profileTouring => 'Touring';

  @override
  String get profileRank => 'Rank';

  @override
  String get profileGhostMode => 'Ghost Mode';

  @override
  String get profileGhostModeDesc => 'Hide your location from group map';

  @override
  String get profileSettings => 'SETTINGS';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePreferencesDesc => 'Language, appearance';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileAccountDesc => 'Profile, password';

  @override
  String get profilePrivacy => 'Privacy Policy';

  @override
  String get profilePrivacyDesc => 'Read our privacy policy';

  @override
  String get profileLogout => 'Log Out';
}
