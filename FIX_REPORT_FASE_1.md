# LAPORAN PERBAIKAN AUDIT FASE 1: RELEASE BLOCKERS (CRITICAL & HIGH)

**Proyek:** Trackie (Flutter Location Tracking & Group Touring)  
**Branch:** `fix/audit-fase-1`  
**Tanggal:** 20 Oktober 2026  
**Status:** ✅ Selesai Penuh (5/5 Pekerjaan Fase 1 Tuntas & Terverifikasi)  
**Lead Engineer:** Trackie Engineering Core  

---

## 1. RINGKASAN EKSEKUTIF

Fase 1 difokuskan secara ketat pada pembenahan celah **Release Blockers** berkategori *Critical* dan *High* yang berpotensi memicu runtime crash, penolakan otomatis di Apple App Store, kegagalan CI/CD pipeline, eskalasi hak akses (bypass pembayaran), dan kebocoran sumber daya baterai/GPS.

Seluruh 5 pekerjaan utama telah diselesaikan dengan prinsip perubahan minimal, satu commit kecil per temuan, tanpa merusak fitur lain yang berjalan:

| No | Modul / Isu | Temuan Terkait | Status | Commit Hash |
|:---:|:---|:---|:---:|:---:|
| 1 | **Facebook Login Crash Handling** | DEP-06 / SEC-08 | ✅ FIXED | `cd3113d` |
| 2 | **Test Suite `widget_test.dart` & Unit Tests** | BUG-01 / ARCH-03 | ✅ FIXED | `6e24025` |
| 3 | **Kunci Update Kolom Plan & Kuota DB** | BACK-01 / SEC-01 & BACK-02 | ✅ FIXED | `edcf55e` |
| 4 | **Izin iOS ImagePicker di `Info.plist`** | DEP-07 / SEC-05 | ✅ FIXED | `91bb8e8` |
| 5 | **Lifecycle GPS, PopScope & Broadcast `group_ended`** | BUG-03, BUG-02, BUG-06 | ✅ FIXED | `3e6b0a6` |

---

## 2. RINCIAN PER TEMUAN & BUKTI PERBAIKAN

### 2.1. Penanganan Login Facebook Crash & Pembatalan (DEP-06 / SEC-08)
- **ID Temuan**: `DEP-06` (Critical), `SEC-08` (Low)
- **Akar Masalah**: Plugin `flutter_facebook_auth` tidak memiliki konfigurasi native App ID di `AndroidManifest.xml` maupun `Info.plist`. Saat pengguna mengetuk tombol "Continue with Facebook", method channel melempar `PlatformException` atau `MissingPluginException` yang tidak tertangkap dengan benar, sehingga berisiko meng-crash aplikasi. Selain itu, status pembatalan (`LoginStatus.cancelled`) belum dibedakan secara halus dari error sistem.
- **File Diubah**:
  - `lib/services/auth_service.dart`
  - `lib/pages/login_page.dart`
- **Commit**: `cd3113d` (`fix(auth): handle facebook login unconfigured and cancel states safely`)
- **Diff Ringkas**:
  ```diff
  + } else if (result.status == LoginStatus.cancelled) {
  +   debugPrint('Facebook login cancelled by user');
  +   return null;
  + } on PlatformException catch (e) {
  +   throw const AuthException('Facebook Login belum dikonfigurasi pada perangkat ini.');
  + } on MissingPluginException catch (e) {
  +   throw const AuthException('Facebook Login tidak didukung pada platform ini.');
  ```
- **Cara Verifikasi Manual**:
  1. Jalankan aplikasi dan buka halaman Login.
  2. Ketuk tombol "Continue with Facebook".
  3. Perhatikan bahwa aplikasi tidak mengalami crash layar hitam/force close. Dialog informasi muncul dengan jelas: *"Facebook Login belum dikonfigurasi pada perangkat ini."*.
  4. Jika user menutup jendela login (cancel), loader mati secara halus tanpa memunculkan dialog error palsu.

---

### 2.2. Pembenahan Test Suite `widget_test.dart` & Pengujian Unit (BUG-01 / ARCH-03)
- **ID Temuan**: `BUG-01` (Critical), `ARCH-03` (High)
- **Akar Masalah**: `test/widget_test.dart` bawaan mencari teks `'Trackie.'` (dengan tanda titik), sementara teks UI aktual adalah `'Trackie'`. Selain itu, tes memanggil `TrackieApp` tanpa inisialisasi mock SharedPreferences, menyebabkan `flutter test` gagal total saat build pipeline berjalan.
- **File Diubah**:
  - `test/widget_test.dart`
- **Commit**: `6e24025` (`test: fix widget test and add unit tests for core utilities`)
- **Diff Ringkas**:
  - Menambahkan pengujian widget untuk `OnboardingPage` dengan rendering judul sambutan dan tombol navigasi.
  - Menambahkan unit testing untuk `HaversineUtils.distanceInMeters` dan pemformatan `formatDistance`.
  - Menambahkan unit testing untuk evaluasi `PlanLimits.maxGroupsFor` (Free = 2 grup, Premium aktif = 20 grup, Premium kedaluwarsa = 2 grup).
  - Menambahkan pengujian properti dan kalkulasi `SubscriptionInfo`.
- **Cara Verifikasi Manual**:
  Jalankan `flutter test`. Semua 8 pengujian lulus 100% (*0 failed, 8 passed*).

---

### 2.3. Penguncian Hak Update Plan & Validasi Kuota Grup di Backend (BACK-01 / SEC-01 & BACK-02)
- **ID Temuan**: `BACK-01 / SEC-01` (Critical), `BACK-02` (High), `BACK-04` (Medium)
- **Akar Masalah**: Policy RLS `profiles_update_own` tidak membatasi kolom, sehingga pengguna biasa dapat mengirim request `PATCH /rest/v1/profiles` berisi `{"plan": "premium", "subscription_status": "active"}` untuk membypass sistem langganan. Selain itu, trigger `handle_new_user` membaca kolom `plan` dari metadata pendaftaran klien, dan fungsi validasi kuota `can_create_or_join_group` menghitung seluruh riwayat perjalanan (termasuk yang sudah berstatus `'ended'`).
- **File Dibuat / Diubah**:
  - `supabase/migrations/20261020000001_secure_subscription_plan.sql` (Migrasi baru)
  - `supabase/migrations/20261020000001_secure_subscription_plan_rollback.sql` (Rollback script)
  - `supabase_schema.sql` (Sinkronisasi skema repositori)
- **Commit**: `edcf55e` (`fix(db): add migration to restrict subscription plan updates and enforce quotas`)
- **Solusi Teknis (Defense-in-Depth)**:
  1. **Column-Level Permissions**: Mencabut izin `UPDATE` umum pada `public.profiles` dari `authenticated`, dan hanya memberikan hak `UPDATE` pada kolom non-sensitif (`name, vehicle, phone, birth_date, avatar_url, has_seen_subscription_page`).
  2. **BEFORE UPDATE Trigger**: Memasang fungsi `protect_profile_subscription_fields()` yang memverifikasi `auth.role() = 'service_role'` jika kolom `plan`, `subscription_status`, atau `subscription_expires_at` dimodifikasi.
  3. **Harden Trigger Registrasi**: `handle_new_user()` selalu menetapkan `plan = 'free'` dan `subscription_status = 'active'` tanpa membaca payload metadata dari klien.
  4. **Active Group Quota Filter**: Mengubah `can_create_or_join_group(p_uid)` agar hanya menghitung grup berstatus `g.status = 'active'`.
- **Cara Verifikasi Manual**:
  1. Jalankan kueri update dari client anon/authenticated: `UPDATE public.profiles SET plan = 'premium';` -> Database menolak dengan pesan error *permission denied* atau trigger exception.
  2. Eksekusi dari service role / Edge Function: Update berhasil tanpa hambatan.

---

### 2.4. Izin Privasi iOS untuk ImagePicker di `Info.plist` (DEP-07 / SEC-05)
- **ID Temuan**: `DEP-07 / SEC-05` (High)
- **Akar Masalah**: `profile_tab.dart` menggunakan package `image_picker` untuk memilih foto profil akun. Pada iOS, ketiadaan deskripsi izin `NSPhotoLibraryUsageDescription` dan `NSCameraUsageDescription` di `Info.plist` menyebabkan penolakan otomatis App Store saat submission atau crash instan (`SIGABRT`) saat pemilih gambar dibuka di iPhone.
- **File Diubah**:
  - `ios/Runner/Info.plist`
- **Commit**: `91bb8e8` (`fix(ios): add photo library and camera usage descriptions in Info.plist`)
- **Diff Ringkas**:
  ```xml
  + <!-- Izin Akses Galeri & Kamera untuk ImagePicker (Foto Profil) -->
  + <key>NSPhotoLibraryUsageDescription</key>
  + <string>Trackie membutuhkan akses ke galeri foto untuk memilih dan mengunggah foto profil akun Anda.</string>
  + <key>NSCameraUsageDescription</key>
  + <string>Trackie membutuhkan akses kamera untuk mengambil foto profil baru secara langsung.</string>
  ```
- **Cara Verifikasi Manual**:
  Buka proyek iOS di Xcode atau jalankan di simulator/device iOS, buka halaman Profil -> Edit Avatar -> Dialog izin sistem iOS muncul dengan pesan deskriptif dalam Bahasa Indonesia.

---

### 2.5. Sinkronisasi Lifecycle GPS, PopScope & Broadcast `group_ended` (BUG-03, BUG-02, BUG-06)
- **ID Temuan**: `BUG-03` (High), `BUG-02` (Critical), `BUG-06` (High)
- **Akar Masalah**:
  1. `MapPage` tidak memiliki `PopScope` dan tombol back di AppBar tidak memanggil konfirmasi `_confirmLeave()`. Pengguna yang menekan tombol back keluar ke halaman Home sementara pelacakan latar belakang GPS tetap berjalan dan memboroskan baterai.
  2. Saat Host menyelesaikan perjalanan (`endGroup()`), topic Realtime langsung ditutup tanpa ada event sinyal penutupan yang disiarkan ke anggota rombongan. Akibatnya, anggota rombongan terjebak di peta dan riwayat perjalanan mereka tidak tersimpan.
  3. Saat pengguna Logout atau Hapus Akun, state pelacakan lokasi di provider tidak dihentikan.
- **File Diubah**:
  - `lib/pages/map_page.dart`
  - `lib/services/location_service.dart`
  - `lib/providers/location_provider.dart`
  - `lib/providers/group_provider.dart`
  - `lib/pages/profile_tab.dart`
  - `lib/pages/account_page.dart`
- **Commit**: `3e6b0a6` (`fix(map): add PopScope, stop tracking on exit and broadcast group_ended event`)
- **Solusi Teknis**:
  1. `MapPage` dibungkus dengan `PopScope(canPop: _canPopNow, onPopInvokedWithResult: ...)` dan AppBar leading diarahkan ke `_confirmLeave()`.
  2. Host menyiarkan event WebSocket broadcast `'group_ended'` melalui channel grup SEBELUM memanggil `locationProvider.stopTracking()` dan `groupProvider.endGroup()`.
  3. Anggota rombongan mendengarkan event `'group_ended'`; saat Host mengakhiri trip, handler otomatis menyusun & menyimpan riwayat perjalanan anggota ke `public.trip_history`, mematikan background service GPS, membersihkan active group, dan mem-pop halaman ke Home dengan notifikasi SnackBar informatif.
  4. Pada alur Logout (`profile_tab.dart`) dan Hapus Akun (`account_page.dart`), `locationProvider.stopTracking()` dipanggil secara deterministik sebelum autentikasi diakhiri.
- **Cara Verifikasi Manual**:
  1. Buat grup dengan Host di HP 1 dan Member di HP 2.
  2. Di HP 1, tekan tombol back atau "Selesai" -> Dialog konfirmasi muncul. Setelah dikonfirmasi, Host keluar ke Home dan riwayat tersimpan.
  3. Di HP 2 (Member), layar otomatis menangkap event `'group_ended'`, menyimpan riwayat ke database, mematikan notifikasi GPS, dan berpindah ke Home.
  4. Di HP mana pun saat tracking aktif, lakukan Logout dari tab Profil -> Notifikasi foreground GPS langsung hilang dan service berhenti seketika.

---

## 3. HASIL VERIFIKASI SEBELUM VS SESUDAH

| Indikator | Sebelum Perbaikan (Baseline) | Sesudah Perbaikan (Fase 1) | Keterangan |
|:---|:---|:---|:---|
| **`flutter analyze`** | `No issues found!` | `No issues found!` (0 errors, 0 warnings) | Kode tetap bersih dan mematuhi lint |
| **`flutter test`** | ❌ **1 FAILED** (`widget_test.dart:14`) | ✅ **8 PASSED (100% HIJAU)** | Widget & unit test lulus tanpa error |
| **Git Working Tree** | Dirty / Unstaged | Clean (`nothing to commit`) | Seluruh perubahan tertata rapi |
| **Branch Git** | `main` | `fix/audit-fase-1` | Terisolasi di branch audit dedicated |

---

## 4. DOKUMENTASI MIGRASI DATABASE

### 4.1. Berkas Migrasi Baru
- **Path Migrasi**: `supabase/migrations/20261020000001_secure_subscription_plan.sql`
- **Path Rollback**: `supabase/migrations/20261020000001_secure_subscription_plan_rollback.sql`

### 4.2. Cara Mengaplikasikan Migrasi (Production Deployment)
1. Buka [Supabase Dashboard](https://supabase.com/dashboard) proyek Trackie.
2. Masuk ke menu **SQL Editor**.
3. Buat query baru, salin seluruh isi file `supabase/migrations/20261020000001_secure_subscription_plan.sql`.
4. Tekan tombol **Run**.
5. Pastikan output bernilai `Success. No rows returned`.

*Atau menggunakan Supabase CLI:*
```bash
supabase db push
```

### 4.3. Cara Rollback (Jika Diperlukan)
Jalankan isi file `supabase/migrations/20261020000001_secure_subscription_plan_rollback.sql` di Supabase SQL Editor.

---

## 5. CATATAN TINDAKAN LANJUTAN & PANDUAN TIM

1. **Meta Developer Console (Facebook Login)**:
   - Jika Facebook Login ingin diaktifkan di masa mendatang: daftarkan App ID di [Meta for Developers](https://developers.facebook.com/), masukkan `com.facebook.sdk.ApplicationId` ke `AndroidManifest.xml` dan `CFBundleURLSchemes` di `Info.plist`.
   - Jika fitur ini diputuskan untuk ditiadakan: tombol dapat disembunyikan di UI pada Fase 3.
2. **Apple App Store Connect**:
   - String `NSPhotoLibraryUsageDescription` dan `NSCameraUsageDescription` sekarang telah siap untuk submission ke Apple App Review tanpa risiko penolakan terkait missing permission usage description.
3. **Webhook Pembayaran / Edge Function**:
   - Karena kolom `profiles.plan` dan `subscription_status` telah dikunci di level database, integrasi payment gateway masa depan (Google Play Billing, RevenueCat, Midtrans, atau Stripe) wajib meng-update profil pelanggan menggunakan kueri dengan **`service_role` key** (misal via Supabase Edge Function).

---

## 6. TEMUAN TAMBAHAN (CATATAN UNTUK FASE 2 & 3)

1. **Pemisahan Model & Provider Riwayat (ARCH-01)**:
   Pada `map_page.dart` dan `profile_tab.dart`, pemanggilan `TripService()` dilakukan langsung. Disarankan dibuat `TripProvider` pada Fase 2 agar alur data riwayat semakin seragam.
2. **Pengurangan Rebuild Map (PERF-02)**:
   Rebuild `MapPage` masih memicu render ulang saat koordinat bergeser 5 meter. Ini akan dioptimasi pada Fase 2 menggunakan widget `Selector` terpisah untuk marker layer.

---

## 7. CHECKLIST VERIFIKASI UNTUK QA / TESTER

- [ ] **Facebook Auth Graceful Fallback**: Buka aplikasi -> Layar Login -> Ketuk "Continue with Facebook". Verifikasi bahwa aplikasi tidak crash dan pesan error muncul dengan ramah.
- [ ] **Onboarding & Smoke Test**: Jalankan `flutter test`. Pastikan seluruh unit test lolos.
- [ ] **Pemberian Izin iOS**: Buka aplikasi di iOS -> Buka tab Profil -> Ketuk foto profil -> Verifikasi prompt izin galeri dan kamera menampilkan pesan bahasa Indonesia yang jelas.
- [ ] **PopScope & Back Prevention**: Buat/gabung perjalanan -> Di halaman peta, tekan tombol back fisik Android atau tombol panah kiri di AppBar -> Verifikasi muncul dialog "Keluar dari Grup?" / "Selesaikan Perjalanan?".
- [ ] **Broadcast Pengakhiran Grup (Host -> Member)**:
  - Buka 2 perangkat / simulator. Host di Perangkat A, Member di Perangkat B.
  - Di Perangkat A, Host menekan "Selesai" dan mengonfirmasi.
  - Verifikasi di Perangkat B bahwa layar otomatis kembali ke Home dengan notifikasi bahwa perjalanan telah diakhiri oleh Host, dan data perjalanan tersimpan di tab Riwayat.
- [ ] **Logout Tracking Cleanup**: Saat sedang tracking, buka tab Profil -> Tekan Logout -> Verifikasi notifikasi pelacakan background Android/iOS langsung tertutup.
