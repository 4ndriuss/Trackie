import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/subscription_page.dart';
import 'providers/subscription_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _hasSeenOnboarding;
  String? _initializedUid;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    bool seen = false;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      seen = prefs.getBool('hasSeenOnboarding') ?? false;
    } catch (_) {
      seen = false;
    }
    if (!seen && mounted) {
      try {
        await OnboardingPage.precacheAll(context)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _hasSeenOnboarding = seen);
    }
  }

  void _ensureSubscriptionLoaded(String uid) {
    if (_initializedUid == uid) return;
    _initializedUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SubscriptionProvider>().initializeForUser(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseConfig.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          _ensureSubscriptionLoaded(session.user.id);
          final subProvider = context.watch<SubscriptionProvider>();

          if (!subProvider.isInitialized || subProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (!subProvider.hasSeenSubscriptionPage) {
            return const SubscriptionPage(isFirstTimeFlow: true);
          }

          return const MainPage();
        }

        _initializedUid = null;

        if (!_hasSeenOnboarding!) {
          return const OnboardingPage();
        }

        return const LoginPage();
      },
    );
  }
}
