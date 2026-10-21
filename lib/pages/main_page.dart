import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const HistoryTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<GroupProvider>().loadActiveGroup(uid);
        context.read<SubscriptionProvider>().initializeForUser(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: const Color(0xFF8E91B5),
            selectedLabelStyle: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w500),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: AppLocalizations.of(context)?.navHome ?? 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_outlined),
                activeIcon: const Icon(Icons.history),
                label: AppLocalizations.of(context)?.navHistory ?? 'History',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: AppLocalizations.of(context)?.navProfile ?? 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
