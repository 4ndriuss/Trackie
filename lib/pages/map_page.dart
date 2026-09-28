import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

enum MemberStatus { online, offline }

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.status,
    required this.position,
    required this.distanceMeters,
  });

  final String id;
  final String name;
  final MemberStatus status;
  final LatLng position;
  final double distanceMeters;

  bool get isOnline => status == MemberStatus.online;
}

String formatDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.isHost});
  final bool isHost;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _initialPosition = CameraPosition(
    target: LatLng(-6.200000, 106.816666),
    zoom: 14.4746,
  );

  // TODO: ganti dengan data dari backend / stream lokasi
  static const _members = <GroupMember>[
    GroupMember(
      id: 'anda', name: 'Anda', status: MemberStatus.online,
      position: LatLng(-6.200000, 106.816666), distanceMeters: 0,
    ),
    GroupMember(
      id: 'budi', name: 'Budi (NMAX Hitam)', status: MemberStatus.online,
      position: LatLng(-6.201000, 106.817666), distanceMeters: 120,
    ),
    GroupMember(
      id: 'citra', name: 'Citra (Vario)', status: MemberStatus.offline,
      position: LatLng(-6.210000, 106.820666), distanceMeters: 1500,
    ),
  ];

  final _mapController = Completer<GoogleMapController>();

  Set<Marker> get _markers => {
        for (final m in _members)
          Marker(
            markerId: MarkerId(m.id),
            position: m.position,
            alpha: m.isOnline ? 1 : 0.5,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              m.isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: m.isOnline ? m.name : '${m.name} - Terputus',
            ),
          ),
      };

  Future<void> _focusOn(GroupMember m) async {
    final c = await _mapController.future;
    await c.animateCamera(CameraUpdate.newLatLngZoom(m.position, 16));
  }

  void _showInviteCode() {
    const code = 'TRG-42A'; // TODO: ambil dari backend
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kode Undangan'),
        content: SelectableText(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32, letterSpacing: 2.0, fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode disalin')),
              );
            },
            child: const Text('SALIN'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari grup?'),
        content: const Text('Lokasimu tidak akan dibagikan lagi ke anggota grup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      // TODO: panggil API keluar grup dan hentikan tracking
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Real-time'),
        actions: [
          if (widget.isHost)
            IconButton(
              tooltip: 'Bagikan kode undangan',
              icon: const Icon(Icons.share),
              onPressed: _showInviteCode,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: _markers,
                padding: EdgeInsets.only(bottom: constraints.maxHeight * 0.3), // Avoid Google Logo being covered
                onMapCreated: (c) {
                  if (!_mapController.isCompleted) _mapController.complete(c);
                },
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.3,
                minChildSize: 0.15,
                maxChildSize: 0.6,
                snap: true,
                builder: (_, scrollController) => Material(
                  // Use surface since surfaceContainerLowest might not be in older flutter
                  color: theme.colorScheme.surface,
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.dividerColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Anggota Grup (${_members.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _confirmLeave,
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                    icon: const Icon(Icons.exit_to_app),
                                    label: const Text('Keluar'),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                      SliverList.builder(
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final m = _members[i];
                          return ListTile(
                            onTap: () => _focusOn(m),
                            leading: Stack(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: m.isOnline ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              m.isOnline ? 'Terhubung' : 'Terputus sinyal',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Jarak', style: theme.textTheme.labelSmall),
                                Text(
                                  formatDistance(m.distanceMeters),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}
