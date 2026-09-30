import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import '../main.dart';

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
            onPressed: () {
              Navigator.pop(ctx); // Tutup dialog
              // Arahkan kembali ke halaman Login dan hapus seluruh riwayat halaman
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
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
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.primaryColor.withOpacity(0.1), // ignore: deprecated_member_use
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Nama Pengguna
                  Text(
                    'John Doe',
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
                          'NMAX Hitam',
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
                        _buildStatItem(context, 'Total Jarak', '2.450', 'km'),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                        ),
                        _buildStatItem(context, 'Touring', '12', 'kali'),
                        Container(
                          width: 1,
                          height: 40,
                          color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                        ),
                        _buildStatItem(context, 'Rank', 'Veteran', '⭐️'),
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
                  const SizedBox(height: AppSpacing.md),
                  
                  // Pengaturan Tema (Light/Dark Mode)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                      ),
                    ),
                    child: ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, child) {
                        final isDark = currentMode == ThemeMode.dark;
                        return SwitchListTile(
                          value: isDark,
                          onChanged: (value) {
                            themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                          },
                          title: const Text('Mode Gelap (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Ubah tampilan aplikasi menjadi gelap.'),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? theme.primaryColor.withOpacity(0.1) // ignore: deprecated_member_use
                                  : theme.colorScheme.secondary.withOpacity(0.1), // ignore: deprecated_member_use
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: isDark ? theme.primaryColor : theme.colorScheme.secondary,
                            ),
                          ),
                          activeTrackColor: theme.primaryColor.withOpacity(0.5), // ignore: deprecated_member_use
                          activeThumbColor: theme.primaryColor,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  // Tombol Edit Profile
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur Edit Profil akan segera hadir!')),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
