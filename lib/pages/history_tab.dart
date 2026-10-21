import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'trip_detail_page.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/trip_history_model.dart';
import '../providers/auth_provider.dart';
import '../services/trip_service.dart';

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
  final String? journalNote;
  final double? rating;

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
    this.journalNote,
    this.rating,
  });

  factory TripHistory.fromModel(TripHistoryModel model) {
    final avg = model.avgSpeedKmh;
    return TripHistory(
      id: model.id,
      groupName: model.displayGroupName,
      destination: model.destinationName,
      date: model.endedAt,
      distanceKm: model.distanceKm,
      duration: model.duration.isNotEmpty ? model.duration : '1m',
      routePoints: model.routePoints,
      role: model.role,
      members: model.memberCount,
      avgSpeed: avg,
      maxSpeed: double.parse((avg * 1.35).toStringAsFixed(1)),
      journalNote: model.journalNote,
      rating: model.rating,
    );
  }
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final TripService _tripService = TripService();
  StreamSubscription<List<TripHistoryModel>>? _tripSubscription;
  List<TripHistoryModel>? _tripHistory;
  bool _isLoading = true;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    _subscribeToTripHistory(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUid = context.watch<AuthProvider>().user?.uid;
    if (currentUid != _subscribedUid) {
      _subscribeToTripHistory(currentUid);
    }
  }

  void _subscribeToTripHistory(String? uid) {
    _subscribedUid = uid;
    _tripSubscription?.cancel();
    _tripSubscription = null;

    if (uid == null) {
      setState(() {
        _tripHistory = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _tripSubscription = _tripService.streamTripHistory(uid).listen(
      (data) {
        if (mounted) {
          setState(() {
            _tripHistory = data;
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        debugPrint('Error streaming trip history: $err');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _tripSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('id');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).cardColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)?.navHistory ?? 'History',
          style: GoogleFonts.urbanist(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).dividerColor,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: _subscribedUid == null
            ? Center(
                child: Text(
                  'Silakan login untuk melihat riwayat perjalanan',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    color: const Color(0xFF6B6F9A),
                  ),
                ),
              )
            : _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _buildTripContent(numberFormat),
      ),
    );
  }

  Widget _buildTripContent(NumberFormat numberFormat) {
    final models = _tripHistory ?? const <TripHistoryModel>[];
    final historyList = models.map(TripHistory.fromModel).toList();

    if (historyList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.route_rounded,
                                size: 42,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada riwayat perjalanan',
                              style: GoogleFonts.urbanist(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Perjalanan grup yang telah selesai akan otomatis tersimpan dan tampil di halaman ini.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                fontSize: 14,
                                color: const Color(0xFF6B6F9A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final trip = historyList[index];
                      final dateStr =
                          DateFormat('dd MMM yyyy').format(trip.date);
                      final timeStr = DateFormat('HH:mm').format(trip.date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trip.groupName,
                                              style: GoogleFonts.urbanist(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSurface,
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: trip.role == 'Host'
                                              ? AppTheme.primary
                                                  .withValues(alpha: 0.15)
                                              : const Color(0xFFF1F1F5),
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_outlined,
                                          color: Color(0xFF6B6F9A),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                color: Theme.of(context).colorScheme.onSurface,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white10
                                          : const Color(0xFFF7F7FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatMetric(
                                          Icons.route_outlined,
                                          '${numberFormat.format(trip.distanceKm)} km',
                                        ),
                                        _buildStatMetric(
                                          Icons.schedule_outlined,
                                          trip.duration,
                                        ),
                                        _buildStatMetric(
                                          Icons.speed_outlined,
                                          '${numberFormat.format(trip.avgSpeed)} km/h',
                                        ),
                                        _buildStatMetric(
                                          Icons.group_outlined,
                                          '${trip.members} pax',
                                        ),
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
