import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/location_provider.dart';

/// [AccountPage] menampilkan halaman pengaturan akun pengguna.
/// Menyediakan fitur edit profil, ubah password, dan hapus akun.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === INFORMASI AKUN ===
            _buildSectionTitle(theme, 'Informasi Akun'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2), // ignore: deprecated_member_use
                ),
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                    theme,
                    icon: Icons.person_outline,
                    label: 'Nama',
                    value: userProfile?.name ?? '-',
                  ),
                  _buildDivider(theme),
                  _buildInfoTile(
                    theme,
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: userProfile?.email ?? '-',
                  ),
                  _buildDivider(theme),
                  _buildInfoTile(
                    theme,
                    icon: Icons.two_wheeler,
                    label: 'Kendaraan',
                    value: (userProfile?.vehicle != null && userProfile!.vehicle.isNotEmpty) 
                        ? userProfile.vehicle 
                        : '-',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // === PENGATURAN AKUN ===
            _buildSectionTitle(theme, 'Pengaturan Akun'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2), // ignore: deprecated_member_use
                ),
              ),
              child: Column(
                children: [
                  // Edit Profil
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1), // ignore: deprecated_member_use
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_outlined, color: theme.primaryColor, size: 20),
                    ),
                    title: const Text('Edit Profil', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Ubah nama dan informasi kendaraan'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.secondary),
                    onTap: () => _showEditProfileDialog(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  _buildDivider(theme),
                  // Ubah Password
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1), // ignore: deprecated_member_use
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline, color: theme.primaryColor, size: 20),
                    ),
                    title: const Text('Ubah Password', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Perbarui kata sandi akun Anda'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.secondary),
                    onTap: () => _showChangePasswordDialog(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // === ZONA BAHAYA ===
            _buildSectionTitle(theme, 'Zona Bahaya'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3), // ignore: deprecated_member_use
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1), // ignore: deprecated_member_use
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error, size: 20),
                ),
                title: Text(
                  'Hapus Akun',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
                subtitle: const Text('Hapus akun dan semua data secara permanen'),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
                onTap: () => _showDeleteAccountDialog(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.secondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile(ThemeData theme, {required IconData icon, required String label, required String value}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1), // ignore: deprecated_member_use
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.secondary, size: 20),
      ),
      title: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: theme.colorScheme.secondary.withValues(alpha: 0.15), // ignore: deprecated_member_use
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final userProfile = authProvider.userProfile;
    final nameController = TextEditingController(text: userProfile?.name ?? '');
    final vehicleController = TextEditingController(text: userProfile?.vehicle ?? '');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(
                labelText: 'Kendaraan',
                prefixIcon: Icon(Icons.two_wheeler),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );

    final newName = nameController.text.trim();
    final newVehicle = vehicleController.text.trim();
    nameController.dispose();
    vehicleController.dispose();

    if (shouldSave == true && context.mounted) {
      final success = await authProvider.updateProfile(
        name: newName,
        vehicle: newVehicle,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '✅ Profil berhasil diperbarui' : '❌ Gagal memperbarui profil',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final email = authProvider.userProfile?.email ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Password'),
        content: Text(
          'Kami akan mengirimkan link reset password ke email:\n\n$email\n\n'
          'Silakan cek inbox Anda setelah menekan tombol Kirim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (email.isNotEmpty) {
                final success = await authProvider.resetPassword(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '📧 Link reset password telah dikirim ke $email'
                            : '❌ Gagal mengirim email reset password',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('KIRIM'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: const Text(
          '⚠️ Tindakan ini tidak dapat dibatalkan!\n\n'
          'Semua data Anda termasuk riwayat perjalanan, statistik, dan informasi profil '
          'akan dihapus secara permanen.\n\n'
          'Apakah Anda yakin ingin menghapus akun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final locationProvider = context.read<LocationProvider>();
              final groupProvider = context.read<GroupProvider>();
              await locationProvider.stopTracking(
                groupId: groupProvider.activeGroup?.id,
                uid: context.read<AuthProvider>().user?.uid,
              );
              groupProvider.clearActiveGroup();
              if (!context.mounted) return;
              final authProvider = context.read<AuthProvider>();
              final success = await authProvider.deleteAccount();
              if (!context.mounted) return;
              if (success) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(authProvider.error ?? 'Gagal menghapus akun.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('HAPUS AKUN'),
          ),
        ],
      ),
    );
  }
}
