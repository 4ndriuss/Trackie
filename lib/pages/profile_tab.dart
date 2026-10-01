import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'privacy_policy_page.dart';
import 'preferences_page.dart';
import 'account_page.dart';

/// [ProfileTab] menampilkan informasi akun pengguna.
/// Menampilkan foto profil, nama, informasi kendaraan, 
/// serta menyediakan tombol untuk mengedit profil dan keluar (Log Out).
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
        title: const Text('Log Out'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Tutup dialog
              await context.read<AuthProvider>().logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      final file = File(pickedFile.path);
      final authProvider = context.read<AuthProvider>();
      
      final success = await authProvider.uploadProfilePicture(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '✅ Foto profil berhasil diperbarui' 
                : '❌ Gagal memperbarui foto profil'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Ubah Foto Profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, String unit) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Profil',
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Foto Profil
                  GestureDetector(
                    onTap: () => _showImagePicker(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: theme.primaryColor.withOpacity(0.1), // ignore: deprecated_member_use
                          backgroundImage: userProfile?.photoUrl != null
                              ? CachedNetworkImageProvider(userProfile!.photoUrl!)
                              : null,
                          child: userProfile?.photoUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: theme.primaryColor,
                                )
                              : null,
                        ),
                        if (authProvider.isLoading)
                          const Positioned.fill(
                            child: CircularProgressIndicator(),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Nama Pengguna
                  Text(
                    userProfile?.name ?? 'User',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Info Kendaraan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1), // ignore: deprecated_member_use
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.two_wheeler,
                          size: 18,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (userProfile?.vehicle != null && userProfile!.vehicle.isNotEmpty) ? userProfile.vehicle : '-',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Statistik Perjalanan (Touring Stats)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03), // ignore: deprecated_member_use
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: _buildStatItem(context, 'Total Jarak', '2.450', 'km')),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                        ),
                        Expanded(child: _buildStatItem(context, 'Touring', '12', 'kali')),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                        ),
                        Expanded(child: _buildStatItem(context, 'Rank', 'Veteran', '⭐️')),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Pengaturan Privasi (Ghost Mode)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                      ),
                    ),
                    child: SwitchListTile(
                      value: _isGhostMode,
                      onChanged: (value) {
                        setState(() {
                          _isGhostMode = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value 
                                  ? '👻 Mode Hantu Aktif: Lokasi disembunyikan' 
                                  : '📍 Mode Hantu Nonaktif: Lokasi dibagikan',
                            ),
                          ),
                        );
                      },
                      title: const Text('Mode Hantu (Ghost Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Sembunyikan lokasi Anda sementara dari peta grup.'),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isGhostMode 
                              ? theme.colorScheme.error.withOpacity(0.1) // ignore: deprecated_member_use
                              : theme.colorScheme.secondary.withOpacity(0.1), // ignore: deprecated_member_use
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isGhostMode ? Icons.visibility_off : Icons.visibility,
                          color: _isGhostMode ? theme.colorScheme.error : theme.colorScheme.secondary,
                        ),
                      ),
                      activeTrackColor: theme.colorScheme.error.withOpacity(0.5), // ignore: deprecated_member_use
                      activeThumbColor: theme.colorScheme.error,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // === MENU PENGATURAN ===
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'PENGATURAN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                      ),
                    ),
                    child: Column(
                      children: [
                        // Preferensi
                        _buildMenuTile(
                          theme,
                          icon: Icons.tune,
                          iconColor: Colors.blue,
                          title: 'Preferensi',
                          subtitle: 'Bahasa, tampilan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PreferencesPage()),
                            );
                          },
                        ),
                        _buildMenuDivider(theme),
                        // Akun
                        _buildMenuTile(
                          theme,
                          icon: Icons.manage_accounts_outlined,
                          iconColor: Colors.teal,
                          title: 'Akun',
                          subtitle: 'Profil, password, hapus akun',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AccountPage()),
                            );
                          },
                        ),
                        _buildMenuDivider(theme),
                        // Kebijakan Privasi
                        _buildMenuTile(
                          theme,
                          icon: Icons.privacy_tip_outlined,
                          iconColor: Colors.orange,
                          title: 'Kebijakan Privasi',
                          subtitle: 'Baca kebijakan privasi kami',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  // Tombol Log Out
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Versi Aplikasi
                  Text(
                    'Trackie v1.0.0',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary.withOpacity(0.5), // ignore: deprecated_member_use
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1), // ignore: deprecated_member_use
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.secondary),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildMenuDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: theme.colorScheme.secondary.withOpacity(0.15), // ignore: deprecated_member_use
    );
  }
}
