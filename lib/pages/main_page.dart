// File: main_page.dart
// Halaman utama setelah pengguna berhasil login atau mendaftar.
// Menyediakan navigasi bawah (BottomNavigationBar) untuk berpindah antar tab (Home, Riwayat, Profil).
import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'history_tab.dart';

/// [MainPage] adalah kerangka utama yang mengatur navigasi berbasis tab di aplikasi.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // Indeks tab yang sedang aktif, dimulai dari 0 (Home)
  int _selectedIndex = 0;

  // Daftar halaman/tab yang bisa dinavigasikan melalui BottomNavigationBar
  final List<Widget> _tabs = [
    const HomeTab(), // Tab Home (Beranda)
    const HistoryTab(), // Tab Riwayat (History)
    const Center(child: Text('Profil User akan tampil di sini')), // Tab Profil (Profile)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menampilkan konten tab sesuai indeks yang dipilih
      body: _tabs[_selectedIndex],
      // Navigasi bawah
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // Memperbarui state agar tampilan beralih ke tab yang dipilih
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.secondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
