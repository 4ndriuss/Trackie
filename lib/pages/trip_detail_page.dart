import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import 'history_tab.dart'; // To access TripHistory model

/// Halaman [TripDetailPage] menampilkan detail rute perjalanan dari histori.
/// Merender `FlutterMap` (OpenStreetMap) yang memperlihatkan polyline rute dan
/// ringkasan informasi jarak serta durasi perjalanan.
class TripDetailPage extends StatefulWidget {
  final TripHistory trip;

  const TripDetailPage({super.key, required this.trip});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  final MapController _mapController = MapController();
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Membuat teks ringkasan perjalanan untuk dibagikan.
  String _buildShareText() {
    final trip = widget.trip;
    final dateStr = '${trip.date.day}/${trip.date.month}/${trip.date.year}';
    final routeInfo = trip.routePoints.isNotEmpty
        ? '\n🗺️ Rute dimulai dari (${trip.routePoints.first.latitude.toStringAsFixed(4)}, '
            '${trip.routePoints.first.longitude.toStringAsFixed(4)}) '
            'hingga (${trip.routePoints.last.latitude.toStringAsFixed(4)}, '
            '${trip.routePoints.last.longitude.toStringAsFixed(4)})\n'
        : '';
    return '🏍️ *${trip.groupName} - ${trip.destination}*\n'
        '📅 $dateStr\n'
        '📏 Jarak: ${trip.distanceKm} km\n'
        '⏱️ Durasi: ${trip.duration}\n'
        '$routeInfo'
        '\n'
        '— Dibagikan dari Trackie 🏁';
  }

  /// Capture widget menjadi gambar untuk dibagikan.
  Future<Uint8List?> _captureShareCard() async {
    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Bagikan teks perjalanan menggunakan share sheet native.
  Future<void> _shareAsText() async {
    final text = _buildShareText();
    await SharePlus.instance.share(
      ShareParams(text: text),
    );
  }

  /// Bagikan sebagai gambar (capture share card widget).
  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);

    try {
      // Beri waktu agar widget render selesai
      await Future.delayed(const Duration(milliseconds: 100));
      final imageBytes = await _captureShareCard();

      if (imageBytes != null) {
        final xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'trackie_trip_${widget.trip.id}.png',
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: _buildShareText(),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Gagal membuat gambar. Mencoba bagikan sebagai teks...'),
            ),
          );
          await _shareAsText();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Terjadi kesalahan saat berbagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// Tampilkan bottom sheet dengan opsi berbagi.
  void _showShareBottomSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Bagikan Perjalanan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih cara berbagi hasil perjalanan Anda',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Preview card (mini)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.route, color: theme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.trip.destination,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              widget.trip.groupName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.trip.distanceKm} km  •  ${widget.trip.duration}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Share options grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(
                      theme,
                      icon: Icons.textsms_outlined,
                      color: Colors.blue,
                      label: 'Teks',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareAsText();
                      },
                    ),
                    _buildShareOption(
                      theme,
                      icon: Icons.image_outlined,
                      color: Colors.purple,
                      label: 'Gambar',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareAsImage();
                      },
                    ),
                    _buildShareOption(
                      theme,
                      icon: Icons.chat_outlined,
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareAsText();
                      },
                    ),
                    _buildShareOption(
                      theme,
                      icon: Icons.copy,
                      color: Colors.orange,
                      label: 'Salin',
                      onTap: () {
                        Navigator.pop(ctx);
                        _copyToClipboard();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Full-width share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareAsText();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('BAGIKAN LAINNYA'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Salin teks perjalanan ke clipboard.
  void _copyToClipboard() {
    final text = _buildShareText();
    // Hapus markdown bold markers untuk clipboard
    final plainText = text.replaceAll('*', '');

    Clipboard.setData(ClipboardData(text: plainText)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Teks perjalanan berhasil disalin!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Widget _buildShareOption(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.trip.routePoints;
    final initialPosition = points.isNotEmpty
        ? points.first
        : const LatLng(-6.200000, 106.816666);

    final hasDistinctPoints = points.length >= 2 &&
        points.any((p) =>
            p.latitude != points.first.latitude ||
            p.longitude != points.first.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Perjalanan'),
        actions: [
          // Share button di AppBar
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan',
            onPressed: _showShareBottomSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 2,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialPosition,
                    initialZoom: 13.0,
                    initialCameraFit: hasDistinctPoints
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(points),
                            padding: const EdgeInsets.all(50.0),
                          )
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.trackie.app',
                    ),
                    if (points.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            color: theme.colorScheme.primary,
                            strokeWidth: 4.5,
                          ),
                        ],
                      ),
                    if (points.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: points.first,
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Titik Awal',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: points.last,
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Titik Akhir',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                                child: const Icon(
                                  Icons.flag_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.trip.destination,
                            style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                          ),
                          Text(
                            widget.trip.groupName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
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
                          const SizedBox(height: AppSpacing.xl),

                          // Jurnal & Rating Perjalanan
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Catatan Perjalanan',
                                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < 4 ? Icons.star : Icons.star_half,
                                          color: Colors.amber,
                                          size: 20,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '"Rute asik, aspal mulus, tapi sempat hujan deras di daerah pegunungan. Untung bawa jas hujan!"',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Fitur edit jurnal akan segera hadir!'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    label: const Text('Edit Jurnal'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),
                          // Tombol Bagikan
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showShareBottomSheet,
                              icon: const Icon(Icons.share),
                              label: const Text('BAGIKAN RUTE'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay saat sharing gambar
          if (_isSharing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Menyiapkan gambar...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
