import 'package:latlong2/latlong.dart';

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
