// File: home_tab.dart
// Tab Beranda (Home) yang muncul pertama kali di [MainPage].
// Menyediakan pilihan bagi pengguna untuk membuat perjalanan baru (sebagai Host)
// atau bergabung dengan perjalanan yang sudah ada (menggunakan kode undangan).
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';
import 'map_page.dart';

/// [HomeTab] adalah widget stateless yang menampilkan menu utama aplikasi.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  /// Menampilkan modal bawah (bottom sheet) untuk membuat grup/perjalanan baru.
  void _showCreateGroupModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Agar modal bisa menyesuaikan saat keyboard muncul
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          // Memberikan padding bawah sesuai tinggi keyboard (viewInsets.bottom)
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Tinggi kolom menyesuaikan konten
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Buat Perjalanan Baru',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.md),
              // Input nama grup
              const CustomTextField(
                label: 'Nama Grup',
                hint: 'contoh: Touring Lembang',
              ),
              const SizedBox(height: AppSpacing.md),
              Text('TIPE KENDARAAN', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              // Dropdown untuk memilih jenis kendaraan yang digunakan grup
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(),
                items: ['Motor', 'Mobil', 'Sepeda'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (_) {},
                hint: const Text('Pilih Tipe Kendaraan'),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Tombol Mulai
              ElevatedButton(
                onPressed: () {
                  // Menutup modal
                  Navigator.pop(context);
                  // Pindah ke MapPage sebagai pembuat grup (host)
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage(isHost: true)));
                },
                child: const Text('MULAI'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  /// Menampilkan modal bawah (bottom sheet) untuk bergabung dengan grup/perjalanan yang sudah ada.
  void _showJoinGroupModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gabung Perjalanan',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.md),
              // Input kode undangan
              const CustomTextField(
                label: 'Kode Undangan',
                hint: 'contoh: TRG-42A',
              ),
              const SizedBox(height: AppSpacing.xl),
              // Tombol Gabung
              ElevatedButton(
                onPressed: () {
                  // Menutup modal
                  Navigator.pop(context);
                  // Pindah ke MapPage bukan sebagai host (isHost = false)
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage(isHost: false)));
                },
                child: const Text('GABUNG'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            // Teks sambutan
            Text(
              'Halo, Rider!',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Siap untuk perjalanan hari ini?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Tombol utama untuk membuat perjalanan (warna solid)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              ),
              onPressed: () => _showCreateGroupModal(context),
              child: const Text('BUAT PERJALANAN BARU'),
            ),
            const SizedBox(height: AppSpacing.md),
            // Tombol sekunder untuk bergabung perjalanan (warna outline)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 16),
              ),
              onPressed: () => _showJoinGroupModal(context),
              child: const Text('GABUNG PERJALANAN'),
            ),
          ],
        ),
      ),
    );
  }
}
