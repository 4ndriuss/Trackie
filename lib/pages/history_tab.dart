import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'trip_detail_page.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

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

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  static final List<TripHistory> _dummyHistory = [
    TripHistory(
      id: '1',
      groupName: 'Touring Lembang',
      destination: 'Gunung Tangkuban Perahu',
      date: DateTime.now().subtract(const Duration(days: 2)),
      distanceKm: 42.5,
      duration: '1h 45m',
      role: 'Host',
      members: 12,
      avgSpeed: 45.2,
      maxSpeed: 70.0,
      routePoints: [const LatLng(-6.814, 107.618), const LatLng(-6.759, 107.609)],
    ),
    TripHistory(
      id: '2',
      groupName: 'Sunday Morning Ride',
      destination: 'Pangaloan, Ciwidey',
      date: DateTime.now().subtract(const Duration(days: 9)),
      distanceKm: 120.3,
      duration: '4h 20m',
      role: 'Member',
      members: 45,
      avgSpeed: 50.1,
      maxSpeed: 85.0,
      routePoints: [const LatLng(-6.914, 107.609), const LatLng(-7.100, 107.450)],
    ),
    TripHistory(
      id: '3',
      groupName: 'Night Ride City',
      destination: 'Gedung Sate',
      date: DateTime.now().subtract(const Duration(days: 15)),
      distanceKm: 15.0,
      duration: '45m',
      role: 'Member',
      members: 8,
      avgSpeed: 30.5,
      maxSpeed: 55.0,
      routePoints: [const LatLng(-6.914, 107.609), const LatLng(-6.902, 107.618)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('id');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA), // Match profile page
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)?.navHistory ?? 'History',
          style: GoogleFonts.urbanist(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFEDEDF2),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: _dummyHistory.isEmpty
            ? Center(
                child: Text(
                  'Belum ada riwayat perjalanan',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    color: const Color(0xFF6B6F9A),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                itemCount: _dummyHistory.length,
                itemBuilder: (context, index) {
                  final trip = _dummyHistory[index];
                  
                  // Date Formatting "12 Oct 2026, 14:30"
                  final dateStr = DateFormat('dd MMM yyyy').format(trip.date);
                  final timeStr = DateFormat('HH:mm').format(trip.date);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEDEDF2), width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailPage(trip: trip),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Title & Badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip.groupName,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A2E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$dateStr at $timeStr',
                                          style: GoogleFonts.urbanist(
                                            fontSize: 13,
                                            color: const Color(0xFF6B6F9A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: trip.role == 'Host' 
                                          ? AppTheme.primary.withOpacity(0.15) 
                                          : const Color(0xFFF1F1F5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      trip.role,
                                      style: GoogleFonts.urbanist(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: trip.role == 'Host' 
                                            ? AppTheme.primary 
                                            : const Color(0xFF6B6F9A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Middle Row: Icon & Destination
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F1F5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.location_on_outlined, color: Color(0xFF6B6F9A), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Destination',
                                          style: GoogleFonts.urbanist(
                                            fontSize: 13,
                                            color: const Color(0xFF6B6F9A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          trip.destination,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1A1A2E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Bottom Ribbon: Metrics
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatMetric(Icons.route_outlined, '${numberFormat.format(trip.distanceKm)} km'),
                                    _buildStatMetric(Icons.schedule_outlined, trip.duration),
                                    _buildStatMetric(Icons.speed_outlined, '${numberFormat.format(trip.avgSpeed)} km/h'),
                                    _buildStatMetric(Icons.group_outlined, '${trip.members} pax'),
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
    );
  }

  Widget _buildStatMetric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B6F9A)),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.urbanist(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
