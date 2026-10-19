import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// [PrivacyPolicyPage] menampilkan halaman Kebijakan Privasi aplikasi Trackie.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1), // ignore: deprecated_member_use
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: theme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                'Terakhir diperbarui: 1 Oktober 2026',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            _buildSection(
              theme,
              '1. Pendahuluan',
              'Selamat datang di Trackie. Kami menghargai privasi Anda dan berkomitmen '
                  'untuk melindungi data pribadi Anda. Kebijakan privasi ini menjelaskan '
                  'bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi Anda '
                  'saat menggunakan aplikasi Trackie.',
            ),
            _buildSection(
              theme,
              '2. Data yang Kami Kumpulkan',
              '• Informasi Akun: Nama, email, dan informasi kendaraan yang Anda berikan '
                  'saat mendaftar.\n'
                  '• Data Lokasi: Lokasi GPS Anda selama sesi touring untuk keperluan pelacakan '
                  'real-time dan riwayat perjalanan.\n'
                  '• Data Penggunaan: Statistik perjalanan seperti jarak tempuh, durasi, '
                  'dan frekuensi touring.',
            ),
            _buildSection(
              theme,
              '3. Penggunaan Data',
              'Data Anda digunakan untuk:\n'
                  '• Menyediakan fitur pelacakan lokasi secara real-time dalam grup touring.\n'
                  '• Menyimpan dan menampilkan riwayat perjalanan Anda.\n'
                  '• Meningkatkan pengalaman pengguna dan performa aplikasi.\n'
                  '• Mengirimkan notifikasi terkait aktivitas touring.',
            ),
            _buildSection(
              theme,
              '4. Berbagi Data',
              'Lokasi Anda hanya dibagikan kepada anggota grup touring yang Anda ikuti. '
                  'Anda dapat mengaktifkan Mode Hantu (Ghost Mode) kapan saja untuk '
                  'menyembunyikan lokasi Anda dari peta grup.\n\n'
                  'Kami tidak menjual atau membagikan data pribadi Anda kepada pihak ketiga '
                  'untuk tujuan komersial.',
            ),
            _buildSection(
              theme,
              '5. Penyimpanan & Keamanan Data',
              'Data Anda disimpan secara aman menggunakan infrastruktur database Supabase '
                  'dengan enkripsi standar industri. Kami menerapkan langkah-langkah keamanan '
                  'yang wajar untuk melindungi data Anda dari akses tidak sah.',
            ),
            _buildSection(
              theme,
              '6. Hak Anda',
              'Anda memiliki hak untuk:\n'
                  '• Mengakses dan memperbarui informasi profil Anda.\n'
                  '• Menghapus akun dan semua data terkait.\n'
                  '• Mengontrol visibilitas lokasi melalui Mode Hantu.\n'
                  '• Menonaktifkan pelacakan lokasi kapan saja.',
            ),
            _buildSection(
              theme,
              '7. Perubahan Kebijakan',
              'Kami dapat memperbarui kebijakan privasi ini dari waktu ke waktu. '
                  'Perubahan signifikan akan diberitahukan melalui aplikasi. '
                  'Penggunaan berkelanjutan atas aplikasi setelah perubahan berarti '
                  'Anda menyetujui kebijakan yang diperbarui.',
            ),
            _buildSection(
              theme,
              '8. Hubungi Kami',
              'Jika Anda memiliki pertanyaan tentang kebijakan privasi ini, '
                  'silakan hubungi kami di:\n\n'
                  '📧 support@trackie.app',
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
