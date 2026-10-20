# LAPORAN AUDIT MENYELURUH (AUDIT REVIEW REPORT) — PROJECT TRACKIE

**Nama Proyek:** Trackie (Aplikasi Pelacakan Lokasi Grup & Touring)  
**Platform:** Flutter (Android, iOS, Web)  
**Tanggal Audit:** 20 Oktober 2026  
**Auditor:** Multi-Agent Specialist Panel (Orchestrated by Lead Reviewer)  
**Mode Audit:** READ-ONLY (Dokumentasi Murni, Tanpa Modifikasi Kode)  

---

## 1. RINGKASAN EKSEKUTIF

Aplikasi **Trackie** menunjukkan fondasi teknis yang kuat dalam pemanfaatan ekosistem Flutter modern dan arsitektur database Supabase, terutama keputusan cerdas menggunakan **Supabase Realtime Broadcast (Zero Database Write)** untuk koordinasi konvoi real-time, penguncian *search path* fungsi PostgreSQL, serta ketiadaan kebocoran *private API secret*. Namun, audit multi-agent menemukan beberapa celah kritis yang dapat menghentikan deployment produksi dan merusak pengalaman pengguna:
1. **Crash Runtime Fatal & Penolakan App Store**: Fitur Facebook Login tidak memiliki konfigurasi native sama sekali di Android/iOS (pasti crash saat ditekan), izin kamera/galeri (`image_picker`) tidak dideklarasikan di `ios/Runner/Info.plist`, dan `flutter test` gagal total.
2. **Eskalasi Hak Akses (Privilege Escalation) & Bug Kuota**: Policy RLS `profiles_update_own` mengizinkan pengguna mengubah kolom `plan` menjadi `premium` langsung dari client SDK tanpa melalui payment gateway. Di sisi lain, fungsi batas kuota menghitung grup yang sudah selesai (`ended`), sehingga pengguna Free terkunci permanen setelah 2 perjalanan.
3. **Kebocoran Baterai & Desinkronisasi GPS**: Terjadi duplikasi pelacakan GPS (Foreground Stream + Background Timer 5s berjalan serentak), ketiadaan `PopScope` di halaman peta menyebabkan GPS terus menyala setelah tombol back ditekan, serta pengakhiran perjalanan oleh Host tidak menyiarkan sinyal selesai ke anggota rombongan.

### Skor Kesehatan Proyek (Skala 1 - 10)

| Kategori | Skor | Catatan Evaluasi |
|:---|:---:|:---|
| **Bug & Correctness** | **6.5 / 10** | Analisis linter bersih, namun `flutter test` gagal, desinkronisasi lifecycle grup, dan format `birth_date` salah. |
| **Performa & Efisiensi** | **6.0 / 10** | Konsep broadcast sangat hemat DB, namun GPS polling ganda dan rebuild peta total memicu *battery drain* & *jank*. |
| **Security (Sisi Aplikasi)** | **7.0 / 10** | HTTPS menyeluruh, tidak ada secret bocor, namun token di SharedPreferences biasa dan `allowBackup=true`. |
| **Backend, Data & Privasi** | **6.5 / 10** | RLS dan Private Channel aman, namun `profiles.plan` dapat di-tamper dan Ghost Mode masih berupa *placebo*. |
| **Dependency & Supply Chain** | **6.5 / 10** | AGP & SDK modern, namun Facebook Auth memicu crash instan dan beberapa package tertinggal versi mayor. |
| **Arsitektur & Kualitas Kode** | **5.5 / 10** | Struktur folder rapi, namun memiliki *God Classes* (>1.400 baris), hardcoded colors merusak Dark Mode, dan nihil DI. |
| **RATA-RATA KESELURUHAN** | **6.3 / 10** | **Perlu Pembenahan Sebelum Rilis Produksi (Beta-Ready)** |

---

## 2. TABEL RINGKASAN TEMUAN

### Berdasarkan Tingkat Keparahan (Severity)
| Severity | Jumlah | Deskripsi Dampak |
|:---|:---:|:---|
| **Critical** | **5** | Crash fatal, eskalasi hak akses (bypass monetisasi), tes suite gagal, kebocoran GPS/stuck trip. |
| **High** | **14** | Kebocoran baterai/resource, pelanggaran privasi (Ghost Mode), RLS flaw, desinkronisasi navigasi, broken Dark Mode. |
| **Medium** | **17** | Query database lambat, duplikasi UI, race condition concurrency, memory leak potensional. |
| **Low** | **7** | Dead code, dead dependencies, validasi password lemah, hardcoded strings. |
| **Info** | **5** | Boilerplate naming, file git hygiene, optimasi aset gambar. |
| **TOTAL** | **48** | *(Setelah konsolidasi temuan lintas-agent)* |

### Berdasarkan Kategori
| Kategori | Critical | High | Medium | Low | Info | Total |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Bug & Correctness** | 2 | 4 | 6 | 2 | 1 | **15** |
| **Performance & Efisiensi** | 1 | 3 | 5 | 3 | 0 | **12** |
| **Security (Sisi Aplikasi)** | 1 | 0 | 4 | 4 | 1 | **10** |
| **Backend, Data & Privasi** | 1 | 3 | 4 | 1 | 1 | **10** |
| **Dependency & Supply Chain** | 1 | 2 | 3 | 2 | 3 | **11** |
| **Arsitektur & Kualitas Kode** | 0 | 4 | 4 | 2 | 0 | **10** |

---

## 3. TOP 10 PERBAIKAN PRIORITAS (URUTAN RISIKO & USAHA)

| No | ID | Kategori | Severity | Masalah Utama | Estimasi Usaha |
|:---:|:---|:---|:---:|:---|:---:|
| 1 | **BACK-01 / SEC-01** | Backend / Security | **Critical** | User dapat meng-update kolom `plan = 'premium'` langsung dari client SDK (Bypass bayar total). | **Sedang** |
| 2 | **DEP-06 / SEC-08** | Dependency / Bug | **Critical** | Tombol Facebook Login aktif tanpa konfigurasi native di Android/iOS -> Crash seketika saat ditekan. | **Kecil** |
| 3 | **BUG-01 / ARCH-03** | Bug / Testing | **Critical** | `flutter test` gagal total karena string mismatch `'Trackie.'` vs `'Trackie'` dan nihil mock Supabase. | **Kecil** |
| 4 | **BUG-02** | Bug / Realtime | **Critical** | Host menyelesaikan perjalanan tanpa broadcast `group_ended` -> Anggota stuck di peta, GPS bocor. | **Sedang** |
| 5 | **PERF-01 / PERF-04** | Performance | **Critical** | Main isolate stream & background service timer berjalan serentak -> Boros baterai & kuota ganda. | **Sedang** |
| 6 | **DEP-07 / SEC-05** | Dependency / iOS | **High** | `image_picker` tidak didukung `NSPhotoLibraryUsageDescription` di iOS `Info.plist` -> Crash & App Store reject. | **Kecil** |
| 7 | **BUG-03** | Bug / Resource | **High** | `MapPage` tidak memiliki `PopScope` -> Back gesture menutup halaman tanpa mematikan background tracking. | **Kecil** |
| 8 | **BUG-05** | Bug / Data | **High** | Kolom `birth_date` PostgreSQL bertipe `DATE`, tapi model mengirim ISO timestamp -> Upsert profil gagal. | **Kecil** |
| 9 | **BACK-04** | Backend / Logic | **Medium** | Validasi kuota menghitung grup yang sudah `ended` -> Pengguna Free terkunci permanen setelah 2 touring. | **Kecil** |
| 10 | **BACK-07** | Backend / Privasi | **High** | Ghost Mode hanya toggle lokal UI dan tetap memancarkan koordinat ke WebSocket -> Pelanggaran privasi. | **Sedang** |

---

## 4. DAFTAR LENGKAP TEMUAN AUDIT PER KATEGORI

### A. BUG & CORRECTNESS

#### [BUG-01] Kegagalan Test Suite & Ketiadaan Unit Test Modul Kritis
- **Severity**: Critical
- **Lokasi**: [test/widget_test.dart:14](file:///d:/Projects/Trackie/test/widget_test.dart#L14), [lib/pages/login_page.dart:265](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L265)
- **Masalah**: `flutter test` gagal karena mencari string `'Trackie.'` (dengan titik), sementara teks UI aktual adalah `'Trackie'`. Selain itu, tes memanggil `TrackieApp()` tanpa mock Supabase sehingga memicu unhandled exception.
- **Bukti**:
  ```dart
  expect(find.text('Trackie.'), findsOneWidget); // Actual: Found 0 widgets
  ```
- **Dampak**: Pipa CI/CD gagal, regresi logika tidak terdeteksi.
- **Rekomendasi**: Perbaiki string pencarian, pasang mock `SharedPreferences.setMockInitialValues()`, dan buat unit test untuk service bisnis (`HaversineUtils`, `RoutingService`, `SubscriptionProvider`).
- **Estimasi Usaha**: Sedang

#### [BUG-02] Desinkronisasi Status Grup Selesai & Kebocoran Pelacakan Anggota
- **Severity**: Critical
- **Lokasi**: [lib/pages/map_page.dart:830-840](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L830-L840), [lib/services/group_service.dart:115](file:///d:/Projects/Trackie/lib/services/group_service.dart#L115), [supabase_schema.sql:442-447](file:///d:/Projects/Trackie/supabase_schema.sql#L442-L447)
- **Masalah**: Saat Host menekan "Selesaikan Perjalanan", RPC `end_group` mengubah status grup menjadi `'ended'`. RLS Supabase langsung memutus topic Realtime. Karena Host tidak menyiarkan event penutupan grup sebelum status berubah, anggota rombongan tidak pernah tahu grup telah berakhir.
- **Bukti**:
  ```sql
  -- supabase_schema.sql:444
  WHERE g.id = v_group_id AND g.status = 'active' -- Realtime broadcast ditolak jika status != active
  ```
- **Dampak**: Layar anggota tetap berada di peta, background service terus aktif menguras baterai, dan data riwayat perjalanan anggota tidak pernah tersimpan.
- **Rekomendasi**: Host mengirim event broadcast `'group_ended'` sebelum memanggil `endGroup()`. Pada `MapPage` anggota, dengarkan stream perubahan grup; jika status `'ended'`, hentikan tracking, simpan trip history, dan pop ke Home.
- **Estimasi Usaha**: Sedang

#### [BUG-03] Ketiadaan `PopScope` dan Override Back Button di `MapPage`
- **Severity**: High
- **Lokasi**: [lib/pages/map_page.dart:927-940](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L927-L940)
- **Masalah**: `MapPage` tidak memiliki `PopScope` dan tombol back `AppBar` tidak mengarah ke `_confirmLeave()`.
- **Bukti**:
  ```dart
  appBar: AppBar(title: const Text('Peta & Navigasi Rute')), // Tidak ada leading handler & tidak ada PopScope
  ```
- **Dampak**: Pengguna yang menekan tombol back Android langsung keluar ke Home tanpa mematikan foreground notification dan GPS background service.
- **Rekomendasi**: Bungkus `Scaffold` dengan `PopScope(canPop: false, onPopInvokedWithResult: ...)` dan arahkan `leading: IconButton(onPressed: _confirmLeave)`.
- **Estimasi Usaha**: Kecil

#### [BUG-04] Race Condition Navigasi Deklaratif vs Imperatif Pasca-Login
- **Severity**: High
- **Lokasi**: [lib/app.dart:68-98](file:///d:/Projects/Trackie/lib/app.dart#L68-L98), [lib/pages/login_page.dart:57-75](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L57-L75)
- **Masalah**: `AuthWrapper` bereaksi otomatis terhadap perubahan session (`StreamBuilder`), namun `LoginPage` juga memanggil `Navigator.pushNamedAndRemoveUntil('/home', ...)`.
- **Dampak**: Terjadi perebutan kontrol routing yang dapat menyebabkan dialog login sukses tidak sempat tampil atau menghapus route root `/` dari navigator stack.
- **Rekomendasi**: Pusatkan navigasi root pada `AuthWrapper` secara reaktif berdasarkan state `AuthProvider` & `SubscriptionProvider`.
- **Estimasi Usaha**: Sedang

#### [BUG-05] Data Type Mismatch Kolom `birth_date` (DATE vs Timestamp)
- **Severity**: High
- **Lokasi**: [lib/models/user_model.dart:140](file:///d:/Projects/Trackie/lib/models/user_model.dart#L140), [lib/services/auth_service.dart:73, 90](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L73)
- **Masalah**: Kolom `public.profiles.birth_date` bertipe `DATE` (`YYYY-MM-DD`). Di `UserModel.toSupabase()`, format yang dikirim adalah `birthDate?.toIso8601String()` (`YYYY-MM-DDTHH:mm:ss`). PostgreSQL menolak nilai tersebut dengan error `invalid input syntax for type date`.
- **Bukti**:
  ```dart
  'birth_date': birthDate?.toIso8601String(), // Seharusnya split('T').first
  ```
- **Dampak**: Tanggal lahir profil pengguna baru selalu gagal tersimpan ke database `profiles`.
- **Rekomendasi**: Ubah menjadi `'birth_date': birthDate?.toIso8601String().split('T').first`.
- **Estimasi Usaha**: Kecil

#### [BUG-06] Logout / Hapus Akun Tidak Menghentikan Pelacakan Lokasi
- **Severity**: High
- **Lokasi**: [lib/pages/profile_tab.dart:40-43](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L40-L43), [lib/pages/account_page.dart:340-344](file:///d:/Projects/Trackie/lib/pages/account_page.dart#L340-L344)
- **Masalah**: `AuthProvider.logout()` hanya melakukan sign out Supabase Auth tanpa memanggil `LocationProvider.stopTracking()` dan `BackgroundLocationService.stopTracking()`.
- **Dampak**: Background service tetap aktif memancarkan GPS dengan token lama yang sudah mati, menghabiskan baterai.
- **Rekomendasi**: Panggil `locationProvider.stopTracking()` sebelum sign out.
- **Estimasi Usaha**: Kecil

#### [BUG-07] Silent Failure Inisialisasi Realtime Channel di Background Service
- **Severity**: Medium
- **Lokasi**: [lib/services/background_location_service.dart:147-156](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L147-L156)
- **Masalah**: Jika token terlambat diterima background isolate, listener `updateToken` hanya memanggil `setAuth(token)` tanpa membuat ulang `trackingChannel` jika masih null.
- **Dampak**: Pelacakan latar belakang gagal total secara hening (*silent failure*).
- **Rekomendasi**: Buat helper `_ensureChannel()` yang men-subscribe channel jika token baru masuk.
- **Estimasi Usaha**: Kecil

#### [BUG-08] Overlapping GPS Polling Tanpa Timeout di Background Timer
- **Severity**: Medium
- **Lokasi**: [lib/services/background_location_service.dart:202-211](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L202-L211)
- **Masalah**: `Geolocator.getCurrentPosition` dipanggil tiap 5 detik tanpa `timeLimit`. Di area minim GPS, request dapat memakan waktu >10 detik, memicu tumpukan request paralel.
- **Dampak**: Keborosan baterai dan potensi exception limit dari OS.
- **Rekomendasi**: Pasang flag `_isFetchingLocation` atau set `timeLimit: const Duration(seconds: 4)`.
- **Estimasi Usaha**: Kecil

#### [BUG-09] Tombol SOS Searah (Tanpa Cancel) & Peringatan Tersembunyi
- **Severity**: Medium
- **Lokasi**: [lib/pages/map_page.dart:854-915, 1010-1020](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L854-L915)
- **Masalah**: Tombol SOS di UI tidak bisa dibatalkan jika salah tekan, dan sinyal SOS anggota lain hanya berupa badge kecil di dalam sheet yang terlipat.
- **Dampak**: Salah tekan tidak dapat dikoreksi; bahaya darurat di jalan berisiko tidak disadari rombongan.
- **Rekomendasi**: Buat tombol SOS menjadi toggle (Aktifkan / Batalkan), dan munculkan banner darurat merah menyala di atas peta jika ada rekan yang SOS.
- **Estimasi Usaha**: Sedang

#### [BUG-10] Ketiadaan Penanganan Error pada Stream Riwayat Perjalanan
- **Severity**: Medium
- **Lokasi**: [lib/pages/history_tab.dart:113-168](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L113-L168)
- **Masalah**: `StreamBuilder` di `HistoryTab` tidak mengecek `snapshot.hasError`. Saat offline, `snapshot.data` bernilai null dan dianggap list kosong.
- **Dampak**: Pengguna mengira riwayat perjalanannya terhapus saat koneksi hilang.
- **Rekomendasi**: Tampilkan pesan offline dan tombol coba lagi jika `snapshot.hasError`.
- **Estimasi Usaha**: Kecil

#### [BUG-11] `GroupModel` Mengabaikan Kolom `destination` & `memberUids` pada `operator ==`
- **Severity**: Medium
- **Lokasi**: [lib/models/group_model.dart:175-198](file:///d:/Projects/Trackie/lib/models/group_model.dart#L175-L198)
- **Masalah**: Perbandingan kesetaraan objek `GroupModel` tidak menyertakan `destination` dan `memberUids`.
- **Dampak**: Widget UI yang mengandalkan perbandingan nilai objek tidak me-rebuild saat tujuan diubah atau anggota bertambah.
- **Rekomendasi**: Sertakan `destination` dan `listEquals(memberUids, other.memberUids)` di `operator ==` dan `hashCode`.
- **Estimasi Usaha**: Kecil

#### [BUG-12] Potensi Crash Bounds Zoom Nol pada Riwayat Trip Singkat
- **Severity**: Medium
- **Lokasi**: [lib/pages/trip_detail_page.dart:374-379](file:///d:/Projects/Trackie/lib/pages/trip_detail_page.dart#L374-L379)
- **Masalah**: `CameraFit.bounds` dipanggil jika `points.length >= 2`. Jika seluruh koordinat bernilai sama persis (trip 0 meter), bounding box berdimensi 0 dapat memicu assertion crash di `flutter_map`.
- **Dampak**: Halaman detail trip uji coba/singkat crash saat dibuka.
- **Rekomendasi**: Validasi `hasDistinctPoints` sebelum menyetel bounds fit.
- **Estimasi Usaha**: Kecil

#### [BUG-13] Dead Code Dialog Edukasi Izin Lokasi Permanen
- **Severity**: Low
- **Lokasi**: [lib/services/permission_service.dart:81](file:///d:/Projects/Trackie/lib/services/permission_service.dart#L81), [lib/pages/map_page.dart:124-138](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L124-L138)
- **Masalah**: `PermissionService.showPermissionDeniedDialog` tidak pernah dipanggil saat izin ditolak permanen.
- **Dampak**: Pengguna yang menolak izin tidak diberi tahu cara membuka izin di Pengaturan OS.
- **Rekomendasi**: Panggil dialog edukasi jika status izin `isPermanentlyDenied`.
- **Estimasi Usaha**: Kecil

#### [BUG-14] Penggunaan Operator `!` Lintas Async Gap di `AuthProvider`
- **Severity**: Low
- **Lokasi**: [lib/providers/auth_provider.dart:178-183](file:///d:/Projects/Trackie/lib/providers/auth_provider.dart#L178-L183)
- **Masalah**: Memanggil `_user!.uid` setelah `await uploadProfilePicture`. Jika user sign out saat upload berlangsung, memicu Null Pointer exception.
- **Dampak**: Crash acak pada koneksi lambat saat pengguna keluar aplikasi.
- **Rekomendasi**: Simpan `final currentUser = _user; if (currentUser == null) return false;` sebelum pemanggilan async.
- **Estimasi Usaha**: Kecil

#### [BUG-15] Data Dummy Statis Upcoming Trips di Halaman Home
- **Severity**: Info
- **Lokasi**: [lib/pages/home_tab.dart:670-691](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L670-L691)
- **Masalah**: Daftar jadwal trip mendatang di-hardcode di dalam widget tree, belum terhubung ke database.
- **Rekomendasi**: Hubungkan ke kueri database Supabase atau sembunyikan jika belum diimplementasikan.
- **Estimasi Usaha**: Sedang

---

### B. PERFORMANCE & EFISIENSI

#### [PERF-01] Duplikasi Pelacakan GPS & Broadcast WebSocket Bersamaan (Foreground + Background)
- **Severity**: Critical
- **Lokasi**: [lib/providers/location_provider.dart:314](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L314), [lib/services/background_location_service.dart:200](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L200)
- **Masalah**: Saat `MapPage` terbuka, main isolate menjalankan stream GPS dan mengirim broadcast lokasi. Di saat yang sama, background isolate service tetap menyalakan polling timer 5 detik dan mengirim broadcast kedua.
- **Dampak**: Pemborosan daya baterai ganda dan penggandaan traffic jaringan WebSocket Supabase.
- **Rekomendasi**: Pause timer background isolate saat aplikasi berada di foreground, aktifkan HANYA saat aplikasi beralih ke background/paused.
- **Estimasi Usaha**: Sedang

#### [PERF-02] Rebuild Keseluruhan Pohon Widget `MapPage` pada Setiap Koordinat Baru
- **Severity**: High
- **Lokasi**: [lib/pages/map_page.dart:172-180, 921-923](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L172-L180)
- **Masalah**: `context.watch<LocationProvider>()` diletakkan di root `build()`. Setiap pergeseran koordinat 5 meter merebuild seluruh `FlutterMap`, `TileLayer`, dan `DraggableScrollableSheet`. Di samping itu, terdapat mutasi state dan `addPostFrameCallback` di dalam fungsi `_resolveMembers` yang dipanggil saat `build`.
- **Dampak**: Frame drop parah (jank/stutter) pada perangkat Android saat touring berlangsung.
- **Rekomendasi**: Pisahkan marker layer ke widget terpisah dengan `Selector`, dan pindahkan initial centering kamera ke listener `initState`.
- **Estimasi Usaha**: Sedang

#### [PERF-03] Instansiasi Stream Supabase di Dalam Method `build()` `HistoryTab`
- **Severity**: High
- **Lokasi**: [lib/pages/history_tab.dart:113-115](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L113-L115)
- **Masalah**: `StreamBuilder(stream: _tripService.streamTripHistory(uid))` membuat instance Stream baru setiap kali tab dirender ulang.
- **Dampak**: Koneksi WebSocket berkedip (churning), pembatalan dan koneksi ulang terus-menerus, memboroskan kuota dan batas koneksi Supabase.
- **Rekomendasi**: Inisialisasi stream satu kali di `initState()` atau simpan di provider.
- **Estimasi Usaha**: Kecil

#### [PERF-04] Ketiadaan Throttling pada Kecepatan Tinggi & `distanceFilter` Bisu di Background
- **Severity**: High
- **Lokasi**: [lib/providers/location_provider.dart:314](file:///d:/Projects/Trackie/lib/providers/location_provider.dart#L314), [lib/services/background_location_service.dart:206](file:///d:/Projects/Trackie/lib/services/background_location_service.dart#L206)
- **Masalah**: Kecepatan 60 km/jam memicu `distanceFilter: 5` lebih dari 3 kali per detik. Di background isolate, `getCurrentPosition` mengabaikan `distanceFilter` sehingga GPS tetap dipolling saat motor berhenti/macet.
- **Dampak**: Banjir pesan (30+ pesan/detik untuk 10 anggota) dan baterai cepat habis.
- **Rekomendasi**: Berikan throttling minimal 2–3 detik di foreground, dan bandingkan pergeseran koordinat via Haversine sebelum broadcast di background.
- **Estimasi Usaha**: Kecil

#### [PERF-05] Query Riwayat Mengunduh Seluruh Array JSONB `route_path` untuk List View
- **Severity**: Medium
- **Lokasi**: [lib/services/trip_service.dart:41-50](file:///d:/Projects/Trackie/lib/services/trip_service.dart#L41-L50)
- **Masalah**: List view ringkasan riwayat mengunduh seluruh kolom `route_path` yang berisi ratusan titik GPS dan mem-parsingnya ke memori.
- **Dampak**: Payload jaringan membengkak puluhan MB seiring bertambahnya riwayat perjalanan user.
- **Rekomendasi**: Kecualikan kolom `route_path` pada query list, unduh hanya saat membuka `TripDetailPage`.
- **Estimasi Usaha**: Sedang

#### [PERF-06] Ketiadaan GIN Index pada Kolom Array `public.groups.member_uids`
- **Severity**: Medium
- **Lokasi**: [supabase_schema.sql:106, 117-118](file:///d:/Projects/Trackie/supabase_schema.sql#L106)
- **Masalah**: Kueri `.contains('member_uids', [uid])` dan evaluasi RLS berjalan tanpa indeks array PostgreSQL.
- **Dampak**: Full table scan pada tabel `groups` seiring bertambahnya data grup di server.
- **Rekomendasi**: Pasang indeks GIN: `CREATE INDEX idx_groups_member_uids ON public.groups USING gin (member_uids);`.
- **Estimasi Usaha**: Kecil

#### [PERF-07] Penggunaan `context.watch` Berlebihan pada Root Widget Tree
- **Severity**: Medium
- **Lokasi**: [lib/pages/home_tab.dart:659](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L659), [lib/pages/history_tab.dart:77](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L77), [lib/app.dart:74](file:///d:/Projects/Trackie/lib/app.dart#L74)
- **Masalah**: Seluruh layar di-rebuild padahal widget hanya memerlukan properti spesifik.
- **Rekomendasi**: Ganti dengan `context.select` atau `Selector`.
- **Estimasi Usaha**: Kecil

#### [PERF-08] Pembuangan Resource Controller Berbasis `Future.delayed(400ms)`
- **Severity**: Medium
- **Lokasi**: [lib/pages/home_tab.dart:503-509](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L503-L509)
- **Masalah**: Controller modal bottom sheet di-dispose menggunakan timer delay manual.
- **Dampak**: Risiko `TextEditingController was used after being disposed` jika animasi modal terhambat.
- **Rekomendasi**: Ekstrak isi modal ke `StatefulWidget` tersendiri dengan `dispose()` deterministik.
- **Estimasi Usaha**: Kecil

#### [PERF-09] Navigasi Tab Bottom Bar Menghancurkan State Layar
- **Severity**: Medium
- **Lokasi**: [lib/pages/main_page.dart:45](file:///d:/Projects/Trackie/lib/pages/main_page.dart#L45)
- **Masalah**: `body: _tabs[_selectedIndex]` me-mount dan me-unmount widget tab setiap kali berpindah tab.
- **Dampak**: Posisi scroll hilang dan query dipicu ulang.
- **Rekomendasi**: Gunakan `IndexedStack(index: _selectedIndex, children: _tabs)`.
- **Estimasi Usaha**: Kecil

#### [PERF-10] Penggunaan `NetworkImage` Mentah Tanpa Caching di Halaman Home
- **Severity**: Low
- **Lokasi**: [lib/pages/home_tab.dart:801-806](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L801-L806)
- **Masalah**: Foto profil di `HomeTab` tidak menggunakan disk cache.
- **Rekomendasi**: Ganti dengan `CachedNetworkImageProvider`.
- **Estimasi Usaha**: Kecil

#### [PERF-11] Penghitungan Kuota Grup Mengunduh Seluruh Baris Data ke Memori
- **Severity**: Low
- **Lokasi**: [lib/services/group_service.dart:24-35](file:///d:/Projects/Trackie/lib/services/group_service.dart#L24-L35)
- **Masalah**: Menghitung kuota grup dengan menarik array row ID lalu memanggil `.length` di Dart.
- **Rekomendasi**: Gunakan PostgREST aggregation `.count(CountOption.exact)`.
- **Estimasi Usaha**: Kecil

#### [PERF-12] Format Aset Gambar Onboarding Masih JPEG/PNG (~1.46 MB)
- **Severity**: Low
- **Lokasi**: `assets/images/`
- **Masalah**: Aset gambar onboarding berukuran total ~1.46 MB.
- **Rekomendasi**: Konversi ke `.webp` kualitas 80% untuk memangkas ukuran APK hingga ~1 MB.
- **Estimasi Usaha**: Kecil

---

### C. SECURITY (SISI APLIKASI & OTORISASI)

#### [SEC-01 / BACK-01] Privilege Escalation ke Paket Premium via RLS Update Policy
- **Severity**: Critical
- **Lokasi**: [supabase_schema.sql:221-223](file:///d:/Projects/Trackie/supabase_schema.sql#L221-L223), [lib/services/subscription_service.dart:271](file:///d:/Projects/Trackie/lib/services/subscription_service.dart#L271)
- **Masalah**: Policy `profiles_update_own` tidak membatasi kolom. Pengguna gratis dapat mengirim request `PATCH /rest/v1/profiles` berisi `{"plan": "premium", "subscription_status": "active"}`.
- **Dampak**: Bypass total sistem pembayaran/monetisasi aplikasi; kuota grup langsung terbuka menjadi 20 grup tanpa verifikasi store.
- **Rekomendasi**: Cabut izin UPDATE kolom langganan: `REVOKE UPDATE (plan, subscription_status, subscription_expires_at) ON public.profiles FROM authenticated;`, dan kendalikan status paket eksklusif via Database Webhook / Edge Function ber-role `service_role`.
- **Estimasi Usaha**: Sedang

#### [SEC-02] Token Sesi JWT Disimpan Tanpa Enkripsi di SharedPreferences
- **Severity**: Medium
- **Lokasi**: [lib/main.dart:27-30](file:///d:/Projects/Trackie/lib/main.dart#L27-L30), [pubspec.yaml:54](file:///d:/Projects/Trackie/pubspec.yaml#L54)
- **Masalah**: Default storage Supabase menyimpan token sesi ke dalam file XML teks biasa di `/data/data/.../shared_prefs/`.
- **Dampak**: Token sesi dapat diekstrak oleh penyerang pada perangkat yang di-root atau via backup ADB.
- **Rekomendasi**: Gunakan `flutter_secure_storage` sebagai custom `localStorage` pada `Supabase.initialize()`.
- **Estimasi Usaha**: Kecil

#### [SEC-03] `android:allowBackup` Tidak Didefinisikan (Default `true`)
- **Severity**: Medium
- **Lokasi**: [android/app/src/main/AndroidManifest.xml:17-20](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml#L17-L20)
- **Masalah**: Atribut `android:allowBackup` tidak diset secara eksplisit.
- **Dampak**: Seluruh data lokal dan token sesi dapat diekstrak via kabel USB melalui perintah `adb backup`.
- **Rekomendasi**: Tambahkan atribut `android:allowBackup="false"` di elemen `<application>`.
- **Estimasi Usaha**: Kecil

#### [SEC-04] Tipe Build `release` Ditandatangani Menggunakan Kunci Debug Publik
- **Severity**: Medium
- **Lokasi**: [android/app/build.gradle.kts:38](file:///d:/Projects/Trackie/android/app/build.gradle.kts#L38)
- **Masalah**: `signingConfig = signingConfigs.getByName("debug")` pada build release.
- **Dampak**: Build rilis rentan di-repackage dan Google Play Console menolak upload AAB ber-signature debug.
- **Rekomendasi**: Konfigurasi `key.properties` privat untuk rilis produksi.
- **Estimasi Usaha**: Kecil

#### [SEC-05 / DEP-07] Hilangnya Deskripsi Izin Privasi Galeri/Kamera di iOS
- **Severity**: High
- **Lokasi**: [ios/Runner/Info.plist:1-86](file:///d:/Projects/Trackie/ios/Runner/Info.plist), [lib/pages/profile_tab.dart:54](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L54)
- **Masalah**: Kunci `NSPhotoLibraryUsageDescription` dan `NSCameraUsageDescription` tidak ada di `Info.plist`.
- **Dampak**: Crash seketika (SIGABRT) saat memilih avatar di iPhone & penolakan otomatis App Store.
- **Rekomendasi**: Tambahkan string deskripsi izin galeri dan kamera di `Info.plist`.
- **Estimasi Usaha**: Kecil

#### [SEC-06] Ketiadaan Skema Deep Link untuk Redirect Reset Password
- **Severity**: Low
- **Lokasi**: [android/app/src/main/AndroidManifest.xml:21-42](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml#L21-L42), [lib/services/auth_service.dart:196](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L196)
- **Masalah**: Tautan email reset password tidak memiliki custom scheme callback ke aplikasi.
- **Dampak**: Pengguna dialihkan ke peramban web eksternal yang tidak dapat menyelesaikan pembaruan kata sandi di aplikasi.
- **Rekomendasi**: Daftarkan URL scheme (mis. `trackie://reset-password`).
- **Estimasi Usaha**: Sedang

#### [SEC-07] Service Background Tracking Belum Dideklarasikan `exported="false"`
- **Severity**: Low
- **Lokasi**: [android/app/src/main/AndroidManifest.xml:51-54](file:///d:/Projects/Trackie/android/app/src/main/AndroidManifest.xml#L51-L54)
- **Masalah**: Ketiadaan atribut eksplisit `android:exported="false"` pada service background.
- **Rekomendasi**: Tambahkan `android:exported="false"` secara tegas.
- **Estimasi Usaha**: Kecil

#### [SEC-08 / DEP-06] Facebook Auth Native Config Nihil
- **Severity**: Critical
- **Lokasi**: [pubspec.yaml:59](file:///d:/Projects/Trackie/pubspec.yaml#L59), [lib/pages/login_page.dart:366](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L366)
- **Masalah**: Tombol Facebook Login aktif di UI tanpa konfigurasi native di Android/iOS -> Crash seketika saat ditekan.
- **Rekomendasi**: Hapus plugin dan sembunyikan tombol jika belum dipakai, atau lengkapi ID Meta Developer di manifest.
- **Estimasi Usaha**: Kecil

#### [SEC-09] Kebijakan Kompleksitas Kata Sandi Terlalu Lemah & Tanpa Konfirmasi
- **Severity**: Low
- **Lokasi**: [lib/pages/signup_page.dart:301-305](file:///d:/Projects/Trackie/lib/pages/signup_page.dart#L301-L305)
- **Masalah**: Validasi hanya mengecek panjang minimal 6 karakter tanpa kombinasi karakter dan tanpa field konfirmasi kata sandi.
- **Rekomendasi**: Standarisasi minimal 8 karakter dengan kombinasi angka dan sediakan field konfirmasi kata sandi.
- **Estimasi Usaha**: Kecil

#### [SEC-10] Default Anon Key Tersedia di Source Code Lokal
- **Severity**: Info
- **Lokasi**: [lib/supabase_config.dart:16-24](file:///d:/Projects/Trackie/lib/supabase_config.dart#L16-L24)
- **Masalah**: Anon key dan URL project tertanam sebagai fallback default di file Dart.
- **Rekomendasi**: Gunakan `--dart-define` secara eksklusif untuk build rilis.
- **Estimasi Usaha**: Kecil

---

### D. BACKEND, DATA & PRIVASI

#### [BACK-02] Injeksi Status Paket Premium Saat Registrasi Akun
- **Severity**: High
- **Lokasi**: [supabase_schema.sql:68-70](file:///d:/Projects/Trackie/supabase_schema.sql#L68-L70)
- **Masalah**: Trigger `handle_new_user` membaca `raw_user_meta_data->>'plan'` yang dikirim oleh klien.
- **Dampak**: Penyerang dapat mendaftarkan akun baru langsung berstatus Premium aktif.
- **Rekomendasi**: Kunci nilai default pada trigger pendaftaran selalu bernilai `'free'`.
- **Estimasi Usaha**: Kecil

#### [BACK-03] Akun Zombie & File Avatar Orphan Saat Penghapusan Akun
- **Severity**: High
- **Lokasi**: [supabase_schema.sql:350-369](file:///d:/Projects/Trackie/supabase_schema.sql#L350-L369), [lib/services/auth_service.dart:285](file:///d:/Projects/Trackie/lib/services/auth_service.dart#L285)
- **Masalah**: Penghapusan avatar mengandalkan client sebelum memanggil RPC; kegagalan jaringan membuat avatar tersimpan selamanya. Jika user adalah host grup aktif, grup ditinggalkan tanpa host baru.
- **Rekomendasi**: Alihkan kepemilikan host di RPC dan gunakan Database Webhook untuk menghapus storage.
- **Estimasi Usaha**: Sedang

#### [BACK-04] Penghitungan Kuota Grup Menyertakan Grup yang Telah Selesai (`ended`)
- **Severity**: Medium
- **Lokasi**: [supabase_schema.sql:155-160](file:///d:/Projects/Trackie/supabase_schema.sql#L155-L160)
- **Masalah**: `can_create_or_join_group` menghitung seluruh baris grup di mana user terdaftar tanpa filter `status = 'active'`.
- **Dampak**: Pengguna Free yang sudah menyelesaikan 2 kali touring terkunci permanen dan tidak bisa membuat grup baru lagi.
- **Rekomendasi**: Tambahkan filter `WHERE g.status = 'active' AND p_uid::text = ANY (g.member_uids)`.
- **Estimasi Usaha**: Kecil

#### [BACK-05] Host Dapat Memanipulasi `member_uids` Secara Sepihak di Luar RPC
- **Severity**: Medium
- **Lokasi**: [supabase_schema.sql:245-248](file:///d:/Projects/Trackie/supabase_schema.sql#L245-L248)
- **Masalah**: Policy `groups_update_as_host` tidak membatasi kolom yang boleh diupdate.
- **Dampak**: Host dapat menginjeksi UID user lain tanpa izin.
- **Rekomendasi**: Kunci manipulasi `member_uids` hanya melalui fungsi RPC `join_group` & `leave_group`.
- **Estimasi Usaha**: Sedang

#### [BACK-06] Concurrency Race Condition pada Pembuatan Grup
- **Severity**: Medium
- **Lokasi**: [supabase_schema.sql:235-243](file:///d:/Projects/Trackie/supabase_schema.sql#L235-L243)
- **Masalah**: Kueri `SELECT count(*)` pada isolasi transaksi Read Committed rentan terhadap request insert paralel.
- **Rekomendasi**: Pasang advisory lock berbasis user ID: `PERFORM pg_advisory_xact_lock(hashtext(p_uid::text));`.
- **Estimasi Usaha**: Sedang

#### [BACK-07] Ghost Mode Hanya Berupa Placebo UI (Pelanggaran Kebijakan Privasi)
- **Severity**: High
- **Lokasi**: [lib/pages/profile_tab.dart:280-290](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L280-L290), [lib/pages/privacy_policy_page.dart:79](file:///d:/Projects/Trackie/lib/pages/privacy_policy_page.dart#L79)
- **Masalah**: Toggle Ghost Mode hanya mengubah variabel lokal di tab profil dan tidak pernah diteruskan ke service pelacakan lokasi.
- **Dampak**: Pengguna mengira lokasinya tersembunyi, padahal koordinat GPS tetap dipancarkan ke seluruh anggota grup. Ini adalah pelanggaran privasi serius (UU PDP / Google Play Privacy Policy).
- **Rekomendasi**: Hubungkan status Ghost Mode ke `LocationProvider` dan hentikan transmisi koordinat saat aktif.
- **Estimasi Usaha**: Sedang

#### [BACK-08] Ketiadaan Kebijakan Retensi Data & Opsi Hapus Riwayat Personal
- **Severity**: Medium
- **Lokasi**: [supabase_schema.sql:168-181](file:///d:/Projects/Trackie/supabase_schema.sql#L168-L181), [lib/services/trip_service.dart:1-71](file:///d:/Projects/Trackie/lib/services/trip_service.dart#L1-L71)
- **Masalah**: Jejak koordinat GPS disimpan permanen dan pengguna tidak memiliki tombol untuk menghapus data riwayat touring individunya.
- **Rekomendasi**: Tambahkan method `deleteTrip` pada `TripService` dan sediakan tombol hapus di UI.
- **Estimasi Usaha**: Sedang

#### [BACK-09] Potensi Pemalsuan Lokasi Antar-Anggota dalam Grup yang Sama
- **Severity**: Low
- **Lokasi**: [lib/services/location_service.dart:146-149](file:///d:/Projects/Trackie/lib/services/location_service.dart#L146-L149)
- **Masalah**: Broadcast payload tidak memverifikasi kecocokan `uid` pengirim dengan user ID token di channel.
- **Rekomendasi**: Validasi kesesuaian UID pengirim atau gunakan Supabase Realtime Presence.
- **Estimasi Usaha**: Sedang

#### [BACK-10] Ekstensi PostGIS Terpasang Tanpa Pemanfaatan Kolom Geometri
- **Severity**: Info
- **Lokasi**: [supabase_schema.sql:8, 175](file:///d:/Projects/Trackie/supabase_schema.sql#L8)
- **Masalah**: PostGIS aktif di database tetapi koordinat disimpan sebagai teks JSONB biasa.
- **Rekomendasi**: Gunakan tipe `geography(LineString, 4326)` jika ingin memanfaatkan query spasial performa tinggi, atau hapus ekstensi jika tidak diperlukan.
- **Estimasi Usaha**: Kecil

---

### E. DEPENDENCY & SUPPLY CHAIN

#### [DEP-01] Dependensi Mati / Tidak Digunakan: `uuid: ^4.5.1`
- **Severity**: Low
- **Lokasi**: [pubspec.yaml:44](file:///d:/Projects/Trackie/pubspec.yaml#L44)
- **Masalah**: Paket didaftarkan tetapi tidak diimport sama sekali di seluruh kode `lib/`.
- **Rekomendasi**: Hapus dari `pubspec.yaml`.
- **Estimasi Usaha**: Kecil

#### [DEP-02] Dependensi Font Tidak Digunakan: `cupertino_icons: ^1.0.8`
- **Severity**: Low
- **Lokasi**: [pubspec.yaml:36](file:///d:/Projects/Trackie/pubspec.yaml#L36)
- **Masalah**: Aplikasi menggunakan Material Icons secara konsisten; font CupertinoIcons (~280 KB) terbuang percuma di bundle.
- **Rekomendasi**: Hapus dari `pubspec.yaml`.
- **Estimasi Usaha**: Kecil

#### [DEP-03] `flutter_local_notifications` Tertinggal 4 Versi Mayor (v18 -> v22)
- **Severity**: High
- **Lokasi**: [pubspec.yaml:48](file:///d:/Projects/Trackie/pubspec.yaml#L48)
- **Masalah**: Versi 18.0.1 tertinggal jauh dari versi stabil 22.3.2.
- **Dampak**: Isu ketidakcocokan foreground service notification pada Android 14/15.
- **Rekomendasi**: Upgrade ke `^22.3.2`.
- **Estimasi Usaha**: Sedang

#### [DEP-04] Pinning Versi Lawas `google_sign_in: 6.2.1` (Latest 7.2.0)
- **Severity**: Medium
- **Lokasi**: [pubspec.yaml:58](file:///d:/Projects/Trackie/pubspec.yaml#L58)
- **Masalah**: Di-pin tanpa caret `^` pada versi 6.x.
- **Rekomendasi**: Upgrade ke `^7.2.0` (dukungan Android Credential Manager).
- **Estimasi Usaha**: Sedang

#### [DEP-05] `permission_handler` Tertinggal 2 Versi Mayor (v11 -> v13)
- **Severity**: Medium
- **Lokasi**: [pubspec.yaml:49](file:///d:/Projects/Trackie/pubspec.yaml#L49)
- **Masalah**: Versi 11 tertinggal dari versi 13.0.2.
- **Rekomendasi**: Upgrade ke `^13.0.2`.
- **Estimasi Usaha**: Kecil

#### [DEP-08] Missing OAuth URL Scheme di iOS `Info.plist` untuk Google Sign-In
- **Severity**: Medium
- **Lokasi**: [ios/Runner/Info.plist:1-86](file:///d:/Projects/Trackie/ios/Runner/Info.plist)
- **Masalah**: Tidak ada konfigurasi callback `CFBundleURLTypes` untuk redirect Google Sign-In di iPhone.
- **Rekomendasi**: Daftarkan reversed client ID di `Info.plist`.
- **Estimasi Usaha**: Kecil

#### [DEP-09] Penggunaan Default Boilerplate ID Android `com.example.trackie`
- **Severity**: Medium
- **Lokasi**: [android/app/build.gradle.kts:21](file:///d:/Projects/Trackie/android/app/build.gradle.kts#L21)
- **Masalah**: `applicationId` masih menggunakan domain contoh.
- **Dampak**: Ditolak saat pendaftaran di Google Play Console.
- **Rekomendasi**: Ganti ke package name resmi (mis. `id.trackie.app`).
- **Estimasi Usaha**: Kecil

#### [DEP-10] Berkas `ios/Podfile` Belum Di-commit ke Git
- **Severity**: Info
- **Lokasi**: Direktori `ios/`
- **Rekomendasi**: Generate dan commit `Podfile` dengan deployment target iOS 15.0.
- **Estimasi Usaha**: Kecil

#### [DEP-11] Transitive Dependency `archive: 4.3.0` Terkunci di Bawah 4.5.2
- **Severity**: Info
- **Lokasi**: [pubspec.lock:44](file:///d:/Projects/Trackie/pubspec.lock#L44)
- **Rekomendasi**: Jalankan `flutter pub upgrade`.
- **Estimasi Usaha**: Kecil

---

### F. ARSITEKTUR & KUALITAS KODE

#### [ARCH-01] Kebocoran Abstraksi Layer (Presentation Memanggil Service Langsung)
- **Severity**: High
- **Lokasi**: [history_tab.dart:72](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L72), [home_tab.dart:24](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L24), [map_page.dart:94, 824](file:///d:/Projects/Trackie/lib/pages/map_page.dart#L94), [app.dart:67](file:///d:/Projects/Trackie/lib/app.dart#L67)
- **Masalah**: UI menginstansiasi concrete service secara mandiri (`TripService()`, `RoutingService()`, `SupabaseConfig.client.auth`) melompati state management.
- **Dampak**: State terpecah dan pengujian UI independen menjadi mustahil.
- **Rekomendasi**: Buat `TripProvider` dan bungkus pemanggilan service melalui Provider.
- **Estimasi Usaha**: Sedang

#### [ARCH-02] God Classes & Massive View Files (>1.000 Baris)
- **Severity**: High
- **Lokasi**:
  - `lib/pages/subscription_page.dart` (1.486 baris)
  - `lib/pages/map_page.dart` (1.472 baris)
  - `lib/pages/home_tab.dart` (1.236 baris)
  - `lib/providers/location_provider.dart` (673 baris)
- **Masalah**: Pelanggaran berat Single Responsibility Principle (SRP); logika navigasi, modal bottom sheet ratusan baris, downsampling koordinat, dan rendering peta bercampur dalam satu class raksasa.
- **Rekomendasi**: Dekomposisi modal sheet dan layer peta ke dalam sub-widget terpisah di `lib/widgets/`.
- **Estimasi Usaha**: Besar

#### [ARCH-03] Ketiadaan Dependency Injection & Tight Coupling Instansiasi Service
- **Severity**: High
- **Lokasi**: `lib/providers/auth_provider.dart:17`, `lib/providers/group_provider.dart:6`, `lib/providers/location_provider.dart:27`
- **Masalah**: Seluruh provider menginstansiasi concrete service secara hardcoded tanpa constructor parameter.
- **Rekomendasi**: Terapkan constructor injection opsional (seperti yang sudah dilakukan pada `SubscriptionProvider`).
- **Estimasi Usaha**: Sedang

#### [ARCH-04] Inkonsistensi Typography System-Wide (Bypass Terhadap AppTheme)
- **Severity**: Medium
- **Lokasi**: `lib/theme/app_theme.dart:29` vs hampir seluruh halaman UI
- **Masalah**: `AppTheme` mendefinisikan font Public Sans, tetapi widget UI mem-bypass dengan memanggil langsung `GoogleFonts.urbanist(...)` di ratusan tempat.
- **Rekomendasi**: Selaraskan typography di `AppTheme` dan gunakan `Theme.of(context).textTheme`.
- **Estimasi Usaha**: Sedang

#### [ARCH-05] Fitur Dark Mode Rusak Akibat Puluhan Hardcoded Colors
- **Severity**: High
- **Lokasi**: [login_page.dart:233](file:///d:/Projects/Trackie/lib/pages/login_page.dart#L233), [signup_page.dart:125](file:///d:/Projects/Trackie/lib/pages/signup_page.dart#L125), [history_tab.dart:91](file:///d:/Projects/Trackie/lib/pages/history_tab.dart#L91), [profile_tab.dart:175](file:///d:/Projects/Trackie/lib/pages/profile_tab.dart#L175)
- **Masalah**: Meng-hardcode warna terang (`Colors.white`, `const Color(0xFFF7F7FA)`, `const Color(0xFF1A1A2E)`).
- **Dampak**: Saat Dark Mode diaktifkan, layar tetap putih menyilaukan dan kontras teks rusak.
- **Rekomendasi**: Ganti dengan semantik `Theme.of(context).colorScheme.surface` dan `onSurface`.
- **Estimasi Usaha**: Sedang

#### [ARCH-06] Duplikasi Komponen Antarmuka yang Tersebar
- **Severity**: Medium
- **Lokasi**: Pencarian tempat (Nominatim) di `home_tab.dart` vs `map_page.dart`, card riwayat di `history_tab.dart` vs `home_tab.dart`.
- **Rekomendasi**: Ekstrak menjadi shared widget (`PlaceSearchModal`).
- **Estimasi Usaha**: Sedang

#### [ARCH-07] Pola Error Handling & User Feedback Terfragmentasi
- **Severity**: Medium
- **Lokasi**: `login_page.dart`, `home_tab.dart`, `map_page.dart:824-827`
- **Masalah**: Sebagian menggunakan custom dialog, sebagian SnackBar, dan penyimpanan trip gagal ditelan secara silent (`debugPrint` saja).
- **Rekomendasi**: Satukan utilitas notifikasi dan beri notifikasi yang bisa di-retry saat gagal menyimpan trip.
- **Estimasi Usaha**: Kecil

#### [ARCH-08] Delimited String Packing Hack (`Nama||lat,lng`)
- **Severity**: Medium
- **Lokasi**: `lib/services/routing_service.dart:149`, `lib/models/trip_history_model.dart:53`
- **Masalah**: Menggabungkan data terstruktur ke satu kolom string dengan delimiter `||`.
- **Rekomendasi**: Buat kolom terpisah di tabel PostgreSQL (`destination_lat`, `destination_lng`).
- **Estimasi Usaha**: Sedang

#### [ARCH-09] Ketidaklengkapan Adopsi Lokalisasi (l10n)
- **Severity**: Low
- **Lokasi**: `lib/l10n/` vs hardcoded text di halaman-halaman utama.
- **Rekomendasi**: Ekstrak seluruh teks user-facing ke `app_id.arb` dan `app_en.arb`.
- **Estimasi Usaha**: Sedang

#### [ARCH-10] Mock Data Tertanam di Production Widget Tree
- **Severity**: Low
- **Lokasi**: [lib/pages/home_tab.dart:670](file:///d:/Projects/Trackie/lib/pages/home_tab.dart#L670)
- **Rekomendasi**: Pindahkan data mock ke mock service terpisah.
- **Estimasi Usaha**: Kecil

---

## 5. HAL YANG SUDAH BAIK / BEST PRACTICES (JANGAN DIUBAH)

1. **Zero Database Write Tracking Architecture**:
   Pelacakan posisi rombongan dan sinyal SOS sepenuhnya menggunakan WebSocket Supabase Realtime Broadcast tanpa menulis jutaan koordinat GPS ke disk database. Ini adalah keputusan arsitektur yang sangat tepat dan hemat biaya.
2. **Private Realtime Channel Authorization**:
   Topic `group_tracking:<group_id>` dipagari oleh Row Level Security `realtime.messages` dan fungsi verifikasi keanggotaan `can_access_tracking_topic`. Non-anggota grup tidak dapat mengintip lokasi rombongan.
3. **Hardened PostgreSQL Stored Functions**:
   Seluruh fungsi `SECURITY DEFINER` di `supabase_schema.sql` menetapkan `SET search_path = ''` dan mengkualifikasikan skema `public.`, mencegah serangan *Search Path Hijacking*.
4. **Isolasi Supabase Storage Bucket**:
   Bucket `avatars` membatasi ukuran maksimal 5 MB, membatasi whitelist MIME type (`jpeg`, `png`, `webp`), dan membatasi manipulasi hanya pada folder UID pemiliknya sendiri.
5. **Kalkulasi Matematis Haversine Baku**:
   Implementasi jarak di `HaversineUtils` menggunakan radius bumi 6371.0 km dan formula trigonometri yang akurat.
6. **Downsampling Jejak Rute GPS**:
   Sebelum disimpan ke riwayat perjalanan, jejak koordinat di-subsample secara otomatis menjadi maksimal 80 titik representatif, mencegah pembengkakan kolom JSONB.
7. **Pembersihan Log Sensitif**:
   Tidak ada fungsi `print()` mentah di codebase `lib/`. Seluruh logging menggunakan `debugPrint()` tanpa mencetak koordinat presisi atau token autentikasi.
8. **Enkapsulasi Network Terenkripsi**:
   Seluruh panggilan eksternal (Supabase, OSRM, Nominatim) menggunakan HTTPS murni tanpa bypass sertifikat SSL.

---

## 6. ROADMAP PERBAIKAN BERDASARKAN PRIORITAS

### Fase 1: Perbaiki Sekarang (Critical & High — Release Blockers)
- [ ] **Kunci Kolom Langganan (SEC-01 / BACK-01)**: Cabut hak UPDATE kolom `plan` dan `subscription_status` dari role `authenticated`.
- [ ] **Hapus / Konfigurasi Facebook Auth (DEP-06 / SEC-08)**: Hapus paket dan sembunyikan tombol login Facebook untuk mencegah runtime crash instan.
- [ ] **Perbaiki Test Suite (BUG-01 / ARCH-03)**: Selaraskan string `widget_test.dart` dan pasang mock SharedPreferences/Supabase agar tes hijau.
- [ ] **Tambahkan Izin iOS Image Picker (DEP-07 / SEC-05)**: Tambahkan `NSPhotoLibraryUsageDescription` dan `NSCameraUsageDescription` di `Info.plist`.
- [ ] **Pasang `PopScope` & Stop Tracking di Map (BUG-03, BUG-06)**: Pastikan GPS berhenti saat back button ditekan atau saat user logout.
- [ ] **Broadcast Event `group_ended` (BUG-02)**: Siarkan event penutupan grup agar anggota rombongan tidak terjebak di peta.
- [ ] **Sinkronisasi Foreground/Background GPS (PERF-01 / PERF-04)**: Hentikan timer background saat aplikasi di foreground.
- [ ] **Perbaiki Tipe Data `birth_date` (BUG-05)**: Potong timestamp ISO menjadi format `YYYY-MM-DD`.
- [ ] **Benahi Ghost Mode (BACK-07)**: Sambungkan toggle Ghost Mode ke `LocationProvider` agar menghentikan pancaran GPS.
- [ ] **Perbaiki Kueri Kuota Grup (BACK-04)**: Tambahkan filter `status = 'active'` pada fungsi batas grup.

### Fase 2: Sprint Berikutnya (Medium — Stabilitas & Performa)
- [ ] **Optimasi Rebuild `MapPage` (PERF-02)**: Pisahkan marker layer dengan `Selector`.
- [ ] **Pindahkan Realtime Stream dari `HistoryTab.build` (PERF-03)**: Simpan instance stream di `initState`.
- [ ] **Pasang GIN Index pada `member_uids` (PERF-06)**: Tingkatkan kecepatan kueri keanggotaan grup di database.
- [ ] **Gunakan `IndexedStack` di Bottom Navigation (PERF-09)**: Jaga state halaman saat berpindah tab.
- [ ] **Perbaiki Fitur Dark Mode (ARCH-05)**: Ganti hardcoded `Colors.white` dan `0xFF1A1A2E` dengan warna tema dinamis.
- [ ] **Amankan Sesi JWT dengan `flutter_secure_storage` (SEC-02)**: Hindari penyimpanan token plaintext di SharedPreferences.
- [ ] **Set `android:allowBackup="false"` (SEC-03)**: Cegah backup data via USB ADB.
- [ ] **Perbaiki Kesetaraan `GroupModel` (BUG-11)**: Masukkan `destination` dan `memberUids` ke `operator ==`.
- [ ] **Berikan Tombol Batalkan SOS (BUG-09)**: Buat tombol darurat menjadi toggle interaktif dua arah.
- [ ] **Ganti Delimited String dengan Kolom Database (ARCH-08)**: Buat migrasi SQL untuk `destination_lat` dan `destination_lng`.

### Fase 3: Backlog (Low & Info — Polishing & Tech Debt)
- [ ] **Dekomposisi God Classes (ARCH-02)**: Pecah `map_page.dart` dan `subscription_page.dart` ke file sub-widget terpisah.
- [ ] **Bersihkan Unused Dependencies (DEP-01, DEP-02)**: Hapus `uuid` dan `cupertino_icons` dari `pubspec.yaml`.
- [ ] **Konversi Gambar Onboarding ke `.webp` (PERF-12)**: Hemat ~1 MB ukuran bundle aplikasi.
- [ ] **Lengkapi File Lokalisasi (ARCH-09)**: Pindahkan seluruh string hardcoded ke file `.arb`.
- [ ] **Konfigurasi Keystore Rilis Resmi (SEC-04, DEP-09)**: Ganti `com.example.trackie` dan siapkan `key.properties`.

---

## 7. AREA DI LUAR CAKUPAN / MEMBUTUHKAN AKSES TAMBAHAN

1. **Akses Dashboard Supabase & Edge Functions**:
   Audit dilakukan berbasis file skema lokal `supabase_schema.sql`. Verifikasi apakah RLS dan ekstensi PostGIS sudah dieksekusi di database live membutuhkan akses langsung ke Supabase Dashboard.
2. **Kredensial Google Cloud Console & Meta Developer Console**:
   Pengecekan batasan API Key (SHA-1 fingerprint dan package name restriction) serta status pendaftaran App ID Facebook memerlukan akses ke konsol pengembang terkait.
3. **Pengujian Build Release Perangkat Fisik (Hardware Sensors & GPS Sleep)**:
   Perilaku spesifik manajemen daya vendor Android tertentu (seperti Xiaomi MIUI / Samsung OneUI battery optimization) saat background tracking berjalan berjam-jam memerlukan pengujian pada perangkat fisik langsung.
