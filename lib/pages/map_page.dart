// File: map_page.dart
// Menampilkan peta langsung (real-time) yang melacak posisi anggota grup
// beserta rute jalan raya, estimasi waktu tiba (ETA), dan petunjuk arah belokan
// ala Google Maps menggunakan OpenStreetMap (flutter_map + OSRM + Nominatim).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/location_provider.dart';
import '../services/haversine_utils.dart';
import '../services/routing_service.dart';
import '../services/trip_service.dart';

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
  bool get isOnline =>
      status == MemberStatus.online || status == MemberStatus.sos;
  bool get isSos => status == MemberStatus.sos;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          position == other.position &&
          distanceMeters == other.distanceMeters;

  @override
  int get hashCode => Object.hash(id, name, status, position, distanceMeters);
}

/// Fungsi pembantu untuk memformat jarak agar mudah dibaca.
/// Di bawah 1000m ditampilkan dalam meter (m), selain itu kilometer (km).
String formatDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

class _MarkerLayerData {
  final List<GroupMember> members;
  final DestinationTarget? destination;

  const _MarkerLayerData({required this.members, this.destination});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MarkerLayerData &&
          runtimeType == other.runtimeType &&
          destination == other.destination &&
          listEquals(members, other.members);

  @override
  int get hashCode => Object.hash(destination, Object.hashAll(members));
}

class _MapMarkersLayer extends StatelessWidget {
  final String? currentUid;
  final void Function(GroupMember) onFocusMember;
  final void Function(LatLng) onFocusDestination;

  const _MapMarkersLayer({
    required this.currentUid,
    required this.onFocusMember,
    required this.onFocusDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<LocationProvider, _MarkerLayerData>(
      selector: (_, lp) => _MarkerLayerData(
        members: _MapPageState._resolveMembers(lp, currentUid),
        destination: lp.destinationTarget,
      ),
      builder: (context, data, _) {
        return MarkerLayer(
          markers: _MapPageState._buildMarkers(
            data.members,
            data.destination,
            onFocusMember,
            onFocusDestination,
          ),
        );
      },
    );
  }
}

class _MapRouteLayer extends StatelessWidget {
  const _MapRouteLayer();

  @override
  Widget build(BuildContext context) {
    return Selector<LocationProvider, RouteResult?>(
      selector: (_, lp) => lp.activeRoute,
      builder: (context, activeRoute, _) {
        if (activeRoute == null || activeRoute.points.length < 2) {
          return const SizedBox.shrink();
        }
        return PolylineLayer(
          polylines: [
            // Garis tepi luar (casing) ala Google Maps
            Polyline(
              points: activeRoute.points,
              color: const Color(0xFF1E3A8A),
              strokeWidth: 8.0,
            ),
            // Garis inti rute
            Polyline(
              points: activeRoute.points,
              color: const Color(0xFF3B82F6),
              strokeWidth: 5.0,
            ),
          ],
        );
      },
    );
  }
}

class _NavOverlayData {
  final DestinationTarget? destination;
  final RouteResult? route;
  final bool isLoadingRoute;
  final LatLng? myPosition;

  const _NavOverlayData({
    this.destination,
    this.route,
    required this.isLoadingRoute,
    this.myPosition,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NavOverlayData &&
          runtimeType == other.runtimeType &&
          destination == other.destination &&
          route == other.route &&
          isLoadingRoute == other.isLoadingRoute &&
          myPosition == other.myPosition;

  @override
  int get hashCode =>
      Object.hash(destination, route, isLoadingRoute, myPosition);
}

/// [MapPage] adalah halaman utama untuk fitur pelacakan grup dan navigasi rute.
class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.isHost});

  /// Jika true, pengguna ini adalah pembuat grup (Host) dan bisa melihat kode undangan
  /// serta mengatur/mengubah titik tujuan rute secara langsung.
  final bool isHost;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Posisi kamera default saat peta pertama dimuat (contoh: Jakarta)
  static const LatLng _initialCenter = LatLng(-6.200000, 106.816666);
  static const double _initialZoom = 14.5;

  // Data fallback saat stream lokasi belum mengembalikan data
  final List<GroupMember> _fallbackMembers = [
    const GroupMember(
      id: 'anda',
      name: 'Anda',
      status: MemberStatus.online,
      position: LatLng(-6.200000, 106.816666),
      distanceMeters: 0,
    ),
    const GroupMember(
      id: 'budi',
      name: 'Budi (NMAX Hitam)',
      status: MemberStatus.online,
      position: LatLng(-6.201000, 106.817666),
      distanceMeters: 120,
    ),
    const GroupMember(
      id: 'citra',
      name: 'Citra (Vario)',
      status: MemberStatus.offline,
      position: LatLng(-6.210000, 106.820666),
      distanceMeters: 1500,
    ),
  ];

  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  LocationProvider? _locationProviderRef;
  bool _hasCenteredOnRealLocation = false;
  bool _hasFittedInitialRoute = false;
  bool _isPickingDestinationOnMap = false;
  bool _isSettingPin = false;
  bool _canPopNow = false;
  StreamSubscription<String>? _groupEndedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _locationProviderRef = context.read<LocationProvider>();
      _locationProviderRef?.addListener(_handleCameraInitialSetup);
      _initRealTimeTracking();
    });
  }

  void _handleCameraInitialSetup() {
    if (!mounted || _locationProviderRef == null) return;
    if (!_hasCenteredOnRealLocation) {
      final myPos = _locationProviderRef!.myLatLng;
      if (myPos != null) {
        _hasCenteredOnRealLocation = true;
        _mapController.move(myPos, _initialZoom);
      }
    }
    if (!_hasFittedInitialRoute) {
      final route = _locationProviderRef!.activeRoute;
      if (route != null && route.points.length >= 2) {
        _hasFittedInitialRoute = true;
        _fitRouteBounds(route);
      }
    }
    if (_hasCenteredOnRealLocation && _hasFittedInitialRoute) {
      _locationProviderRef?.removeListener(_handleCameraInitialSetup);
    }
  }

  @override
  void dispose() {
    _locationProviderRef?.removeListener(_handleCameraInitialSetup);
    _groupEndedSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initRealTimeTracking() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final locationProvider = context.read<LocationProvider>();

    final activeGroup = groupProvider.activeGroup;
    final currentUser = authProvider.user;
    if (activeGroup == null || currentUser == null) return;

    final displayName =
        authProvider.userProfile?.name ?? currentUser.displayName ?? 'Anda';

    // Selalu pasang listener group_ended agar anggota otomatis keluar jika host menyelesaikan grup,
    // bahkan jika izin GPS belum diberikan secara penuh.
    _groupEndedSubscription?.cancel();
    _groupEndedSubscription = locationProvider.onGroupEnded.listen((endedGroupId) async {
      if (!mounted) return;
      final currentGroup = context.read<GroupProvider>().activeGroup;
      if (currentGroup?.id == endedGroupId || currentGroup == null) {
        await _handleGroupEndedByHost();
      }
    });

    final granted = await locationProvider.requestPermissions();
    if (!mounted) return;

    if (!granted) {
      // Jika izin lokasi ditolak permanen, tampilkan dialog edukasi bantuan
      final isPermanentlyDenied = await Permission.location.isPermanentlyDenied;
      if (isPermanentlyDenied && mounted) {
        await PermissionService.showPermissionDeniedDialog(context);
      }
      if (!mounted) return;
    }

    await locationProvider.startTracking(
      groupId: activeGroup.id,
      uid: currentUser.uid,
      userName: displayName,
      tripName: activeGroup.name,
      initialDestination: activeGroup.destination,
      vehicleType: activeGroup.type,
    );
  }

  static List<GroupMember> _resolveMembers(
    LocationProvider locationProvider,
    String? currentUid,
  ) {
    final liveMembers = locationProvider.members;

    double? myLat = locationProvider.currentPosition?.latitude;
    double? myLng = locationProvider.currentPosition?.longitude;

    if (currentUid != null) {
      for (final m in liveMembers) {
        if (m.uid == currentUid) {
          myLat = m.lat;
          myLng = m.lng;
          break;
        }
      }
    }

    if (liveMembers.isEmpty) {
      if (myLat != null && myLng != null) {
        return [
          GroupMember(
            id: currentUid ?? 'anda',
            name: 'Anda',
            status: MemberStatus.online,
            position: LatLng(myLat, myLng),
            distanceMeters: 0,
          ),
        ];
      }
      return const [];
    }

    return liveMembers.map((loc) {
      final MemberStatus status;
      if (loc.isSos) {
        status = MemberStatus.sos;
      } else if (loc.isOffline) {
        status = MemberStatus.offline;
      } else {
        status = MemberStatus.online;
      }

      final double distance =
          (myLat != null && myLng != null && loc.uid != currentUid)
              ? HaversineUtils.distanceInMeters(myLat, myLng, loc.lat, loc.lng)
              : 0.0;

      return GroupMember(
        id: loc.uid,
        name: loc.uid == currentUid ? '${loc.name} (Anda)' : loc.name,
        status: status,
        position: LatLng(loc.lat, loc.lng),
        distanceMeters: distance,
      );
    }).toList();
  }

  /// Mengubah list [members] dan titik tujuan menjadi kumpulan [Marker].
  static List<Marker> _buildMarkers(
    List<GroupMember> members,
    DestinationTarget? destinationTarget,
    void Function(GroupMember) onFocusMember,
    void Function(LatLng) onFocusDestination,
  ) {
    return [
      if (destinationTarget != null)
        Marker(
          key: const ValueKey('destination_pin'),
          point: destinationTarget.point,
          width: 150,
          height: 76,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => onFocusDestination(destinationTarget.point),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '🏁 ${destinationTarget.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      for (final m in members)
        Marker(
          key: ValueKey(m.id),
          point: m.position,
          width: 120,
          height: 72,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: m.isOnline ? 1.0 : 0.55,
            child: GestureDetector(
              onTap: () => onFocusMember(m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: m.isSos
                          ? Colors.red.shade700
                          : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.isSos ? '🚨 ${m.name}' : m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: m.isSos
                          ? Colors.red
                          : (m.isOnline ? Colors.green : Colors.orange),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      m.isSos ? Icons.warning_amber_rounded : Icons.navigation,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  /// Mengarahkan kamera peta untuk fokus ke posisi anggota tertentu.
  void _focusOn(GroupMember m) {
    _mapController.move(m.position, 16.0);
  }

  /// Menyesuaikan kamera agar seluruh jalur rute terlihat di layar secara aman.
  void _fitRouteBounds(RouteResult? route) {
    if (!mounted || route == null || route.points.isEmpty) return;
    try {
      if (route.points.length == 1) {
        _mapController.move(route.points.first, 15.0);
        return;
      }
      final first = route.points.first;
      final hasDistinctPoint = route.points.any(
        (p) =>
            (p.latitude - first.latitude).abs() > 0.0001 ||
            (p.longitude - first.longitude).abs() > 0.0001,
      );
      if (!hasDistinctPoint) {
        _mapController.move(first, 15.0);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(route.points),
          padding: const EdgeInsets.fromLTRB(48, 160, 48, 240),
        ),
      );
    } catch (e) {
      debugPrint('Error fitting route bounds: $e');
    }
  }

  /// Menerapkan tujuan baru yang dipilih Host, memperbarui rute, dan menggerakkan kamera peta.
  Future<void> _applyNewDestination(DestinationTarget target) async {
    if (!mounted) return;
    final groupProvider = context.read<GroupProvider>();
    final locationProvider = context.read<LocationProvider>();
    final groupId = groupProvider.activeGroup?.id;

    groupProvider.updateActiveGroupDestination(
      RoutingService.encodeDestination(target.name, target.point),
    );

    await locationProvider.updateGroupDestination(
      groupId: groupId,
      target: target,
    );

    if (!mounted) return;
    final route = locationProvider.activeRoute;
    if (route != null && route.points.length >= 2) {
      _fitRouteBounds(route);
    } else {
      _mapController.move(target.point, 15.0);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Tujuan diperbarui: ${target.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Menangani pemilihan titik tujuan langsung dari tap/long-press di peta (khusus Host).
  Future<void> _handleMapPinSelected(LatLng point) async {
    if (!widget.isHost || _isSettingPin) return;

    setState(() {
      _isSettingPin = true;
      _isPickingDestinationOnMap = false;
    });

    try {
      final placeName = await _routingService.reverseGeocode(point);
      if (!mounted) return;
      final target = DestinationTarget(name: placeName, point: point);
      await _applyNewDestination(target);
    } finally {
      if (mounted) {
        setState(() => _isSettingPin = false);
      }
    }
  }

  /// Menampilkan modal pencarian lokasi tujuan & tombol pilih di peta (khusus Host).
  Future<void> _showChangeDestinationSheet() async {
    if (!widget.isHost) return;

    final result = await showModalBottomSheet<_DestinationSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DestinationSearchSheet(routingService: _routingService),
    );

    if (!mounted || result == null) return;

    if (result.pickOnMap) {
      setState(() => _isPickingDestinationOnMap = true);
    } else if (result.target != null) {
      await _applyNewDestination(result.target!);
    }
  }

  IconData _maneuverIcon(RouteStepInfo? step) {
    if (step == null) return Icons.navigation_rounded;
    switch (step.maneuverType) {
      case 'arrive':
        return Icons.flag_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_left_rounded;
      case 'fork':
        return Icons.fork_right_rounded;
      case 'merge':
        return Icons.merge_rounded;
      default:
        break;
    }
    switch (step.maneuverModifier) {
      case 'uturn':
        return Icons.u_turn_left_rounded;
      case 'sharp left':
      case 'left':
        return Icons.turn_left_rounded;
      case 'slight left':
        return Icons.turn_slight_left_rounded;
      case 'sharp right':
      case 'right':
        return Icons.turn_right_rounded;
      case 'slight right':
        return Icons.turn_slight_right_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  /// Banner navigasi ala Google Maps di bagian atas peta.
  Widget _buildNavigationBanner({
    required DestinationTarget? destination,
    required RouteResult? route,
    required bool isLoadingRoute,
    required LatLng? myPosition,
  }) {
    if (_isPickingDestinationOnMap) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_rounded, color: AppTheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ketuk titik mana saja di peta untuk menetapkan tujuan baru',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _isPickingDestinationOnMap = false),
              child: const Text(
                'BATAL',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (destination == null && !widget.isHost) {
      return const SizedBox.shrink();
    }

    final nextStep = (route != null && myPosition != null)
        ? route.nextStepFor(myPosition)
        : (route != null && route.steps.isNotEmpty ? route.steps.first : null);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5132), // Warna hijau navigasi Google Maps
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Atas: Petunjuk Arah Belokan (Turn-by-Turn)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLoadingRoute || _isSettingPin
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          _maneuverIcon(nextStep),
                          color: Colors.white,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nextStep != null)
                        Text(
                          formatDistance(nextStep.distanceMeters),
                          style: const TextStyle(
                            color: Color(0xFFA3E635),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        destination == null
                            ? 'Belum ada titik tujuan rute'
                            : (nextStep?.instruction ??
                                'Menghitung jalur terbaik ke ${destination.name}...'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (route != null && route.points.length >= 2)
                  IconButton(
                    tooltip: 'Lihat seluruh rute',
                    onPressed: () => _fitRouteBounds(route),
                    icon: const Icon(
                      Icons.route_rounded,
                      color: Colors.white,
                    ),
                  ),
                if (widget.isHost)
                  IconButton(
                    tooltip: 'Ubah lokasi tujuan',
                    onPressed: _showChangeDestinationSheet,
                    icon: const Icon(
                      Icons.edit_location_alt_rounded,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          // Baris Bawah: Info Tujuan, Estimasi Waktu (ETA) & Sisa Jarak
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFF0A3622),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFA3E635),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destination?.name ?? 'Ketuk ikon pensil untuk pilih tujuan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (route != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${route.formattedDuration} • ${route.formattedDistance} • Tiba ${route.formattedEtaClock}',
                    style: const TextStyle(
                      color: Color(0xFFA3E635),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
                fontSize: 32,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
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
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Ayo gabung perjalanan saya di Trackie! Gunakan kode: $code',
                ),
              );
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

  /// Memunculkan konfirmasi ketika pengguna menyelesaikan atau keluar dari perjalanan,
  /// lalu menyimpan riwayat perjalanan ke Supabase (`public.trip_history`).
  Future<void> _confirmLeave() async {
    final isHost = widget.isHost;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHost ? 'Selesaikan Perjalanan?' : 'Keluar dari Grup?'),
        content: Text(
          isHost
              ? 'Perjalanan grup akan diakhiri dan otomatis disimpan ke halaman Riwayat Perjalanan Anda.'
              : 'Lokasimu tidak akan dibagikan lagi dan perjalanan ini akan disimpan ke Riwayat Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isHost ? AppTheme.primary : Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isHost ? 'SELESAI & SIMPAN' : 'KELUAR & SIMPAN'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final groupProvider = context.read<GroupProvider>();
      final locationProvider = context.read<LocationProvider>();

      final activeGroup = groupProvider.activeGroup;
      final groupId = activeGroup?.id;
      final uid = authProvider.user?.uid;

      // 1. Susun & simpan riwayat perjalanan ke Supabase sebelum menghentikan state tracking
      if (uid != null && activeGroup != null) {
        try {
          final completedTrip = locationProvider.buildCompletedTripHistory(
            groupName: activeGroup.name,
            rawDestination: activeGroup.destination,
            groupType: activeGroup.type,
            isHost: isHost,
            fallbackMemberCount: activeGroup.memberCount,
            groupCreatedAt: activeGroup.createdAt,
          );
          await TripService().saveTrip(uid: uid, trip: completedTrip);
        } catch (e) {
          debugPrint('Error saving trip history on finish: $e');
        }
      }

      // 2. Siarkan event group_ended jika Host, agar semua anggota langsung terinfo
      if (isHost && groupId != null) {
        try {
          await locationProvider.broadcastGroupEnded(groupId);
        } catch (e) {
          debugPrint('Error broadcasting group_ended: $e');
        }
      }

      // 3. Hentikan tracking lokasi
      await locationProvider.stopTracking(groupId: groupId, uid: uid);

      // 4. Akhiri grup (jika Host) atau keluar grup (jika Member)
      if (uid != null && groupId != null) {
        if (isHost) {
          await groupProvider.endGroup();
        } else {
          await groupProvider.leaveGroup(uid: uid);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perjalanan selesai dan tersimpan di Riwayat!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _canPopNow = true);
        Navigator.pop(context);
      }
    }
  }

  /// Ditangani ketika Host menyelesaikan perjalanan dan menyiarkan event group_ended.
  /// Anggota rombongan otomatis menyimpan riwayat, menghentikan tracking, dan keluar ke Home.
  Future<void> _handleGroupEndedByHost() async {
    final authProvider = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final locationProvider = context.read<LocationProvider>();

    final activeGroup = groupProvider.activeGroup;
    final uid = authProvider.user?.uid;

    if (uid != null && activeGroup != null) {
      try {
        final completedTrip = locationProvider.buildCompletedTripHistory(
          groupName: activeGroup.name,
          rawDestination: activeGroup.destination,
          groupType: activeGroup.type,
          isHost: false,
          fallbackMemberCount: activeGroup.memberCount,
          groupCreatedAt: activeGroup.createdAt,
        );
        await TripService().saveTrip(uid: uid, trip: completedTrip);
      } catch (e) {
        debugPrint('Error saving member trip history on remote group end: $e');
      }
    }

    await locationProvider.stopTracking(groupId: activeGroup?.id, uid: uid);
    groupProvider.clearActiveGroup();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perjalanan telah diakhiri oleh Host. Riwayat Anda telah disimpan.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() => _canPopNow = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _triggerSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 Tekan Tombol Darurat?'),
        content: const Text(
          'Gunakan hanya jika Anda mengalami kecelakaan, mogok, atau butuh bantuan mendesak. '
          'Seluruh anggota grup akan menerima alarm peringatan.',
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
      final authProvider = context.read<AuthProvider>();
      final groupProvider = context.read<GroupProvider>();
      final locationProvider = context.read<LocationProvider>();

      final groupId = groupProvider.activeGroup?.id;
      final uid = authProvider.user?.uid;

      if (groupId != null && uid != null) {
        await locationProvider.triggerSOS(groupId: groupId, uid: uid);
      }

      setState(() {
        final index = _fallbackMembers.indexWhere((m) => m.id == 'anda');
        if (index != -1) {
          final me = _fallbackMembers[index];
          _fallbackMembers[index] = GroupMember(
            id: me.id,
            name: me.name,
            status: MemberStatus.sos,
            position: me.position,
            distanceMeters: me.distanceMeters,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Sinyal DARURAT telah dikirim ke rombongan!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final currentUid = context.select<AuthProvider, String?>((a) => a.user?.uid);

    return PopScope(
      canPop: _canPopNow,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmLeave,
          ),
          title: const Text('Peta & Navigasi Rute'),
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
                // Lapisan Peta OpenStreetMap + Rute Jalan Raya
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    onTap: (_, latlng) {
                      if (_isPickingDestinationOnMap && widget.isHost) {
                        _handleMapPinSelected(latlng);
                      }
                    },
                    onLongPress: (_, latlng) {
                      if (widget.isHost) {
                        _handleMapPinSelected(latlng);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.trackie',
                    ),
                    const _MapRouteLayer(),
                    _MapMarkersLayer(
                      currentUid: currentUid,
                      onFocusMember: _focusOn,
                      onFocusDestination: (point) =>
                          _mapController.move(point, 16.0),
                    ),
                  ],
                ),
                // Banner Navigasi Rute + Tombol SOS Ikon di bawahnya (otomatis menyesuaikan tinggi banner agar tidak bertabrakan)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Selector<LocationProvider, _NavOverlayData>(
                        selector: (_, lp) => _NavOverlayData(
                          destination: lp.destinationTarget,
                          route: lp.activeRoute,
                          isLoadingRoute: lp.isLoadingRoute,
                          myPosition: lp.myLatLng,
                        ),
                        builder: (context, navData, _) {
                          return _buildNavigationBanner(
                            destination: navData.destination,
                            route: navData.route,
                            isLoadingRoute: navData.isLoadingRoute,
                            myPosition: navData.myPosition,
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 12,
                          right: AppSpacing.md,
                        ),
                        child: FloatingActionButton(
                          heroTag: 'btn_sos',
                          tooltip: 'Sinyal Darurat (SOS)',
                          onPressed: _triggerSOS,
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: Colors.white,
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lapisan Panel Bawah yang dapat digeser (Draggable)
                DraggableScrollableSheet(
                  initialChildSize: 0.28,
                  minChildSize: 0.15,
                  maxChildSize: 0.6,
                  snap: true,
                  builder: (_, scrollController) => Material(
                    color: theme.colorScheme.surface,
                    elevation: 8,
                    clipBehavior: Clip.antiAlias,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Selector<LocationProvider, List<GroupMember>>(
                      selector: (_, lp) => _resolveMembers(lp, currentUid),
                      builder: (context, members, _) {
                        return CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            // Header panel
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
                                            'Anggota Grup (${members.length})',
                                            style:
                                                theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _confirmLeave,
                                          style: TextButton.styleFrom(
                                            foregroundColor: widget.isHost
                                                ? AppTheme.primary
                                                : theme.colorScheme.error,
                                          ),
                                          icon: Icon(
                                            widget.isHost
                                                ? Icons.flag_circle_rounded
                                                : Icons.exit_to_app,
                                          ),
                                          label: Text(
                                            widget.isHost
                                                ? 'Selesai'
                                                : 'Keluar',
                                          ),
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
                              itemCount: members.length,
                              itemBuilder: (_, i) {
                                final m = members[i];
                                return ListTile(
                                  onTap: () => _focusOn(m),
                                  tileColor: m.isSos
                                      ? theme.colorScheme.error.withValues(alpha: 0.1)
                                      : null,
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            m.isSos ? theme.colorScheme.error : null,
                                        foregroundColor:
                                            m.isSos ? Colors.white : null,
                                        child: Icon(
                                          m.isSos ? Icons.warning : Icons.person,
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: m.isSos
                                                ? theme.colorScheme.error
                                                : (m.isOnline
                                                    ? Colors.green
                                                    : Colors.grey),
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
                                      fontWeight: m.isSos
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: m.isSos ? theme.colorScheme.error : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    m.isSos
                                        ? '🚨 BUTUH BANTUAN!'
                                        : (m.isOnline
                                            ? 'Terhubung'
                                            : 'Terputus sinyal'),
                                    style: TextStyle(
                                      color: m.isSos ? theme.colorScheme.error : null,
                                      fontWeight: m.isSos
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Jarak', style: theme.textTheme.labelSmall),
                                      Text(
                                        formatDistance(m.distanceMeters),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DestinationSheetResult {
  final DestinationTarget? target;
  final bool pickOnMap;

  const _DestinationSheetResult.target(this.target) : pickOnMap = false;
  const _DestinationSheetResult.pickOnMap()
      : target = null,
        pickOnMap = true;
}

/// Bottom sheet StatefulWidget terpisah untuk mencari/mengubah lokasi tujuan.
/// Mengelola lifecycle [TextEditingController] dan [Timer] secara aman.
class _DestinationSearchSheet extends StatefulWidget {
  final RoutingService routingService;

  const _DestinationSearchSheet({required this.routingService});

  @override
  State<_DestinationSearchSheet> createState() =>
      _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<_DestinationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (_searchError != null) {
      setState(() => _searchError = null);
    }
    if (val.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await widget.routingService.searchPlaces(val);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _submitDirectSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _debounce?.cancel();
    if (_suggestions.isNotEmpty) {
      final first = _suggestions.first;
      Navigator.pop(
        context,
        _DestinationSheetResult.target(
          DestinationTarget(name: first.title, point: first.point),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final results = await widget.routingService.searchPlaces(query);
    if (!mounted) return;

    if (results.isNotEmpty) {
      final first = results.first;
      Navigator.pop(
        context,
        _DestinationSheetResult.target(
          DestinationTarget(name: first.title, point: first.point),
        ),
      );
    } else {
      setState(() {
        _isSearching = false;
        _searchError =
            'Lokasi "$query" tidak ditemukan. Coba nama kota/tempat lain atau pilih langsung di peta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomInset + 16,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Atur Tujuan Rute (Host)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _submitDirectSearch(),
                decoration: InputDecoration(
                  hintText: 'Ketik nama tempat atau alamat tujuan...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.primary,
                  ),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Cari & Tetapkan',
                          onPressed: _submitDirectSearch,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_searchError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _searchError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          const _DestinationSheetResult.pickOnMap(),
                        );
                      },
                      icon: const Icon(Icons.touch_app_rounded, size: 18),
                      label: const Text('Tap di Peta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _submitDirectSearch,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Tetapkan Tujuan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFFFEFE5),
                          child: Icon(
                            Icons.place_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(
                            context,
                            _DestinationSheetResult.target(
                              DestinationTarget(
                                name: item.title,
                                point: item.point,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
