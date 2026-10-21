# LAPORAN AUDIT MENYELURUH (AUDIT REVIEW REPORT) — PROJECT TRACKIE

**Nama Proyek:** Trackie (Aplikasi Pelacakan Lokasi Grup & Touring)  
**Platform:** Flutter (Android, iOS, Web)  
**Tanggal Audit:** 20 Oktober 2026 (Diperbarui Pasca-Fase 1)  
**Branch:** `fix/audit-fase-1`  
**Auditor:** Multi-Agent Specialist Panel (Orchestrated by Lead Reviewer)  
**Mode Audit:** READ-ONLY (Dokumentasi Murni, Tanpa Modifikasi Kode)  

---

## 1. RINGKASAN EKSEKUTIF

Aplikasi **Trackie** menunjukkan peningkatan kesehatan dan kematangan teknis yang substansial setelah penerapan perbaikan **Fase 1 (Release Blockers)**:
- `flutter test` kini **100% HIJAU (8/8 pengujian lulus)**.
- `flutter analyze` menghasilkan **0 issues (bersih tanpa warning/error)**.
- Kolom sensitif langganan (`plan`, `subscription_status`) di PostgreSQL telah **terkunci penuh ke `service_role`**, menutup celah privilege escalation.
- Deskripsi izin privasi iOS (`NSPhotoLibraryUsageDescription` & `NSCameraUsageDescription`) telah terpasang, mengamankan aplikasi dari penolakan App Store.
- Halaman peta telah dipagari oleh `PopScope` dan mekanisme broadcast event `group_ended` oleh Host telah memulihkan desinkronisasi status grup.

Meskipun demikian, audit mendalam multi-agent terhadap sisa codebase mengidentifikasi area prioritas berikutnya (Fase 2 & Fase 3):
1. **Performa & Konsumsi Baterai**: Duplikasi pelacakan GPS (main isolate stream + background timer 5s) masih aktif serentak saat foreground, peta `FlutterMap` merebuild seluruh pohon widget setiap 5 meter, dan kueri PostgreSQL tabel `groups` berjalan tanpa indeks GIN pada kolom array `member_uids`.
2. **Kualitas Data & Privasi**: Fitur *Ghost Mode* masih berstatus placebo lokal (koordinat tetap terpancar ke Realtime WebSocket), format tanggal lahir `birth_date` model Dart tidak cocok dengan PostgreSQL `DATE`, dan penghapusan akun berpotensi meninggalkan *zombie groups* tak bertuan.
3. **Arsitektur & Integritas Rilis**: Keberadaan 4 *God Classes* (>1.000 baris), puluhan warna hardcode yang merusak kontras Dark Mode, nama paket masih default `com.example.trackie`, serta ketiadaan `CFBundleURLTypes` untuk redirect Google Sign-In di iOS.

### Skor Kesehatan Proyek (Skala 1 - 10)

| Kategori | Skor Sebelum Fase 1 | Skor Saat Ini (Pasca-Fase 1) | Catatan Evaluasi Pasca-Fase 1 |
|:---|:---:|:---:|:---|
| **Bug & Correctness** | 6.5 / 10 | **7.5 / 10** | Test suite hijau 100%, linter bersih, Facebook crash sembuh; sisa issue format DATE & race routing. |
| **Performa & Efisiensi** | 6.0 / 10 | **6.0 / 10** | Konsep Zero DB Write sangat baik, namun GPS ganda & rebuild total peta memerlukan optimasi Fase 2. |
| **Security (Sisi Aplikasi)** | 7.0 / 10 | **8.0 / 10** | RLS subscription locked to server, HTTPS murni, zero secret leak; sisa issue SharedPreferences token & allowBackup. |
| **Backend, Data & Privasi** | 6.5 / 10 | **7.0 / 10** | Privilege escalation tuntas, topic broadcast private; sisa issue zombie groups & Ghost Mode placebo. |
| **Dependency & Supply Chain** | 6.5 / 10 | **7.0 / 10** | Izin iOS lengkap; sisa issue bundle bloat Facebook Auth, package com.example, & missing Podfile. |
| **Arsitektur & Kualitas Kode** | 5.5 / 10 | **6.0 / 10** | Lifecycle map deterministik; sisa issue God Classes >1.400 baris, broken Dark Mode, & delimited string hack. |
| **RATA-RATA KESELURUHAN** | **6.3 / 10** | **6.9 / 10** | **Stabil, Siap Memasuki Sprint Optimasi Fase 2 (Performa & Stabilitas)** |

---

## 2. TABEL RINGKASAN JUMLAH TEMUAN

### Berdasarkan Tingkat Keparahan (Severity)
| Severity | Jumlah | Deskripsi Dampak |
|:---|:---:|:---|
| **Critical** | **4** | Desinkronisasi kuota grup klien, pemutusan listener penutupan grup, duplikasi polling GPS boros baterai, Full Table Scan PostgreSQL tanpa GIN index. |
| **High** | **16** | Rebuild peta berlebih, kebocoran privasi Ghost Mode, zombie groups, Google OAuth iOS redirect, God classes, broken Dark Mode. |
| **Medium** | **25** | Inisialisasi stream di build(), memory leak controller delayed, dependency outdated mayor, unencrypted SharedPreferences. |
| **Low** | **15** | Dead dependencies (`uuid`, `cupertino_icons`), avatar uncompressed, delimited string hack, weak password validator. |
| **Info** | **4** | IndexedStack tab navigation, asset WebP conversion, Supabase anon key fallback. |
| **TOTAL** | **64** | *(Hasil konsolidasi independen seluruh temuan)* |

### Berdasarkan Kategori
| Kategori | Critical | High | Medium | Low | Info | Total |
|:---|:---:|:---:|:---|:---:|:---:|:---|
| **Bug & Correctness** | 2 | 2 | 6 | 2 | 1 | **13** |
| **Performance & Efisiensi** | 2 | 4 | 4 | 2 | 1 | **13** |
| **Security (Sisi Aplikasi)** | 0 | 0 | 4 | 2 | 1 | **7** |
| **Backend, Data & Privasi** | 0 | 2 | 2 | 3 | 0 | **7** |
| **Dependency & Supply Chain** | 0 | 3 | 4 | 3 | 1 | **11** |
| **Arsitektur & Kualitas Kode** | 0 | 5 | 5 | 3 | 0 | **13** |

---

## 3. TOP 10 PERBAIKAN PRIORITAS (URUTAN RISIKO & USAHA)

| No | ID | Kategori | Severity | Masalah Utama | Estimasi Usaha |
|:---:|:---|:---|:---:|:---|:---:|
| 1 | **PERF-07** | Performance / DB | **Critical** | Ketiadaan GIN index pada kolom array `groups.member_uids` (Full Table Scan setiap query/RLS). | **Kecil** |
| 2 | **PERF-01** | Performance / Battery | **Critical** | Duplikasi GPS foreground stream & background timer 5s berjalan serentak saat foreground (boros baterai ganda). | **Sedang** |
| 3 | **BUG-02** | Bug / Data | **High** | Kolom `birth_date` PostgreSQL bertipe `DATE`, namun dikirim ISO timestamp -> penyimpanan tanggal lahir gagal. | **Kecil** |
| 4 | **DEP-07** | Dependency / iOS | **High** | Ketiadaan `CFBundleURLTypes` di `Info.plist` -> Google Sign-In di iPhone macet saat redirect callback. | **Kecil** |
| 5 | **BACK-01** | Backend / Logic | **High** | Hapus akun via `delete_my_account` meninggalkan zombie headless groups yang mengunci kuota anggota lain. | **Kecil** |
| 6 | **BACK-02** | Privasi / Compliance | **High** | Ghost Mode adalah UI placebo lokal; koordinat GPS tetap dipancarkan ke Realtime Broadcast. | **Sedang** |
| 7 | **PERF-04** | Performance / UI | **High** | Rebuild seluruh pohon widget `MapPage` (FlutterMap, tile layer, sheet) setiap pergeseran koordinat 5 meter. | **Sedang** |
| 8 | **PERF-05** | Performance / Leak | **High** | Instansiasi `streamTripHistory(uid)` dipanggil langsung di dalam method `build()` `HistoryTab`. | **Kecil** |
| 9 | **ARCH-04** | UI / Theme | **High** | Fitur Dark Mode rusak karena puluhan warna terang (`Colors.white`, `0xFFF7F7FA`) di-hardcode di halaman utama. | **Sedang** |
| 10 | **DEP-06** | Native / Store | **High** | Package name masih `com.example.trackie` (pasti ditolak otomatis saat submit ke Google Play Console). | **Sedang** |

---

## 4. DAFTAR LENGKAP TEMUAN AUDIT PER KATEGORI

### A. BUG & CORRECTNESS

#### [BUG-16] Desinkronisasi Logika Kuota Grup: `getUserGroupCount` Menghitung Semua Grup Termasuk yang Berstatus 'ended'
- **Severity**: Critical
- **Kategori**: Bug / Logic Discrepancy
- **Lokasi**: [lib/services/group_service.dart:24-34](file:///d:/Projects/Trackie/lib/services/group_service.dart#L24-L34)
- **Masalah**: Pada Fase 1, validasi SQL `can_create_or_join_group(p_uid)` diubah agar hanya menghitung grup aktif (`g.status = 'active'`). Namun fungsi klien Dart `GroupService.getUserGroupCount` masih menghitung seluruh riwayat grup tanpa memfilter status grup.
- **Bukti**:
  ```dart
  final rows = await _supabase
      .from('groups')
      .select('id')
      .contains('member_uids', [uid]);
  return (rows as List).length; // Menghitung seluruh grup lama yang sudah 'ended'
  ```
- **Dampak**: Pengguna Free yang telah menyelesaikan 2 perjalanan (0 grup aktif) diblokir secara permanen oleh UI `HomeTab` saat ingin membuat atau bergabung dengan grup baru, padahal backend database Supabase mengizinkannya.
- **Rekomendasi**: Tambahkan filter status aktif: `.eq('status', 'active')`.
- **Estimasi Usaha**: Kecil

#### [BUG-18] Izin Lokasi Ditolak Memutus Listener `group_ended` (Member Terjebak di Peta)
- **Severity**: Critical
- **Kategori**: Bug / Lifecycle & Stream
- **Lokasi**: [lib/pages/map_page.dart:127-153](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L127-L153)
- **Masalah**: Di `MapPage._initRealTimeTracking()`, jika `locationProvider.requestPermissions()` mengembalikan `false`, fungsi melakukan *early return* sebelum mendengarkan stream `onGroupEnded`.
- **Bukti**:
  ```dart
  final granted = await locationProvider.requestPermissions();
  if (!mounted) return;
  if (!granted) {
    await locationProvider.startTracking(...);
    return; // <--- EARLY RETURN MEMUTUS EKSEKUSI DI BAWAHNYA
  }
  // Pendaftaran _groupEndedSubscription dilewati jika granted == false
  ```
- **Dampak**: Jika anggota rombongan menolak izin background GPS, listener `onGroupEnded` tidak pernah dipasang. Saat Host menyelesaikan trip, HP anggota tidak akan pernah menerima broadcast penutupan grup dan terjebak di peta.
- **Rekomendasi**: Pindahkan pendaftaran `_groupEndedSubscription` ke atas sebelum pengecekan `if (!granted)`.
- **Estimasi Usaha**: Kecil

#### [BUG-01] Race Condition Navigasi Deklaratif vs Imperatif Pasca-Login
- **Severity**: High
- **Kategori**: Bug / Navigasi
- **Lokasi**: [lib/app.dart:73-98](file:///d:/Projects/Trackie/lib/app.dart#L73-L98), [lib/pages/login_page.dart:60-75](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L60-L75)
- **Masalah**: `AuthWrapper` bereaksi otomatis terhadap perubahan session (`StreamBuilder`), namun `LoginPage` juga memanggil `Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (route) => false)`.
- **Dampak**: Perebutan kontrol routing memicu pemotongan dialog sukses atau penghapusan route root `/` dari navigator stack.
- **Rekomendasi**: Pusatkan navigasi root pada `AuthWrapper` secara reaktif berdasarkan state `AuthProvider` & `SubscriptionProvider`.
- **Estimasi Usaha**: Sedang

#### [BUG-02] Data Type Mismatch Kolom `birth_date` (PostgreSQL DATE vs ISO8601 Timestamp)
- **Severity**: High
- **Kategori**: Bug / Data Type
- **Lokasi**: [lib/models/user_model.dart:140](file:///d:/Projects/Trackie/lib/models/user_model.dart#L140), [lib/services/auth_service.dart:73](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L73)
- **Masalah**: Kolom `public.profiles.birth_date` bertipe `DATE` (`YYYY-MM-DD`). Di `UserModel.toSupabase()`, format yang dikirim adalah `birthDate?.toIso8601String()` (`YYYY-MM-DDTHH:mm:ss`). PostgreSQL menolak dengan error `invalid input syntax for type date`.
- **Bukti**:
  ```dart
  'birth_date': birthDate?.toIso8601String(), // Seharusnya split('T').first
  ```
- **Dampak**: Tanggal lahir profil pengguna baru selalu gagal tersimpan ke database `profiles`.
- **Rekomendasi**: Ubah menjadi `'birth_date': birthDate?.toIso8601String().split('T').first`.
- **Estimasi Usaha**: Kecil

#### [BUG-03] Silent Failure Inisialisasi Realtime Channel di Background Service
- **Severity**: Medium
- **Kategori**: Bug / Realtime
- **Lokasi**: [lib/services/background_location_service.dart:147-156](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L147-L156)
- **Masalah**: Jika token terlambat diterima background isolate, listener `updateToken` hanya memanggil `setAuth(token)` tanpa memvalidasi apakah channel tracking sudah aktif.
- **Dampak**: Pelacakan latar belakang gagal total secara hening (*silent failure*).
- **Rekomendasi**: Buat helper `_ensureChannel()` yang men-subscribe ulang channel jika token baru masuk.
- **Estimasi Usaha**: Kecil

#### [BUG-04] Polling GPS Bertumpuk Tanpa Timeout (`timeLimit`) di Timer Background Service
- **Severity**: Medium
- **Kategori**: Bug / Concurrency
- **Lokasi**: [lib/services/background_location_service.dart:202-211](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L202-L211)
- **Masalah**: `Timer.periodic(const Duration(seconds: 5))` memanggil `Geolocator.getCurrentPosition()` tanpa parameter `timeLimit`. Di daerah minim sinyal, request dapat memakan waktu >10 detik, memicu tumpukan request paralel.
- **Dampak**: Keborosan baterai dan potensi exception limit dari OS.
- **Rekomendasi**: Pasang flag `_isFetchingLocation` atau set `timeLimit: const Duration(seconds: 4)`.
- **Estimasi Usaha**: Kecil

#### [BUG-05] Tombol SOS Searah (Tanpa Cancel Toggle) & Peringatan Tersembunyi
- **Severity**: Medium
- **Kategori**: Bug / UX Safety
- **Lokasi**: [lib/pages/map_page.dart:945-980](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L945-L980), [lib/services/location_service.dart:345-365](file:///d:/Projects/Trackie/lib/services/location_service.dart#L345-L365)
- **Masalah**: Tombol SOS di UI tidak bisa dibatalkan jika salah tekan, dan sinyal SOS anggota lain hanya berupa badge kecil di dalam sheet yang terlipat.
- **Dampak**: Salah tekan tidak dapat dikoreksi; bahaya darurat di jalan berisiko tidak disadari rombongan.
- **Rekomendasi**: Buat tombol SOS menjadi toggle (Aktifkan / Batalkan), dan munculkan banner darurat merah menyala di atas peta jika ada rekan yang SOS.
- **Estimasi Usaha**: Sedang

#### [BUG-06] Ketiadaan Penanganan Error pada `StreamBuilder` Riwayat Perjalanan
- **Severity**: Medium
- **Kategori**: Bug / Offline State
- **Lokasi**: [lib/pages/history_tab.dart:113-168](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L113-L168)
- **Masalah**: `StreamBuilder` di `HistoryTab` tidak mengecek `snapshot.hasError`. Saat offline, `snapshot.data` bernilai null dan dianggap list kosong.
- **Dampak**: Pengguna mengira riwayat perjalanannya terhapus saat koneksi hilang.
- **Rekomendasi**: Tampilkan pesan offline dan tombol coba lagi jika `snapshot.hasError`.
- **Estimasi Usaha**: Kecil

#### [BUG-07] `GroupModel` Mengabaikan Kolom `destination` & `memberUids` pada `operator ==`
- **Severity**: Medium
- **Kategori**: Bug / State Management
- **Lokasi**: [lib/models/group_model.dart:175-198](file:///d:/Projects/Trackie/lib/models/group_model.dart#L175-L198)
- **Masalah**: Perbandingan kesetaraan objek `GroupModel` tidak menyertakan `destination` dan `memberUids`.
- **Dampak**: Widget UI yang mengandalkan perbandingan nilai objek tidak me-rebuild saat tujuan diubah atau anggota bertambah.
- **Rekomendasi**: Sertakan `destination` dan `listEquals(memberUids, other.memberUids)` di `operator ==` dan `hashCode`.
- **Estimasi Usaha**: Kecil

#### [BUG-08] Potensi Assertion Crash `CameraFit.bounds` pada Riwayat Perjalanan 0 Meter
- **Severity**: Medium
- **Kategori**: Bug / Crash
- **Lokasi**: [lib/pages/trip_detail_page.dart:374-379](file:///d:/Projects/Trackie/lib/pages/trip_detail_page.dart#L374-L379)
- **Masalah**: `CameraFit.bounds` dipanggil jika `points.length >= 2`. Jika seluruh koordinat bernilai sama persis (trip uji coba 0 meter), bounding box berdimensi 0 dapat memicu assertion crash di `flutter_map`.
- **Rekomendasi**: Validasi keberadaan minimal 2 titik dengan koordinat berbeda sebelum menyetel bounds fit.
- **Estimasi Usaha**: Kecil

#### [BUG-09] Dead Code Dialog Edukasi Izin Lokasi Permanen
- **Severity**: Low
- **Kategori**: Bug / UX Flow
- **Lokasi**: [lib/services/permission_service.dart:81](file:///d:/Projects/Trackie/lib/services/permission_service.dart#L81), [lib/pages/map_page.dart:127-138](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L127-L138)
- **Masalah**: `PermissionService.showPermissionDeniedDialog` tidak pernah dipanggil saat izin ditolak permanen.
- **Rekomendasi**: Panggil dialog edukasi jika status izin `isPermanentlyDenied`.
- **Estimasi Usaha**: Kecil

#### [BUG-10] Penggunaan Operator `!` Sembarangan Lintas Async Gap di `AuthProvider`
- **Severity**: Low
- **Kategori**: Bug / Null-Safety
- **Lokasi**: [lib/providers/auth_provider.dart:183-188](file:///d:/Projects/Trackie/lib/providers/auth_provider.dart#L183-L188)
- **Masalah**: Memanggil `_user!.uid` setelah `await uploadProfilePicture`. Jika user sign out saat upload berlangsung, memicu exception null check.
- **Rekomendasi**: Simpan `final currentUser = _user; if (currentUser == null) return false;` sebelum pemanggilan async.
- **Estimasi Usaha**: Kecil

#### [BUG-11] Data Dummy Statis Upcoming Trips di Halaman Home
- **Severity**: Info
- **Kategori**: Bug / Mock Data
- **Lokasi**: [lib/pages/home_tab.dart:670-691](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L670-L691)
- **Masalah**: Daftar jadwal trip mendatang di-hardcode di dalam widget tree, belum terhubung ke database.
- **Rekomendasi**: Hubungkan ke kueri database Supabase atau sembunyikan jika belum diimplementasikan.
- **Estimasi Usaha**: Sedang

---

### B. PERFORMANCE & EFISIENSI

#### [PERF-01] Duplikasi Stream GPS di Main Isolate & Polling Timer 5s di Background Isolate saat Foreground
- **Severity**: Critical
- **Kategori**: Performance / Battery & Network
- **Lokasi**: [lib/providers/location_provider.dart:127-152, 319-337](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L319), [lib/services/background_location_service.dart:200-230](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L200)
- **Masalah**: Saat pengguna berada di `MapPage`, main isolate menjalankan `Geolocator.getPositionStream` (mengirim broadcast lokasi ke WebSocket setiap pergerakan >= 5m). Pada saat yang sama, background isolate service tetap menyalakan polling timer 5 detik dan mengirim broadcast kedua ke topic yang sama.
- **Dampak**: Baterai terkuras dua kali lipat, traffic WebSocket berganda, dan koordinat bertabrakan timestamp.
- **Rekomendasi**: Matikan timer background isolate saat aplikasi berada di foreground, aktifkan HANYA saat aplikasi beralih ke background/paused.
- **Estimasi Usaha**: Sedang

#### [PERF-07] Tidak Ada GIN Index pada Kolom Array `member_uids` di Tabel `groups` (Full Table Scan)
- **Severity**: Critical
- **Kategori**: Performance / Database
- **Lokasi**: [supabase_schema.sql:106](file:///d:/Projects/Trackie/supabase_schema.sql#L106)
- **Masalah**: Kolom `public.groups.member_uids` bertipe `TEXT[]`. Evaluasi RLS (`WHERE auth.uid()::text = ANY (member_uids)`) dan kueri Flutter `.contains('member_uids', [uid])` berjalan tanpa indeks array PostgreSQL.
- **Dampak**: Full table scan pada tabel `groups` setiap kali user membuka aplikasi atau query grup aktif dijalankan.
- **Rekomendasi**: Pasang indeks GIN: `CREATE INDEX IF NOT EXISTS idx_groups_member_uids ON public.groups USING gin (member_uids);`.
- **Estimasi Usaha**: Kecil

#### [PERF-02] Tidak Ada Throttling pada Broadcast Lokasi Saat Berkendara Kecepatan Tinggi
- **Severity**: High
- **Kategori**: Performance / Network & Rendering
- **Lokasi**: [lib/providers/location_provider.dart:314-337](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L314)
- **Masalah**: Kecepatan 72 km/jam memicu `distanceFilter: 5` hingga 4 kali per detik. Tanpa rate limiting, 10 anggota konvoi menghasilkan 40 pesan WebSocket per detik dan 40 rebuild per detik di setiap HP member.
- **Dampak**: Frame drop parah, thermal throttling (HP panas), dan boros kuota.
- **Rekomendasi**: Pasang minimum interval throttle minimal 2.5–3 detik sebelum broadcast keluar.
- **Estimasi Usaha**: Kecil

#### [PERF-04] Rebuild Berlebihan pada Seluruh Pohon Widget `MapPage` Setiap Lokasi Update
- **Severity**: High
- **Kategori**: Performance / Rendering
- **Lokasi**: [lib/pages/map_page.dart:985-1065](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L985)
- **Masalah**: `context.watch<LocationProvider>()` diletakkan di root `build()`. Setiap pergeseran koordinat merebuild seluruh `FlutterMap`, `TileLayer`, dan `DraggableScrollableSheet`. Di samping itu, mutasi kamera dipanggil via `addPostFrameCallback` saat `build`.
- **Dampak**: Frame rate drop parah (< 30 fps) di perangkat Android kelas menengah.
- **Rekomendasi**: Pisahkan marker layer ke widget terpisah dengan `Selector`, dan pindahkan initial centering kamera ke listener `initState`.
- **Estimasi Usaha**: Sedang

#### [PERF-05] Instansiasi Stream Supabase di Dalam Method `build()` `HistoryTab`
- **Severity**: High
- **Kategori**: Performance / Resource Churn
- **Lokasi**: [lib/pages/history_tab.dart:113-115](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L113-L115)
- **Masalah**: `StreamBuilder(stream: _tripService.streamTripHistory(uid))` membuat instance Stream baru setiap kali tab dirender ulang.
- **Dampak**: Koneksi WebSocket berkedip (thrashing), boros kuota, dan berpotensi mencapai batas koneksi Supabase.
- **Rekomendasi**: Inisialisasi stream satu kali di `initState()` atau simpan di provider.
- **Estimasi Usaha**: Kecil

#### [PERF-06] Query `trip_history` Mengunduh Seluruh Array JSONB `route_path` Ratusan KB untuk List View Riwayat
- **Severity**: High
- **Kategori**: Performance / Data Payload
- **Lokasi**: [lib/services/trip_service.dart:41-50](file:///d:/Projects/Trackie/lib/services/trip_service.dart#L41-L50), [lib/providers/location_provider.dart:182-192](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L182)
- **Masalah**: List view ringkasan riwayat mengunduh seluruh kolom `route_path` yang berisi ratusan titik GPS. Selain itu, logika downsampling di `LocationProvider` memiliki bug terbalik (`if (pathPoints.length < 2)`) sehingga jika titik banyak, downsampling tidak berjalan!
- **Dampak**: Puluhan megabyte data JSON diunduh dan diparsing di main thread untuk sekadar melihat ringkasan trip.
- **Rekomendasi**: Kecualikan kolom `route_path` pada query list, dan perbaiki algoritma downsampling rute ke maksimal 100 titik.
- **Estimasi Usaha**: Sedang

#### [PERF-03] Penggunaan `distanceFilter` pada `Geolocator.getCurrentPosition` di Background Isolate Diabaikan OS
- **Severity**: Medium
- **Kategori**: Performance / Battery
- **Lokasi**: [lib/services/background_location_service.dart:206-211](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L206)
- **Masalah**: Parameter `distanceFilter` diabaikan oleh native Android/iOS pada pemanggilan `getCurrentPosition`.
- **Dampak**: GPS tetap dipolling tiap 5 detik saat kendaraan diam di lampu merah/parkir.
- **Rekomendasi**: Bandingkan koordinat terakhir via Haversine; lewati broadcast jika perpindahan < 10m.
- **Estimasi Usaha**: Kecil

#### [PERF-08] Penghitungan Kuota Grup Mengunduh Seluruh Baris Data ke Memori
- **Severity**: Medium
- **Kategori**: Performance / Database
- **Lokasi**: [lib/services/group_service.dart:24-35](file:///d:/Projects/Trackie/lib/services/group_service.dart#L24-L35)
- **Masalah**: Menghitung kuota grup dengan menarik array row ID lalu memanggil `.length` di Dart.
- **Rekomendasi**: Gunakan PostgREST aggregation `.count(CountOption.exact)`.
- **Estimasi Usaha**: Kecil

#### [PERF-09] Pembuangan Controller Modal Bottom Sheet Berbasis `Future.delayed(400ms)`
- **Severity**: Medium
- **Kategori**: Performance / Memory Leak
- **Lokasi**: [lib/pages/home_tab.dart:503-509](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L503-L509)
- **Masalah**: Controller modal bottom sheet di-dispose menggunakan timer delay manual.
- **Dampak**: Risiko `TextEditingController was used after being disposed` jika animasi modal terhambat.
- **Rekomendasi**: Ekstrak modal ke `StatefulWidget` tersendiri dengan `dispose()` deterministik.
- **Estimasi Usaha**: Kecil

#### [PERF-10] Penggunaan `context.watch` Berlebihan pada Root Tab
- **Severity**: Medium
- **Kategori**: Performance / Rebuild
- **Lokasi**: [lib/pages/home_tab.dart:659](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L659), [lib/pages/history_tab.dart:77](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L77)
- **Masalah**: Menonton provider penuh di root widget tree.
- **Rekomendasi**: Ganti dengan `context.select` atau `Selector`.
- **Estimasi Usaha**: Kecil

#### [PERF-11] Foto Avatar di `HomeTab` Menggunakan `NetworkImage` Mentah Tanpa Caching
- **Severity**: Low
- **Kategori**: Performance / Media
- **Lokasi**: [lib/pages/home_tab.dart:801-806](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L801-L806)
- **Masalah**: Avatar profil di Beranda di-download ulang setiap buka tab karena tidak menggunakan disk cache.
- **Rekomendasi**: Ganti dengan `CachedNetworkImageProvider`.
- **Estimasi Usaha**: Kecil

#### [PERF-12] Format Aset Gambar Onboarding Masih JPEG/PNG (~1.46 MB)
- **Severity**: Low
- **Kategori**: Performance / APK Size
- **Lokasi**: Direktori `assets/images/`
- **Masalah**: Tiga foto onboarding berukuran total ~1.46 MB.
- **Rekomendasi**: Konversi ke format `.webp` lossy 80% untuk memangkas ukuran hingga ~400 KB (hemat ~70%).
- **Estimasi Usaha**: Kecil

#### [PERF-13] Navigasi Tab Bottom Bar Merusak State Layar
- **Severity**: Info
- **Kategori**: Performance / UX State
- **Lokasi**: [lib/pages/main_page.dart:45](file:///d:/Projects/Trackie/lib/pages/main_page.dart#L45)
- **Masalah**: `body: _tabs[_selectedIndex]` me-mount dan me-unmount widget tab setiap kali berpindah tab.
- **Rekomendasi**: Gunakan `IndexedStack(index: _selectedIndex, children: _tabs)`.
- **Estimasi Usaha**: Kecil

---

### C. SECURITY (SISI APLIKASI)

#### [SEC-01] Token Sesi JWT Disimpan Tanpa Enkripsi di SharedPreferences
- **Severity**: Medium
- **Kategori**: Security / Storage
- **Lokasi**: [lib/main.dart:27-30](file:///d:/Projects/Trackie/lib/main.dart#L27-L30)
- **Masalah**: Default storage Supabase menyimpan token sesi ke dalam file XML teks biasa di `/data/data/.../shared_prefs/`.
- **Dampak**: Token sesi dapat diekstrak oleh penyerang pada perangkat yang di-root atau via backup ADB.
- **Rekomendasi**: Gunakan `flutter_secure_storage` sebagai custom `localStorage` pada `Supabase.initialize()`.
- **Estimasi Usaha**: Sedang

#### [SEC-02] `android:allowBackup` Tidak Didefinisikan (Default `true`)
- **Severity**: Medium
- **Kategori**: Security / Android Manifest
- **Lokasi**: [android/app/src/main/AndroidManifest.xml:17-20](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml#L17-L20)
- **Masalah**: Atribut `android:allowBackup` tidak diset secara eksplisit.
- **Dampak**: Data lokal dan token sesi dapat diekstrak via kabel USB melalui perintah `adb backup`.
- **Rekomendasi**: Tambahkan atribut `android:allowBackup="false"` di elemen `<application>`.
- **Estimasi Usaha**: Kecil

#### [SEC-03] `BackgroundService` Berpotensi Ter-export Tanpa Proteksi (`android:exported="true"`)
- **Severity**: Medium
- **Kategori**: Security / IPC
- **Lokasi**: [android/app/src/main/AndroidManifest.xml:51-53](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml#L51-L53)
- **Masalah**: Service background tidak mendefinisikan `android:exported="false"` secara tegas, berpotensi mewarisi `exported="true"` dari manifest library.
- **Rekomendasi**: Tambahkan `android:exported="false"` dan `tools:replace="android:exported"`.
- **Estimasi Usaha**: Kecil

#### [SEC-04] Tipe Build `release` Ditandatangani Menggunakan Kunci Debug Publik
- **Severity**: Medium
- **Kategori**: Security / Release Integrity
- **Lokasi**: [android/app/build.gradle.kts:38](file:///d:/Projects/Trackie/android/app/build.gradle.kts#L38)
- **Masalah**: `signingConfig = signingConfigs.getByName("debug")` pada build release.
- **Dampak**: APK rilis rentan di-repack dan ditolak oleh Google Play Store.
- **Rekomendasi**: Konfigurasi `key.properties` privat untuk rilis produksi.
- **Estimasi Usaha**: Sedang

#### [SEC-05] Ketiadaan Skema Deep Link Terverifikasi untuk Redirect Reset Password
- **Severity**: Low
- **Kategori**: Security / Deep Linking
- **Lokasi**: [lib/services/auth_service.dart:216](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L216)
- **Masalah**: Tautan email reset password tidak menyertakan `redirectTo` dan belum memiliki konfigurasi intent-filter callback ke aplikasi.
- **Rekomendasi**: Daftarkan App Links terverifikasi atau custom scheme callback.
- **Estimasi Usaha**: Sedang

#### [SEC-06] Desinkronisasi Client-Side Mock Subscription dengan Server-Side Authorization
- **Severity**: Low
- **Kategori**: Security / Architecture
- **Lokasi**: [lib/services/subscription_service.dart:270-281](file:///d:/Projects/Trackie/lib/services/subscription_service.dart#L270-L281)
- **Masalah**: `MockSubscriptionService` mencoba meng-update `profiles.plan` via client SDK; server menolaknya dengan benar, namun klien mengira sukses dan menyimpan lokal di SharedPreferences, memicu ketidaksinkronan batas kuota.
- **Rekomendasi**: Integrasikan server webhook / Edge Function ber-role `service_role` untuk update paket langganan.
- **Estimasi Usaha**: Sedang

#### [SEC-07] Default Anon Key Tersedia di Source Code Lokal
- **Severity**: Info
- **Kategori**: Security / Secrets
- **Lokasi**: [lib/supabase_config.dart:14-25](file:///d:/Projects/Trackie/lib/supabase_config.dart#L14-L25)
- **Masalah**: Anon key dan URL project tertanam sebagai fallback default di file Dart lokal.
- **Rekomendasi**: Gunakan `--dart-define` secara eksklusif untuk build rilis.
- **Estimasi Usaha**: Kecil

---

### D. BACKEND, DATA & PRIVASI

#### [BACK-01] Zombie Groups dan Headless Active Groups saat Host Menghapus Akun via `delete_my_account`
- **Severity**: High
- **Kategori**: Backend / Data Integrity
- **Lokasi**: [supabase_schema.sql:383-402](file:///d:/Projects/Trackie/supabase_schema.sql#L383-L402)
- **Masalah**: Saat Host menghapus akun, `delete_my_account()` hanya menghapus UID dari `member_uids`. Host_uid menjadi NULL dan status tetap 'active'. Tidak ada anggota yang bisa mengakhiri grup atau mengubah tujuan.
- **Dampak**: Grup aktif tak bertuan tertinggal permanen dan mengunci 1 kuota grup aktif seluruh sisa anggotanya selamanya.
- **Rekomendasi**: Terapkan logika transfer kepemilikan host ke anggota berikutnya atau ubah status menjadi `'ended'` jika anggota habis.
- **Estimasi Usaha**: Kecil

#### [BACK-02] Fitur "Ghost Mode" Hanyalah UI Placebo Lokal, Koordinat GPS Tetap Terpancar
- **Severity**: High
- **Kategori**: Backend / Privasi & Compliance
- **Lokasi**: [lib/pages/profile_tab.dart:26, 289-301](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L26), [lib/pages/privacy_policy_page.dart:78-83](file:///d:/Projects/Trackie/lib/pages/privacy_policy_page.dart#L78)
- **Masalah**: Toggle Ghost Mode hanya mengubah boolean lokal UI dan tidak pernah dioper ke `LocationProvider`/`LocationService`. GPS tetap dipantau dan dibroadcast ke WebSocket.
- **Dampak**: Pelanggaran privasi serius terhadap janji Kebijakan Privasi (potensi pelanggaran UU PDP No. 27/2022).
- **Rekomendasi**: Hubungkan status Ghost Mode ke `LocationProvider` untuk menghentikan pancaran `updateLocation`, atau sembunyikan fitur hingga implementasi siap.
- **Estimasi Usaha**: Sedang

#### [BACK-03] Race Condition (*TOCTOU*) pada `join_group` Memungkinkan Bypass Kuota Paket
- **Severity**: Medium
- **Kategori**: Backend / Concurrency
- **Lokasi**: [supabase_schema.sql:122-164, 291-331](file:///d:/Projects/Trackie/supabase_schema.sql#L122)
- **Masalah**: Row lock `FOR UPDATE` di `join_group` hanya mengunci baris grup target, bukan user. Dua request concurrent join bisa lolos validasi bersamaan.
- **Dampak**: Pengguna Free tier dapat masuk ke 3 atau lebih grup aktif sekaligus.
- **Rekomendasi**: Tambahkan advisory lock transaksional per user: `PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));`.
- **Estimasi Usaha**: Kecil

#### [BACK-04] Koordinat Jejak Rute (`route_path` JSONB) Disimpan Permanen Tanpa Fitur Hapus Riwayat
- **Severity**: Medium
- **Kategori**: Data / Privasi
- **Lokasi**: [supabase_schema.sql:170-183](file:///d:/Projects/Trackie/supabase_schema.sql#L170), [lib/services/trip_service.dart](file:///d:/Projects/Trackie/lib/services/trip_service.dart)
- **Masalah**: Jejak koordinat GPS disimpan selamanya tanpa batas retensi, dan UI tidak menyediakan opsi bagi pengguna untuk menghapus riwayat perjalanan tertentu (*Right to Erasure*).
- **Rekomendasi**: Sediakan fitur hapus riwayat trip di UI (`TripService.deleteTrip`) dan kebijakan retensi data rute.
- **Estimasi Usaha**: Sedang

#### [BACK-05] Policy `groups_update_as_host` Tidak Membatasi Kolom
- **Severity**: Low
- **Kategori**: Backend / RLS
- **Lokasi**: [supabase_schema.sql:278-281](file:///d:/Projects/Trackie/supabase_schema.sql#L278)
- **Masalah**: Host dapat meng-update langsung kolom `member_uids`, `status`, atau `invite_code` via panggilan REST langsung.
- **Rekomendasi**: Terapkan column-level privileges: izinkan update hanya untuk `name, type, destination`.
- **Estimasi Usaha**: Kecil

#### [BACK-06] Pembersihan Avatar di Supabase Storage Mengandalkan Klien
- **Severity**: Low
- **Kategori**: Storage / Data Clean-up
- **Lokasi**: [supabase_schema.sql:383-402](file:///d:/Projects/Trackie/supabase_schema.sql#L383), [lib/services/auth_service.dart:305-313](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L305)
- **Masalah**: Jika delete account dipicu langsung via RPC tanpa melewati client SDK, avatar di storage tertinggal menjadi file orphan.
- **Rekomendasi**: Tambahkan `DELETE FROM storage.objects WHERE bucket_id = 'avatars' AND (storage.foldername(name))[1] = v_uid::text;` di RPC `delete_my_account`.
- **Estimasi Usaha**: Kecil

#### [BACK-07] Anggota Non-Host Dapat Mengirim Broadcast `destination_update`
- **Severity**: Low
- **Kategori**: Backend / Realtime
- **Lokasi**: [supabase_schema.sql:497-502](file:///d:/Projects/Trackie/supabase_schema.sql#L497), [lib/services/location_service.dart:71-87](file:///d:/Projects/Trackie/lib/services/location_service.dart#L71)
- **Masalah**: Policy `realtime.messages` mengizinkan seluruh anggota grup mengirim broadcast ke topic grup. Anggota nakal dapat menyiarkan rute palsu.
- **Rekomendasi**: Validasi pengirim event `destination_update` di client listener terhadap `hostUid` grup aktif.
- **Estimasi Usaha**: Kecil

---

### E. DEPENDENCY & SUPPLY CHAIN

#### [DEP-02] `flutter_facebook_auth` Tanpa Konfigurasi Native SDK (Dead Weight ~15MB)
- **Severity**: High
- **Kategori**: Dependency / Native Configuration
- **Lokasi**: [pubspec.yaml:59](file:///d:/Projects/Trackie/pubspec.yaml#L59), [AndroidManifest.xml](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml), [Info.plist](file:///d:/Projects/Trackie/ios/Runner/Info.plist)
- **Masalah**: Paket Facebook Auth ada di `pubspec.yaml` dan tombol login aktif di `login_page.dart`, namun tidak memiliki konfigurasi native Meta SDK. Meskipun di Fase 1 sudah dipasangi error guard (tidak crash), tombol selalu gagal dan membebani binary APK/IPA sebesar ~15MB.
- **Rekomendasi**: Hapus plugin dan tombol Facebook Login jika tidak digunakan, atau lengkapi pendaftaran di Meta Developer Console.
- **Estimasi Usaha**: Kecil

#### [DEP-06] `applicationId` dan `namespace` Masih Menggunakan Default `com.example.trackie`
- **Severity**: High
- **Kategori**: Dependency / Native Configuration
- **Lokasi**: [android/app/build.gradle.kts:9, 21](file:///d:/Projects/Trackie/android/app/build.gradle.kts#L9), [ios/Runner.xcodeproj/project.pbxproj:386](file:///d:/Projects/Trackie/ios/Runner.xcodeproj/project.pbxproj#L386)
- **Masalah**: Package name masih memakai default template Flutter.
- **Dampak**: Google Play Store menolak otomatis package name `com.example.*`.
- **Rekomendasi**: Ganti ke package name resmi (mis. `id.trackie.app` atau `com.trackie.touring`).
- **Estimasi Usaha**: Sedang

#### [DEP-07] Ketiadaan `CFBundleURLTypes` di `ios/Runner/Info.plist` untuk OAuth Callback (Google Sign-In)
- **Severity**: High
- **Kategori**: Native Configuration / iOS
- **Lokasi**: [ios/Runner/Info.plist:1-91](file:///d:/Projects/Trackie/ios/Runner/Info.plist)
- **Masalah**: Tidak ada registrasi Reversed Client ID Google di `CFBundleURLTypes`.
- **Dampak**: Alur login Google Sign-In di iOS menggantung/freeze setelah memilih akun.
- **Rekomendasi**: Tambahkan blok `CFBundleURLTypes` dengan Reversed Client ID di `Info.plist`.
- **Estimasi Usaha**: Kecil

#### [DEP-03] `flutter_local_notifications` Tertinggal 4 Versi Mayor (v18.0.1 -> v22.3.2)
- **Severity**: Medium
- **Kategori**: Dependency
- **Lokasi**: [pubspec.yaml:48](file:///d:/Projects/Trackie/pubspec.yaml#L48)
- **Masalah**: Tertinggal 4 versi mayor, berpotensi memicu build error saat AGP dinaikkan atau saat menargetkan Android 15.
- **Rekomendasi**: Upgrade bertahap ke `^22.3.2` dan uji notifikasi channel.
- **Estimasi Usaha**: Sedang

#### [DEP-04] `google_sign_in` Dipin Kaku pada Versi Lama (6.2.1) Tanpa Credential Manager
- **Severity**: Medium
- **Kategori**: Dependency
- **Lokasi**: [pubspec.yaml:58](file:///d:/Projects/Trackie/pubspec.yaml#L58)
- **Masalah**: Dipin tanpa caret `^`, mengabaikan pembaruan Android Credential Manager API di versi 7.x.
- **Rekomendasi**: Lepas pin ke `^6.2.1` dan rencanakan migrasi ke `^7.2.0`.
- **Estimasi Usaha**: Sedang

#### [DEP-05] `permission_handler` Tertinggal 2 Versi Mayor (v11.4.0 -> v13.0.2)
- **Severity**: Medium
- **Kategori**: Dependency
- **Lokasi**: [pubspec.yaml:49](file:///d:/Projects/Trackie/pubspec.yaml#L49)
- **Masalah**: Belum optimal menangani kebijakan perizinan granular Android 14+ dan AGP 8.5+.
- **Rekomendasi**: Upgrade ke `^13.0.2`.
- **Estimasi Usaha**: Kecil

#### [DEP-08] File `ios/Podfile` Tidak Ada di Repositori & Ketiadaan Macro Flags `permission_handler`
- **Severity**: Medium
- **Kategori**: Native Configuration / iOS
- **Lokasi**: Direktori `ios/`
- **Masalah**: Berkas `Podfile` belum di-commit, dan macro compiler `PERMISSION_LOCATION=1` belum disetel.
- **Dampak**: Izin lokasi di iOS dapat selalu mengembalikan Denied jika macro tidak dikompilasi.
- **Rekomendasi**: Generate `Podfile` dan pasang post-install macro flags.
- **Estimasi Usaha**: Sedang

#### [DEP-01] Dead / Unused Dependencies (`uuid` dan `cupertino_icons`) di `pubspec.yaml`
- **Severity**: Low
- **Kategori**: Dependency
- **Lokasi**: [pubspec.yaml:36, 44](file:///d:/Projects/Trackie/pubspec.yaml#L36)
- **Masalah**: Memiliki 0 import di seluruh `lib/` dan `test/`.
- **Rekomendasi**: Hapus dari `pubspec.yaml`.
- **Estimasi Usaha**: Kecil

#### [DEP-09] Signing Config Release Masih Menggunakan Debug Keystore
- **Severity**: Low
- **Kategori**: Native Configuration
- **Lokasi**: [android/app/build.gradle.kts:34-40](file:///d:/Projects/Trackie/android/app/build.gradle.kts#L34)
- **Masalah**: Build release menandatangani file dengan debug key bawaan.
- **Rekomendasi**: Siapkan `key.properties` privat.
- **Estimasi Usaha**: Sedang

#### [DEP-10] `google_fonts` Tertinggal Versi Mayor (v8.2.1 -> v9.0.0)
- **Severity**: Low
- **Kategori**: Dependency
- **Lokasi**: [pubspec.yaml:37](file:///d:/Projects/Trackie/pubspec.yaml#L37)
- **Masalah**: Versi 9.0.0 tersedia; periksa keselarasan metrik font setelah update.
- **Rekomendasi**: Upgrade ke `^9.0.0`.
- **Estimasi Usaha**: Kecil

#### [DEP-11] Transitive Dependency `archive` Tertinggal (`4.3.0` -> `4.5.2`)
- **Severity**: Info
- **Kategori**: Supply Chain
- **Lokasi**: [pubspec.lock:51](file:///d:/Projects/Trackie/pubspec.lock#L51)
- **Rekomendasi**: Jalankan `flutter pub upgrade`.
- **Estimasi Usaha**: Kecil

---

### F. ARSITEKTUR & KUALITAS KODE

#### [ARCH-01] UI Pages Mengakses Concrete Service Langsung Bypassing Provider Layer
- **Severity**: High
- **Kategori**: Arsitektur / Layering
- **Lokasi**: [lib/pages/history_tab.dart:72](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L72), [lib/pages/home_tab.dart:24](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L24), [lib/pages/map_page.dart:94, 843](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L94), [lib/app.dart:69](file:///d:/Projects/Trackie/lib/app.dart#L69)
- **Masalah**: UI menginstansiasi concrete service secara mandiri (`TripService()`, `RoutingService()`, `SupabaseConfig.client.auth`) melompati state management Provider. Proyek sama sekali belum memiliki `TripProvider`.
- **Dampak**: Pelanggaran arsitektur berlapis; UI tidak dapat di-test terisolasi.
- **Rekomendasi**: Buat `TripProvider` untuk membungkus `TripService`, dan suntikkan `RoutingService` via Provider.
- **Estimasi Usaha**: Sedang

#### [ARCH-02] God Classes & Massive View Files (>1.000 Baris) Melanggar SRP
- **Severity**: High
- **Kategori**: Arsitektur / SRP
- **Lokasi**:
  - `lib/pages/map_page.dart` (**1.547 baris**)
  - `lib/pages/subscription_page.dart` (**1.486 baris**)
  - `lib/pages/home_tab.dart` (**1.236 baris**)
  - `lib/providers/location_provider.dart` (**681 baris**)
- **Masalah**: Pelanggaran Single Responsibility Principle berat; logika navigasi, modal bottom sheet ratusan baris, downsampling koordinat, geocoding, dan rendering peta bercampur dalam satu file raksasa.
- **Dampak**: Cognitive load tinggi, risiko conflict kerja tim, dan sulit dipelihara.
- **Rekomendasi**: Dekomposisi ke dalam sub-widget mandiri di `lib/widgets/` (mis. `DestinationSearchSheet`, `MapMemberOverlay`, `CreateGroupModal`, `SubscriptionTierCard`).
- **Estimasi Usaha**: Besar

#### [ARCH-03] Ketiadaan Constructor Dependency Injection di Provider
- **Severity**: High
- **Kategori**: Arsitektur / Testability
- **Lokasi**: [lib/providers/auth_provider.dart:17](file:///d:/Projects/Trackie/lib/providers/auth_provider.dart#L17), [lib/providers/group_provider.dart:6](file:///d:/Projects/Trackie/lib/providers/group_provider.dart#L6), [lib/providers/location_provider.dart:27](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L27)
- **Masalah**: Seluruh provider (kecuali `SubscriptionProvider`) menginstansiasi concrete service secara hardcoded tanpa constructor parameter.
- **Dampak**: Unit testing murni menggunakan MockService tidak bisa dilakukan.
- **Rekomendasi**: Terapkan optional constructor injection: `AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();`.
- **Estimasi Usaha**: Kecil

#### [ARCH-04] Inkonsistensi Tema Dark Mode: Puluhan Warna Hardcoded Merusak Kontras
- **Severity**: High
- **Kategori**: Desain & Tema
- **Lokasi**: [lib/pages/login_page.dart:233](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L233), [lib/pages/signup_page.dart:123](file:///d:/Projects/Trackie/lib/pages/signup_page.dart#L123), [lib/pages/history_tab.dart:91](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L91), [lib/pages/profile_tab.dart:104, 220](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L104)
- **Masalah**: Meng-hardcode warna terang (`Colors.white`, `const Color(0xFFF7F7FA)`, `const Color(0xFF1A1A2E)`).
- **Dampak**: Saat Dark Mode aktif, layar tetap menyala putih menyilaukan dan kontras teks rusak.
- **Rekomendasi**: Ganti dengan semantic token: `Theme.of(context).scaffoldBackgroundColor`, `colorScheme.surface`, dan `colorScheme.onSurface`.
- **Estimasi Usaha**: Sedang

#### [ARCH-11] Hack Struktural Penyimpanan Data Delimited String `'||'` di RoutingService & TripHistoryModel
- **Severity**: High
- **Kategori**: Arsitektur Data / Code Smell
- **Lokasi**: [lib/services/routing_service.dart:148-177](file:///d:/Projects/Trackie/lib/services/routing_service.dart#L148), [lib/models/trip_history_model.dart:55-88](file:///d:/Projects/Trackie/lib/models/trip_history_model.dart#L55)
- **Masalah**: Menggabungkan data terstruktur ke satu kolom string dengan delimiter `||` (contoh: `'Monas||lat,lng'` dan `'groupName||dest||role'`) demi menghindari migrasi database SQL.
- **Dampak**: Data tidak dapat diindeks atau di-filter via query SQL PostgreSQL di Supabase; rentan error parsing.
- **Rekomendasi**: Buat kolom terpisah di tabel database (`destination_name`, `destination_lat`, `destination_lng`, `user_role`).
- **Estimasi Usaha**: Sedang

#### [ARCH-05] God Provider `LocationProvider` Menggabungkan 6 Domain Berbeda
- **Severity**: Medium
- **Kategori**: Arsitektur / SRP
- **Lokasi**: [lib/providers/location_provider.dart:1-681](file:///d:/Projects/Trackie/lib/providers/location_provider.dart)
- **Masalah**: Menggabungkan GPS streaming, Supabase Realtime broadcast, routing OSRM, trip history collection, Background Service OS, dan auth token sync.
- **Rekomendasi**: Pecah menjadi `LocationProvider` (GPS/telemetry) dan `NavigationProvider` (rute/tujuan OSRM).
- **Estimasi Usaha**: Besar

#### [ARCH-06] Monolitik Modal di `HomeTab` (Inline Bottom Sheets 500+ Baris)
- **Severity**: Medium
- **Kategori**: Arsitektur
- **Lokasi**: [lib/pages/home_tab.dart:172-657](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L172)
- **Masalah**: Menulis modal buat grup dan gabung grup secara inline dengan `StatefulBuilder` ratusan baris.
- **Rekomendasi**: Ekstrak masing-masing modal ke widget mandiri di `lib/widgets/home/`.
- **Estimasi Usaha**: Sedang

#### [ARCH-07] Abstraction Leak Supabase Auth & Token Sync di dalam `LocationProvider`
- **Severity**: Medium
- **Kategori**: Arsitektur
- **Lokasi**: [lib/providers/location_provider.dart:145, 510-545](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L510)
- **Masalah**: Mengakses langsung singleton `SupabaseConfig.client.auth` dan timer 5 menit untuk update token background.
- **Rekomendasi**: Pindahkan siklus hidup token background isolate ke `AuthService`.
- **Estimasi Usaha**: Sedang

#### [ARCH-09] Inkonsistensi Tipografi Sistem-Wide (130 Pemanggilan `GoogleFonts.urbanist` Langsung)
- **Severity**: Medium
- **Kategori**: Desain
- **Lokasi**: Tersebar di 130 baris kode di 11 file UI
- **Masalah**: Mem-bypass `AppTheme` dengan memanggil langsung `GoogleFonts.urbanist` secara hardcoded.
- **Rekomendasi**: Selaraskan typography di `AppTheme` dan gunakan `Theme.of(context).textTheme`.
- **Estimasi Usaha**: Sedang

#### [ARCH-10] Duplikasi Logika Pencarian Tempat (Nominatim) di `home_tab.dart` dan `map_page.dart`
- **Severity**: Medium
- **Kategori**: DRY
- **Lokasi**: [lib/pages/home_tab.dart:195](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L195), [lib/pages/map_page.dart:1299](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L1299)
- **Masalah**: Logika debounce pencarian alamat Nominatim ditulis dua kali secara mandiri.
- **Rekomendasi**: Ekstrak menjadi shared widget `PlaceSearchAutocomplete`.
- **Estimasi Usaha**: Kecil

#### [ARCH-12] Ketidaklengkapan Adopsi Lokalisasi (`l10n`)
- **Severity**: Medium
- **Kategori**: Lokalisasi
- **Lokasi**: `lib/l10n/` vs hardcoded text di halaman-halaman utama
- **Masalah**: Hanya 41 string terdaftar di `.arb` dan hanya dipanggil di 4 file; halaman utama masih bahasa campuran hardcode.
- **Rekomendasi**: Ekstrak seluruh teks user-facing ke berkas `.arb`.
- **Estimasi Usaha**: Sedang

#### [ARCH-13] Domain Model `TripHistory` Didefinisikan di Layer Presentasi (`history_tab.dart`)
- **Severity**: Low
- **Kategori**: Arsitektur
- **Lokasi**: [lib/pages/history_tab.dart:13-62](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L13), [lib/pages/trip_detail_page.dart:11](file:///d:/Projects/Trackie/lib/pages/trip_detail_page.dart#L11)
- **Masalah**: Model data `TripHistory` ditaruh di dalam file UI `history_tab.dart`, memaksa page lain meng-import file page.
- **Rekomendasi**: Pindahkan ke `lib/models/trip_history.dart` atau gabungkan ke `trip_history_model.dart`.
- **Estimasi Usaha**: Kecil

---

## 5. HAL YANG SUDAH BAIK / BEST PRACTICES (JANGAN DIUBAH)

1. **Hasil Pembenahan Fase 1 Terbukti Tangguh**:
   - `flutter test` lulus 100% pada seluruh 8 widget & unit test.
   - `flutter analyze` 100% bersih tanpa error/warning.
   - Kolom langganan aman dari eskalasi hak akses berkat `REVOKE UPDATE` dan trigger `protect_profile_subscription_fields()`.
   - `PopScope` dan tombol back `AppBar` di `MapPage` berhasil mencegah GPS bocor saat pengguna keluar.
   - Host menyiarkan event `group_ended` sebelum menutup grup, memicu auto-save riwayat perjalanan anggota secara deterministik.
2. **Zero Database Write Tracking Architecture**:
   Pelacakan posisi rombongan dan sinyal SOS sepenuhnya menggunakan WebSocket Supabase Realtime Broadcast tanpa menulis jutaan koordinat GPS ke disk database. Keputusan arsitektur ini sangat tepat dan hemat biaya.
3. **Private Realtime Channel Authorization**:
   Topic `group_tracking:<group_id>` dipagari oleh Row Level Security `realtime.messages` dan fungsi verifikasi keanggotaan `can_access_tracking_topic`. Non-anggota grup tidak dapat mengintip lokasi rombongan.
4. **Hardened PostgreSQL Stored Functions**:
   Seluruh fungsi `SECURITY DEFINER` di `supabase_schema.sql` menetapkan `SET search_path = ''` dan mengkualifikasikan skema `public.`, mencegah serangan *Search Path Hijacking*.
5. **Isolasi Supabase Storage Bucket**:
   Bucket `avatars` membatasi ukuran maksimal 5 MB, membatasi whitelist MIME type (`jpeg`, `png`, `webp`), dan membatasi manipulasi hanya pada folder UID pemiliknya sendiri.
6. **Kalkulasi Matematis Haversine Baku & Stateless**:
   Implementasi jarak di `HaversineUtils` menggunakan radius bumi 6371.0 km dan formula trigonometri yang akurat, berstatus utility murni tanpa dependensi eksternal, dan teruji 100% di unit test.
7. **Pembersihan Log Sensitif**:
   Tidak ada fungsi `print()` mentah di codebase `lib/`. Seluruh logging menggunakan `debugPrint()` tanpa mencetak koordinat presisi atau token autentikasi.
8. **Enkapsulasi Network Terenkripsi**:
   Seluruh panggilan eksternal (Supabase, OSRM, Nominatim) menggunakan HTTPS murni tanpa bypass sertifikat SSL.

---

## 6. ROADMAP PERBAIKAN BERDASARKAN PRIORITAS

### Fase 2: Performa, Database & Stabilitas (Sprint Berikutnya)
- [ ] **Pasang GIN Index pada `member_uids` (PERF-07)**: Buat file migrasi SQL untuk mempercepat kueri grup dan evaluasi RLS.
- [ ] **Optimasi Ganda GPS Background/Foreground (PERF-01)**: Hilangkan duplikasi stream/service; matikan polling timer background saat aplikasi di foreground.
- [ ] **Beri Throttling pada Broadcast GPS (PERF-02)**: Batasi broadcast keluar minimal 2.5–3 detik saat kendaraan melaju kencang.
- [ ] **Perbaiki Tipe Data `birth_date` (BUG-02)**: Potong timestamp ISO menjadi `YYYY-MM-DD` agar upsert profil berhasil di Supabase.
- [ ] **Benahi Ghost Mode (BACK-02)**: Sambungkan toggle Ghost Mode ke `LocationProvider` agar menghentikan pancaran GPS.
- [ ] **Cegah Zombie Groups saat Host Hapus Akun (BACK-01)**: Perbarui RPC `delete_my_account` agar mentransfer host atau menutup grup.
- [ ] **Pindahkan Realtime Stream dari `HistoryTab.build` (PERF-05)**: Simpan instance stream di `initState`.
- [ ] **Optimasi Rebuild `MapPage` (PERF-04)**: Pisahkan marker layer ke sub-widget dengan `Selector`.
- [ ] **Optimasi Query Riwayat (PERF-06)**: Kecualikan kolom `route_path` pada query list dan perbaiki bug downsampling.
- [ ] **Perbaiki Fitur Dark Mode (ARCH-04)**: Ganti hardcoded `Colors.white` dan `0xFFF7F7FA` dengan token tema dinamis.
- [ ] **Amankan Sesi JWT dengan `flutter_secure_storage` (SEC-01)**: Hindari penyimpanan token plaintext di SharedPreferences.
- [ ] **Set `android:allowBackup="false"` & `exported="false"` (SEC-02, SEC-03)**: Amankan platform Android dari ekstraksi USB ADB.

### Fase 3: Arsitektur, UI Polish & Tech Debt (Backlog)
- [ ] **Dekomposisi God Classes (ARCH-02)**: Pecah `map_page.dart`, `subscription_page.dart`, dan `home_tab.dart` ke file sub-widget terpisah.
- [ ] **Buat `TripProvider` & Constructor DI (ARCH-01, ARCH-03)**: Hilangkan direct instantiation service di UI dan Provider.
- [ ] **Ganti Delimited String dengan Kolom Database (ARCH-11)**: Migrasi kolom formal `destination_name`, `destination_lat`, `destination_lng`.
- [ ] **Bersihkan Dead Dependencies (DEP-01, DEP-02)**: Hapus `uuid`, `cupertino_icons`, dan bersihkan `flutter_facebook_auth`.
- [ ] **Konfigurasi Keystore Rilis & Ganti `com.example.trackie` (SEC-04, DEP-06)**: Siapkan `key.properties` dan package name resmi.
- [ ] **Tambahkan `CFBundleURLTypes` di iOS (DEP-07)**: Perbaiki callback Google Sign-In di iPhone.
- [ ] **Gunakan `IndexedStack` di Bottom Navigation (PERF-13)**: Jaga state halaman saat berpindah tab.
- [ ] **Berikan Tombol Batalkan SOS (BUG-05)**: Buat tombol darurat menjadi toggle interaktif dua arah.
- [ ] **Konversi Gambar Onboarding ke `.webp` (PERF-12)**: Hemat ~1 MB ukuran bundle aplikasi.
- [ ] **Lengkapi File Lokalisasi (ARCH-12)**: Pindahkan seluruh string hardcoded ke file `.arb`.

---

## 7. AREA DI LUAR CAKUPAN / MEMBUTUHKAN AKSES TAMBAHAN

1. **Akses Langsung Supabase Dashboard**:
   - Pengecekan apakah GIN index dan migrasi Fase 1 telah dieksekusi di database cloud production memerlukan akses SQL Editor / Supabase CLI live.
2. **Kredensial Google Cloud Console & Meta Developer Console**:
   - Pembuatan Reversed Client ID iOS (`CFBundleURLTypes`) dan SHA-1 fingerprint signing key membutuhkan akses konsol pengembang terkait.
3. **Pengujian Build Release Fisik (Thermal & Battery Run)**:
   - Evaluasi konsumsi daya baterai touring multi-jam pada perangkat fisik Android (khususnya penanganan Doze Mode pada vendor Xiaomi MIUI / Samsung OneUI) memerlukan pengujian perangkat fisik langsung.
