// File: home_tab.dart
// Tab Beranda (Home) yang muncul pertama kali di [MainPage].
// Menyediakan pilihan bagi pengguna untuk membuat perjalanan baru (sebagai Host)
// atau bergabung dengan perjalanan yang sudah ada (menggunakan kode undangan).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import 'map_page.dart';

/// Halaman Beranda utama [HomeTab] bagi pengguna.
/// Menyediakan akses cepat untuk membuat perjalanan baru (Host) atau
/// bergabung ke perjalanan yang sudah ada via kode undangan.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {

  /// Menampilkan modal bawah (bottom sheet) untuk membuat grup/perjalanan baru.
  void _showCreateGroupModal(BuildContext context) {
    final groupNameController = TextEditingController();
    final destinationController = TextEditingController();
    String? selectedVehicleType;
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Agar modal bisa menyesuaikan saat keyboard muncul
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                    AppLocalizations.of(context)!.homeCreateTripTitle,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Input nama grup
                  CustomTextField(
                    label: 'Nama Grup',
                    hint: 'contoh: Touring Lembang',
                    controller: groupNameController,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Input tujuan
                  CustomTextField(
                    label: 'Tujuan Pergi',
                    hint: 'contoh: Kawah Putih, Ciwidey',
                    controller: destinationController,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('TIPE KENDARAAN', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  // Dropdown untuk memilih jenis kendaraan yang digunakan grup
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(),
                    items: ['Motor', 'Mobil', 'Sepeda'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedVehicleType = val;
                      });
                    },
                    hint: Text(
                      'Pilih Tipe Kendaraan',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)), // ignore: deprecated_member_use
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Tombol Mulai
                  ElevatedButton(
                    onPressed: isCreating ? null : () async {
                      if (groupNameController.text.trim().isEmpty || destinationController.text.trim().isEmpty || selectedVehicleType == null) return;
                      setModalState(() => isCreating = true);
                      
                      final authProvider = context.read<AuthProvider>();
                      final groupProvider = context.read<GroupProvider>();
                      
                      final success = await groupProvider.createGroup(
                        name: groupNameController.text.trim(),
                        type: selectedVehicleType!,
                        destination: destinationController.text.trim(),
                        hostUid: authProvider.user!.uid,
                      );
                      
                      if (!context.mounted) return;
                      
                      if (success) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage(isHost: true)));
                      } else {
                        setModalState(() => isCreating = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(groupProvider.error ?? 'Gagal membuat grup')),
                        );
                      }
                    },
                    child: isCreating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('MULAI'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          }
        );
      },
    ).whenComplete(() {
      groupNameController.dispose();
      destinationController.dispose();
    });
  }

  /// Menampilkan modal bawah (bottom sheet) untuk bergabung dengan grup/perjalanan yang sudah ada.
  void _showJoinGroupModal(BuildContext context) {
    final inviteCodeController = TextEditingController();
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                    AppLocalizations.of(context)!.homeJoinTripTitle,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Input kode undangan
                  CustomTextField(
                    label: 'Kode Undangan',
                    hint: 'contoh: TRG-42A',
                    controller: inviteCodeController,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Tombol Gabung
                  ElevatedButton(
                    onPressed: isJoining ? null : () async {
                      if (inviteCodeController.text.trim().isEmpty) return;
                      setModalState(() => isJoining = true);
                      
                      final authProvider = context.read<AuthProvider>();
                      final groupProvider = context.read<GroupProvider>();
                      
                      final success = await groupProvider.joinGroup(
                        inviteCode: inviteCodeController.text.trim(),
                        uid: authProvider.user!.uid,
                      );
                      
                      if (!context.mounted) return;
                      
                      if (success) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage(isHost: false)));
                      } else {
                        setModalState(() => isJoining = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(groupProvider.error ?? 'Gagal bergabung grup')),
                        );
                      }
                    },
                    child: isJoining ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('GABUNG'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          }
        );
      },
    ).whenComplete(() {
      inviteCodeController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final userProfile = authProvider.userProfile;
    
    final bool hasActiveTrip = groupProvider.hasActiveGroup;
    final String activeTripName = groupProvider.activeGroup?.name ?? 'Perjalanan';
    final String userName = userProfile?.name ?? 'Rider';
    final String firstName = userName.split(' ')[0];
    
    // Data Dummy untuk presentasi UI
    final List<Map<String, dynamic>> upcomingTrips = [
      {
        'title': 'Sunmori Puncak Pas',
        'date': '12',
        'month': 'OKT',
        'time': '06:00',
        'relativeTime': '8 hari lagi',
        'meetingPoint': 'SPBU X',
        'members': 8,
        'role': 'Member',
      },
      {
        'title': 'Touring Lintas Provinsi',
        'date': '20',
        'month': 'OKT',
        'time': '05:30',
        'relativeTime': '2 minggu lagi',
        'meetingPoint': 'Rest Area KM 57',
        'members': 14,
        'role': 'Host',
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
              AppLocalizations.of(context)!.homeGreeting(firstName),
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context)!.homeSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 1. Banner Perjalanan Aktif (Active Trip)
            if (hasActiveTrip) ...[
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.error, // Pakai warna merah/tertiary agar mencolok
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapPage(isHost: false),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.homeActiveTrip,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeTripName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Buka Peta',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ] else ...[
              // Banner Countdown Trip Terdekat
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  upcomingTrips[0]['date'],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  upcomingTrips[0]['month'],
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trip terdekat: ${upcomingTrips[0]['relativeTime']}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  upcomingTrips[0]['title'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: theme.colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
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
                    icon: const Icon(Icons.route),
                    label: Text(AppLocalizations.of(context)!.homeCreate),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showJoinGroupModal(context),
                    icon: const Icon(Icons.group_add),
                    label: Text(AppLocalizations.of(context)!.homeJoin),
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
                  AppLocalizations.of(context)!.homeUpcoming,
                  style: theme.textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(AppLocalizations.of(context)!.homeSeeAll),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            
            if (upcomingTrips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bike,
                      size: 64,
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Belum ada trip.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buat trip pertamamu atau gabung dengan kode.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...upcomingTrips.map((trip) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            // Blok Tanggal
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    trip['date'],
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    trip['month'],
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            
                            // Info Trip
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          trip['title'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: theme.colorScheme.secondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Titik kumpul: ${trip['meetingPoint']}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.secondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Badge Role
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: trip['role'] == 'Host' ? theme.primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          trip['role'],
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: trip['role'] == 'Host' ? theme.primaryColor : Colors.grey[700],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Member Count
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.people, size: 10, color: theme.primaryColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${trip['members']} peserta',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.primaryColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Waktu & Chevron
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  trip['time'],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Icon(Icons.chevron_right, color: theme.colorScheme.secondary, size: 20),
                              ],
                            ),
                          ],
                        ),
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
