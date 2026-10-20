import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import 'privacy_policy_page.dart';
import 'preferences_page.dart';
import 'account_page.dart';
import 'subscription_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isGhostMode = false;

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.urbanist()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.urbanist(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: Text('Log Out', style: GoogleFonts.urbanist(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditAvatar() async {
    final authProvider = context.read<AuthProvider>();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      final ext = pickedFile.name.split('.').last;
      
      final success = await authProvider.updateProfilePicture(bytes, ext);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Profile picture updated successfully!'
                  : (authProvider.error ?? 'Failed to update profile picture (max 5MB, JPG/PNG/WebP).'),
            ),
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "U";
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final subProvider = context.watch<SubscriptionProvider>();
    final userName = user?.name ?? 'User';
    final userVehicle = (user?.vehicle != null && user!.vehicle.isNotEmpty) ? user.vehicle : 'Trackie Explorer';
    final joinedDate = user != null ? DateFormat('MMM yyyy').format(user.createdAt) : 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Profile',
          style: GoogleFonts.urbanist(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesPage()));
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F1F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_outlined, color: Color(0xFF1A1A2E), size: 22),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFEDEDF2),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2. Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                          backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(user.photoUrl!)
                              : null,
                          child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                              ? Text(
                                  _getInitials(userName),
                                  style: GoogleFonts.urbanist(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _handleEditAvatar,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2B2B2B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userName,
                      style: GoogleFonts.urbanist(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$userVehicle · Joined $joinedDate',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        color: const Color(0xFF5B5F97),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 3. Stats Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const Expanded(child: StatItem(value: '24', label: 'Routes')),
                    Container(width: 1, height: 40, color: const Color(0xFFEDEDF2)),
                    const Expanded(child: StatItem(value: '31', label: 'Tracked')),
                    Container(width: 1, height: 40, color: const Color(0xFFEDEDF2)),
                    const Expanded(child: StatItem(value: '18', label: 'Places')),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Streak Banner
              const StreakBanner(streakDays: 7, subtitle: 'Keep it up to unlock the Explorer badge!'),
              const SizedBox(height: 32),

              // 5. Account & Settings Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 16),
                      child: Text(
                        'ACCOUNT & SETTINGS',
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B6F9A),
                        ),
                      ),
                    ),
                    ProfileMenuTile(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: AppTheme.primary,
                      title: 'Subscription',
                      badge: subProvider.isPremium
                          ? 'PREMIUM (${subProvider.usedGroupsCount}/${subProvider.maxGroups})'
                          : 'FREE (${subProvider.usedGroupsCount}/${subProvider.maxGroups})',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionPage(
                              isFirstTimeFlow: false,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfileMenuTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Account Details',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfileMenuTile(
                      icon: _isGhostMode ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      title: 'Ghost Mode',
                      badge: _isGhostMode ? 'ON' : 'OFF',
                      onTap: () {
                        setState(() => _isGhostMode = !_isGhostMode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isGhostMode ? 'Ghost Mode Activated' : 'Ghost Mode Deactivated'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfileMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfileMenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      iconColor: Colors.redAccent,
                      titleColor: Colors.redAccent,
                      onTap: () => _handleLogout(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Reusable Widgets ---

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.urbanist(
            fontSize: 15,
            color: const Color(0xFF5B5F97),
          ),
        ),
      ],
    );
  }
}

class StreakBanner extends StatelessWidget {
  final int streakDays;
  final String subtitle;

  const StreakBanner({super.key, required this.streakDays, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F1C),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$streakDays-day tracking streak',
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    color: const Color(0xFFA8ABB0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor ?? const Color(0xFF6B6F9A), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6F9A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.chevron_right, color: Color(0xFFC4C4D4), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
