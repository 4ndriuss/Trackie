# Dokumen Perencanaan (Planning) App: Trackie

## 1. Ringkasan Produk

- **Problem Statement:** Saat konvoi (sepeda, motor, mobil), rombongan sering terpisah karena perbedaan kecepatan, macet, atau lampu merah. Sulit dan berbahaya jika harus menelepon atau nge-chat untuk menanyakan "Posisi di mana?".
- **Target User:** Komunitas pesepeda (gowes), klub motor (touring), dan keluarga/teman yang roadtrip menggunakan mobil.
- **Value Proposition:** "Pantau posisi seluruh anggota rombongan secara real-time di satu peta. Perjalanan aman, tidak ada yang tertinggal."

---

## 2. User Flow

### A. Login & Sign Up

1. Buka aplikasi -> Tampil Splash Screen.
2. Layar Login: User memasukkan Email & Password.
3. Jika belum punya akun -> Klik Sign Up -> Isi Email, Password, Nama -> Submit -> Masuk ke Home.
4. Lupa Password -> Masukkan email -> Terima link reset -> Login.

### B. Home (Buat & Join Grup)

- **Buat Grup:**
  1. Di Home, klik tombol "Buat Perjalanan Baru".
  2. Muncul modal: Isi Nama Grup (contoh: "Touring Lembang"), Pilih Tipe (Motor), klik "Mulai".
  3. Sistem meng-generate Kode Undangan (contoh: `TRG-42A`).
  4. User diarahkan ke halaman "Peta Real-time" dan bisa share kode ke teman.
- **Join Grup:**
  1. Di Home, klik tombol "Gabung Perjalanan".
  2. Input Kode `TRG-42A`.
  3. Langsung masuk ke halaman "Peta Real-time" dan posisi user mulai disebar ke grup.

### C. Peta Real-time (Inti Aplikasi)

1. Tampil peta _full-screen_.
2. Ada pin/marker untuk setiap anggota grup. (Contoh: Marker biru = saya, Marker hijau = teman yang online, Marker abu-abu = teman yang terputus sinyalnya).
3. Di bawah ada _bottom sheet_ (bisa di-swipe up) berisi daftar anggota grup beserta **jarak garis lurus (haversine)** mereka dari posisi saya.
4. Tombol "Keluar Grup" untuk berhenti tracking.

### D. Riwayat (History)

1. Dari Bottom Nav Bar, pindah ke tab Riwayat.
2. Tampil list perjalanan yang pernah diikuti.
3. Klik salah satu -> Tampil halaman detail berisi **peta rute kasar (titik yang disampling tiap 50m)**, total jarak, dan durasi.

### E. Profile

1. Dari Bottom Nav Bar, pindah ke tab Profile.
2. Tampil Foto, Nama, dan Info Kendaraan.
3. Tombol Edit Profile & Log Out.

---

## 3. Daftar Fitur (Prioritas MVP vs Nanti)

| Halaman     | Fitur                                    | Prioritas (MoSCoW) |
| :---------- | :--------------------------------------- | :----------------- |
| **Auth**    | Login/Register Email & Password          | **Must**           |
| **Auth**    | Google Sign-In                           | Should             |
| **Home**    | Generate Kode Grup & Join via Kode       | **Must**           |
| **Home**    | Join via Scan QR Code                    | Could              |
| **Map**     | Tracking Real-time & Marker Anggota      | **Must**           |
| **Map**     | Perhitungan jarak haversine lokal        | **Must**           |
| **Map**     | Background Location + Foreground Service | **Must**           |
| **Riwayat** | Daftar perjalanan tersimpan              | **Must**           |
| **Riwayat** | Peta rute kasar hasil sampling           | **Must**           |
| **Profile** | Info dasar (Nama, Kendaraan, Logout)     | **Must**           |

---

## 4. Keputusan Arsitektur & Tech Stack (Hasil Diskusi)

Berdasarkan diskusi, berikut adalah landasan teknis yang disepakati untuk mempercepat development bagi **Solo Developer**:

1.  **Mobile Framework:** **Flutter**. Memungkinkan satu codebase untuk iOS dan Android. Sangat cepat untuk membuat UI peta.
2.  **Backend & Database:** **Firebase**.
    - _Firestore_ untuk data user, info grup, dan riwayat perjalanan (route).
    - _Realtime Database (RTDB)_ khusus untuk data lokasi real-time yang bergerak cepat dengan latensi rendah.
3.  **Layanan Peta:** **Google Maps SDK for Flutter**. Kuota gratis untuk mobile sangat besar.
4.  **Perhitungan Jarak:** Menggunakan rumus Haversine (jarak garis lurus) yang dihitung secara lokal di perangkat. Ini memastikan 100% gratis dan tidak membutuhkan Google Maps Distance Matrix API.

---

## 5. Struktur Database (Firebase NoSQL)

**A. Firestore (Data Permanen & Riwayat)**

- **Koleksi `users`:**
  ```json
  {
    "uid_123": {
      "name": "Andi",
      "email": "andi@mail.com",
      "vehicle": "NMAX Hitam"
    }
  }
  ```
- **Koleksi `groups` / `trips_history`:**
  ```json
  {
    "group_999": {
      "name": "Touring Lembang",
      "type": "motor",
      "inviteCode": "TRG-42A",
      "createdAt": 1698765432,
      "status": "active",
      "routePath": [
        { "lat": -6.123, "lng": 106.123 },
        { "lat": -6.124, "lng": 106.124 } // Disimpan berkala tiap ~50m
      ]
    }
  }
  ```

**B. Firebase Realtime Database (Data Real-time Ephemeral)**

- **Node `active_locations`:**
  ```json
  {
    "group_999": {
      "uid_123": {
        "lat": -6.1234,
        "lng": 106.1234,
        "timestamp": 1698765500,
        "status": "online"
      },
      "uid_456": {
        /* ... */
      }
    }
  }
  ```

---

## 6. Strategi Tracking & Edge Cases

1.  **Background Location:**
    - Aplikasi akan menggunakan **Foreground Service (Android)** dan meminta izin **"Always Allow"** (iOS/Android) beserta notifikasi _persistent_. Ini wajib agar aplikasi tidak dimatikan OS (Doze mode) saat HP dikantongi.
2.  **Leave Group Strategy (Auto-Expire):**
    - User bisa keluar secara manual dengan klik "Keluar Grup".
    - Jika user lupa (Edge case paling umum yang bikin boros baterai & melanggar privasi), sistem akan **otomatis mematikan tracking dan mengeluarkan user dari grup setelah 12-24 jam**.
3.  **Hemat Baterai (Sampling Rute):**
    - Titik lokasi untuk riwayat rute (`routePath`) hanya direkam (disimpan ke array) setiap **50 meter perpindahan**. Ini mencegah Firestore penuh dan baterai terkuras untuk write database.

---

## 7. Roadmap Pengembangan (Estimasi Solo Dev)

- **Tahap 1: Foundation (Minggu 1-2)**
  - Setup Flutter, Firebase Auth, UI Login, Home & Profile.
- **Tahap 2: Core Tracking Logic (Minggu 3-4)**
  - Implementasi Location Permission, Foreground Service, dan ping koordinat ke Firebase Realtime Database.
- **Tahap 3: Map UI & Distance (Minggu 5-6)**
  - Menampilkan Google Map, merender marker teman secara real-time, dan implementasi algoritma kalkulasi jarak Haversine lokal antar teman.
- **Tahap 4: History & Polish (Minggu 7-8)**
  - Menyimpan titik sampel rute perjalanan saat grup selesai, membuat UI halaman riwayat dengan polyline rute kasar, dan testing di jalan raya (field testing).

---

## 💡 Saran Improvement Aplikasi (Value Add di Masa Depan)

1.  **Tombol SOS / Panic Button:** Jika ada anggota yang ban bocor atau darurat, bisa tekan tombol ini dan marker-nya akan berkedip merah di HP teman-temannya (disertai bunyi alarm).
2.  **Titik Temu (Waypoints):** Ketua grup bisa menentukan titik kumpul/istirahat di peta yang bisa dilihat semua orang.
3.  **Speed Limit Warning:** Notifikasi peringatan jika ada anggota yang melaju terlalu cepat melampaui rata-rata kecepatan konvoi.
4.  **Quick In-App Voice (Walkie-Talkie):** Push-to-talk ringan tanpa perlu buka WhatsApp.

---

## User Review Required

> [!IMPORTANT]
> Dokumen Planning (MVP Trackie) telah selesai disusun berdasarkan jawaban-jawabanmu. Silakan di-review, dan tekan **Proceed / Approve** pada dokumen ini jika kamu setuju untuk menjadikannya acuan utama dalam pengembangan.
