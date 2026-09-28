import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'trip_detail_page.dart';
import '../theme/app_theme.dart';

// Dummy data model
class TripHistory {
  final String id;
  final String title;
  final DateTime date;
  final double distanceKm;
  final String duration;
  final List<LatLng> routePoints;

  const TripHistory({
    required this.id,
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.routePoints,
  });
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  static final List<TripHistory> _dummyHistory = [
    TripHistory(
      id: '1',
      title: 'Touring Lembang',
      date: DateTime.now().subtract(const Duration(days: 2)),
      distanceKm: 42.5,
      duration: '1j 45m',
      routePoints: const [
        LatLng(-6.814343, 107.614660),
        LatLng(-6.820000, 107.618000),
        LatLng(-6.830000, 107.612000),
        LatLng(-6.840000, 107.605000),
      ],
    ),
    TripHistory(
      id: '2',
      title: 'City Ride Jakarta',
      date: DateTime.now().subtract(const Duration(days: 7)),
      distanceKm: 15.2,
      duration: '45m',
      routePoints: const [
        LatLng(-6.200000, 106.816666),
        LatLng(-6.205000, 106.820000),
        LatLng(-6.210000, 106.825000),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Riwayat',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _dummyHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final trip = _dummyHistory[index];
                return ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Theme.of(context).primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.route, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(
                    trip.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  subtitle: Text(
                    '${trip.date.day}/${trip.date.month}/${trip.date.year}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${trip.distanceKm} km',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            trip.duration,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailPage(trip: trip),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
