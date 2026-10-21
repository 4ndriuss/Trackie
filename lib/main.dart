import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'theme/app_theme.dart';
import 'app.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'pages/subscription_page.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/location_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'services/background_location_service.dart';
import 'services/secure_local_storage.dart';
import 'supabase_config.dart';

import 'package:flutter/foundation.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );
  
  if (!kIsWeb) {
    try {
      await BackgroundLocationService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize background service: $e');
    }
  }
  
  runApp(const TrackieApp());
}

class TrackieApp extends StatelessWidget {
  const TrackieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // ARCH-12 & BUG-18: Sinkronkan themeNotifier untuk kompatibilitas UI
          if (themeNotifier.value != themeProvider.themeMode) {
            themeNotifier.value = themeProvider.themeMode;
          }
          final localeProvider = Provider.of<LocaleProvider>(context);
          return MaterialApp(
            title: 'Trackie',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('id', ''),
              Locale('en', ''),
            ],
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/login': (context) => const LoginPage(),
              '/home': (context) => const MainPage(),
              '/subscription': (context) => const SubscriptionPage(
                    isFirstTimeFlow: false,
                  ),
              '/subscription-onboarding': (context) => const SubscriptionPage(
                    isFirstTimeFlow: true,
                  ),
            },
          );
        },
      ),
    );
  }
}
