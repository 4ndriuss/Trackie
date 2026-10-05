import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'trip_detail_page.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

// Dummy data model
/// Model data untuk merepresentasikan riwayat perjalanan grup.
class TripHistory {
  final String id;
  final String groupName;
  final String destination;
  final DateTime date;
  final double distanceKm;
  final String duration;
  final List<LatLng> routePoints;
  final String role;
  final int members;
  final double avgSpeed;
  final double maxSpeed;

  const TripHistory({
    required this.id,
    required this.groupName,
    required this.destination,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.routePoints,
    required this.role,
    required this.members,
    required this.avgSpeed,
    required this.maxSpeed,
  });
}

/// [HistoryTab] menampilkan daftar perjalanan yang pernah diikuti pengguna.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  static final List<TripHistory> _dummyHistory = [
    TripHistory(
      id: '1',
      groupName: 'Touring Lembang',
      destination: 'Gunung Tangkuban Perahu',
      date: DateTime.now().subtract(const Duration(days: 2)),
      distanceKm: 42.5,
      duration: '1j 45m',
      role: 'Host',
      members: 12,
      avgSpeed: 45.5,
      maxSpeed: 80.2,
      routePoints: const [
        LatLng(-6.814343, 107.614660),
        LatLng(-6.820000, 107.618000),
        LatLng(-6.830000, 107.612000),
        LatLng(-6.840000, 107.605000),
      ],
    ),
    TripHistory(
      id: '2',
      groupName: 'City Ride Jakarta',
      destination: 'Monumen Nasional',
      date: DateTime.now().subtract(const Duration(days: 7)),
      distanceKm: 15.2,
      duration: '45m',
      role: 'Member',
      members: 5,
      avgSpeed: 25.0,
      maxSpeed: 55.0,
      routePoints: const [
        LatLng(-6.200000, 106.816666),
        LatLng(-6.205000, 106.820000),
        LatLng(-6.210000, 106.825000),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListEmpty = _dummyHistory.isEmpty;

    // Hitung total stat
    final totalKm = _dummyHistory.fold(0.0, (sum, trip) => sum + trip.distanceKm);
    final numberFormat = NumberFormat.decimalPattern('id');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              AppLocalizations.of(context)!.navHistory,
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
          ),
          
          if (isListEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 80,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Belum ada riwayat',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Mulai touring pertamamu dan catat perjalananmu di sini!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Header Ringkasan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Bulan ini • ${_dummyHistory.length} trip • ${numberFormat.format(totalKm)} km',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Daftar Riwayat (menggunakan Card style)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _dummyHistory.length,
                itemBuilder: (context, index) {
                  final trip = _dummyHistory[index];
                  final dateFormat = DateFormat('d MMM yyyy', 'id_ID'); // e.g. 12 Okt 2026
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(trip: trip),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thumbnail Rute (Mini map placeholder)
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.map_outlined,
                                      size: 32,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  
                                  // Info Utama
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip.groupName, // Nama Trip sbg Judul
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 14, color: theme.colorScheme.secondary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                trip.destination, // Lokasi
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.secondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateFormat.format(trip.date), // Tanggal
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Badge Peran
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: trip.role == 'Host' ? theme.primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          trip.role,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: trip.role == 'Host' ? theme.primaryColor : Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: AppSpacing.md),
                              
                              // Statistik Bawah
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMiniStat(theme, Icons.route, '${numberFormat.format(trip.distanceKm)} km'),
                                    _buildMiniStat(theme, Icons.timer_outlined, trip.duration),
                                    _buildMiniStat(theme, Icons.speed, '${numberFormat.format(trip.avgSpeed)} km/j'),
                                    _buildMiniStat(theme, Icons.people_alt_outlined, '${trip.members}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
