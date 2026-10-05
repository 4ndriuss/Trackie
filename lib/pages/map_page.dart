// File: map_page.dart
// Menampilkan peta langsung (real-time) yang melacak posisi anggota grup.
// Halaman ini menggunakan Google Maps untuk menampilkan marker pengguna
// serta panel di bagian bawah untuk melihat status masing-masing anggota.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../providers/group_provider.dart';

/// Status anggota grup, menentukan warna indikator dan opasitas marker.
enum MemberStatus { online, offline, sos }

/// [GroupMember] menyimpan data untuk setiap anggota yang tergabung dalam perjalanan.
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
  final LatLng position; // Titik koordinat di peta
  final double distanceMeters; // Jarak anggota dengan pengguna saat ini

  // Mengecek status anggota
  bool get isOnline => status == MemberStatus.online || status == MemberStatus.sos;
  bool get isSos => status == MemberStatus.sos;
}

/// Fungsi pembantu untuk memformat jarak agar mudah dibaca.
/// Di bawah 1000m ditampilkan dalam meter (m), selain itu kilometer (km).
String formatDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// [MapPage] adalah halaman utama untuk fitur pelacakan grup.
class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.isHost});
  
  /// Jika true, pengguna ini adalah pembuat grup dan bisa melihat kode undangan.
  final bool isHost;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Posisi kamera default saat peta pertama dimuat (contoh: Jakarta)
  static const _initialPosition = CameraPosition(
    target: LatLng(-6.200000, 106.816666),
    zoom: 14.4746,
  );

  // Data mockup anggota grup
  // TODO: ganti dengan data dari backend / stream lokasi
  final List<GroupMember> _members = [
    const GroupMember(
      id: 'anda', name: 'Anda', status: MemberStatus.online,
      position: LatLng(-6.200000, 106.816666), distanceMeters: 0,
    ),
    const GroupMember(
      id: 'budi', name: 'Budi (NMAX Hitam)', status: MemberStatus.online,
      position: LatLng(-6.201000, 106.817666), distanceMeters: 120,
    ),
    const GroupMember(
      id: 'citra', name: 'Citra (Vario)', status: MemberStatus.offline,
      position: LatLng(-6.210000, 106.820666), distanceMeters: 1500,
    ),
  ];

  // Controller untuk memanipulasi Google Maps (misal: menggeser kamera)
  final _mapController = Completer<GoogleMapController>();

  /// Mengubah list [_members] menjadi kumpulan [Marker] untuk ditampilkan di peta.
  Set<Marker> get _markers => {
        for (final m in _members)
          Marker(
            markerId: MarkerId(m.id),
            position: m.position,
            alpha: m.isOnline ? 1 : 0.5, // Redupkan jika sedang offline
            icon: BitmapDescriptor.defaultMarkerWithHue(
              m.isSos 
                  ? BitmapDescriptor.hueRed 
                  : (m.isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
            ),
            infoWindow: InfoWindow(
              title: m.isSos ? '🚨 ${m.name} - SOS!' : (m.isOnline ? m.name : '${m.name} - Terputus'),
            ),
          ),
      };

  /// Mengarahkan kamera peta untuk fokus ke posisi anggota tertentu.
  Future<void> _focusOn(GroupMember m) async {
    final c = await _mapController.future;
    await c.animateCamera(CameraUpdate.newLatLngZoom(m.position, 16));
  }

  /// Menampilkan dialog berisi kode undangan untuk dibagikan ke teman.
  void _showInviteCode() {
    final groupProvider = context.read<GroupProvider>();
    final code = groupProvider.activeGroup?.inviteCode ?? 'TIDAK-ADA-KODE';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undang Teman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bagikan kode ini untuk bergabung:'),
            const SizedBox(height: 8),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32, letterSpacing: 2.0, fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode disalin')),
              );
            },
            child: const Text('SALIN KODE'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(ShareParams(text: 'Ayo gabung perjalanan saya di Trackie! Gunakan kode: $code'));
            },
            child: const Text('BAGIKAN'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  /// Memunculkan konfirmasi ketika pengguna ingin keluar dari sesi pelacakan.
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

  Future<void> _triggerSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 Tekan Tombol Darurat?'),
        content: const Text(
          'Gunakan hanya jika Anda mengalami kecelakaan, mogok, atau butuh bantuan mendesak. '
          'Seluruh anggota grup akan menerima alarm peringatan.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('KIRIM SOS'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        // Simulasi: Mengubah status 'Anda' menjadi SOS
        final index = _members.indexWhere((m) => m.id == 'anda');
        if (index != -1) {
          final me = _members[index];
          _members[index] = GroupMember(
            id: me.id,
            name: me.name,
            status: MemberStatus.sos,
            position: me.position,
            distanceMeters: me.distanceMeters,
          );
        }
      });
      // TODO: Panggil API Backend untuk membunyikan sirine di semua HP
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Sinyal DARURAT telah dikirim ke rombongan!'),
          backgroundColor: Colors.red,
        ),
      );
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
          // Tombol share hanya ditampilkan jika pengguna adalah host (pembuat grup)
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
              // Lapisan Peta
              GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: _markers,
                // Memberikan padding bawah agar logo Google tidak tertutup oleh panel bottom sheet
                padding: EdgeInsets.only(bottom: constraints.maxHeight * 0.3),
                onMapCreated: (c) {
                  if (!_mapController.isCompleted) _mapController.complete(c);
                },
              ),
              // Tombol SOS Mengambang
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: FloatingActionButton.extended(
                  heroTag: 'btn_sos',
                  onPressed: _triggerSOS,
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.warning_amber_rounded, size: 28),
                  label: const Text(
                    'SOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Lapisan Panel Bawah yang dapat digeser (Draggable)
              DraggableScrollableSheet(
                initialChildSize: 0.3,
                minChildSize: 0.15,
                maxChildSize: 0.6,
                snap: true,
                builder: (_, scrollController) => Material(
                  color: theme.colorScheme.surface,
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      // Header panel
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // Indikator garis (handle) untuk digeser
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
                      // Daftar anggota grup
                      SliverList.builder(
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final m = _members[i];
                          return ListTile(
                            onTap: () => _focusOn(m), // Geser kamera saat anggota ditekan
                            tileColor: m.isSos ? theme.colorScheme.error.withValues(alpha: 0.1) : null, // ignore: deprecated_member_use
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: m.isSos ? theme.colorScheme.error : null,
                                  foregroundColor: m.isSos ? Colors.white : null,
                                  child: Icon(m.isSos ? Icons.warning : Icons.person),
                                ),
                                // Indikator titik status online/offline
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: m.isSos 
                                          ? theme.colorScheme.error 
                                          : (m.isOnline ? Colors.green : Colors.grey),
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
                            title: Text(
                              m.name,
                              style: TextStyle(
                                fontWeight: m.isSos ? FontWeight.bold : FontWeight.normal,
                                color: m.isSos ? theme.colorScheme.error : null,
                              ),
                            ),
                            subtitle: Text(
                              m.isSos ? '🚨 BUTUH BANTUAN!' : (m.isOnline ? 'Terhubung' : 'Terputus sinyal'),
                              style: TextStyle(
                                color: m.isSos ? theme.colorScheme.error : null,
                                fontWeight: m.isSos ? FontWeight.bold : FontWeight.normal,
                              ),
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
                      // Memberikan ruang kosong tambahan di bawah daftar agar tidak tertutup sistem navigasi
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
