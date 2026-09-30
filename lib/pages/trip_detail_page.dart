import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import 'history_tab.dart'; // To access TripHistory model

/// Halaman [TripDetailPage] menampilkan detail rute perjalanan dari histori.
/// Merender `GoogleMap` statis yang memperlihatkan polyline rute dan ringkasan 
/// informasi jarak serta durasi perjalanan.
class TripDetailPage extends StatefulWidget {
  final TripHistory trip;

  const TripDetailPage({super.key, required this.trip});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final _mapController = Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialPosition = widget.trip.routePoints.isNotEmpty
        ? widget.trip.routePoints.first
        : const LatLng(-6.200000, 106.816666);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Perjalanan'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 13.0,
              ),
              polylines: {
                if (widget.trip.routePoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('route_path'),
                    points: widget.trip.routePoints,
                    color: theme.colorScheme.primary,
                    width: 4,
                  ),
              },
              markers: {
                if (widget.trip.routePoints.isNotEmpty) ...[
                  Marker(
                    markerId: const MarkerId('start'),
                    position: widget.trip.routePoints.first,
                    infoWindow: const InfoWindow(title: 'Titik Awal'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                  Marker(
                    markerId: const MarkerId('end'),
                    position: widget.trip.routePoints.last,
                    infoWindow: const InfoWindow(title: 'Titik Akhir'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                ]
              },
              onMapCreated: (c) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(c);
                  
                  // Adjust camera bounds to fit the route
                  if (widget.trip.routePoints.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      double minLat = widget.trip.routePoints.first.latitude;
                      double maxLat = widget.trip.routePoints.first.latitude;
                      double minLng = widget.trip.routePoints.first.longitude;
                      double maxLng = widget.trip.routePoints.first.longitude;
                      
                      for (var point in widget.trip.routePoints) {
                        if (point.latitude < minLat) minLat = point.latitude;
                        if (point.latitude > maxLat) maxLat = point.latitude;
                        if (point.longitude < minLng) minLng = point.longitude;
                        if (point.longitude > maxLng) maxLng = point.longitude;
                      }
                      
                      c.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(minLat, minLng),
                            northeast: LatLng(maxLat, maxLng),
                          ),
                          50.0, // padding
                        ),
                      );
                    });
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trip.title,
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${widget.trip.date.day}/${widget.trip.date.month}/${widget.trip.date.year}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        context,
                        icon: Icons.map_outlined,
                        label: 'Total Jarak',
                        value: '${widget.trip.distanceKm} km',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: theme.dividerColor,
                      ),
                      _buildStatCard(
                        context,
                        icon: Icons.timer_outlined,
                        label: 'Durasi',
                        value: widget.trip.duration,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
