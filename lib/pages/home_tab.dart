// File: home_tab.dart
// Tab Beranda (Home) yang muncul pertama kali di [MainPage].
// Menyediakan pilihan bagi pengguna untuk membuat perjalanan baru (sebagai Host)
// atau bergabung dengan perjalanan yang sudah ada (menggunakan kode undangan).
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';
import 'map_page.dart';

/// Halaman Beranda utama [HomeTab] bagi pengguna.
/// Menyediakan akses cepat untuk membuat perjalanan baru (Host) atau
/// bergabung ke perjalanan yang sudah ada via kode undangan.
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
    final theme = Theme.of(context);
    
    // Data Dummy untuk presentasi UI
    final bool hasActiveTrip = true;
    final List<Map<String, dynamic>> upcomingTrips = [
      {
        'title': 'Sunmori Puncak Pas',
        'date': '12 Okt 2026 • 06:00',
        'members': 8,
      },
      {
        'title': 'Touring Lintas Provinsi',
        'date': '20 Okt 2026 • 05:30',
        'members': 14,
      },
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Halo, Rider! 👋',
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Siap untuk perjalanan hari ini?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 1. Banner Perjalanan Aktif (Active Trip)
            if (hasActiveTrip) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error, // Pakai warna merah/tertiary agar mencolok
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withOpacity(0.3), // ignore: deprecated_member_use
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // ignore: deprecated_member_use
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sedang dalam perjalanan',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Touring Bali 2026',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapPage(isHost: false),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 2. Tombol Aksi Cepat (Buat & Gabung)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateGroupModal(context),
                    icon: const Icon(Icons.add_road),
                    label: const Text('Buat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showJoinGroupModal(context),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Gabung'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: theme.textTheme.labelSmall?.copyWith(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 3. Jadwal Akan Datang (Upcoming Trips)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jadwal Mendatang',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            ...upcomingTrips.map((trip) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withOpacity(0.2), // ignore: deprecated_member_use
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1), // ignore: deprecated_member_use
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_month, color: theme.colorScheme.secondary),
                  ),
                  title: Text(
                    trip['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: theme.colorScheme.secondary),
                        const SizedBox(width: 4),
                        Text(trip['date']),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1), // ignore: deprecated_member_use
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 14, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${trip['members']}',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
