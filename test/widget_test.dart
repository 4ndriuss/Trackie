// File: widget_test.dart
// Berisi pengujian (testing) untuk widget antarmuka pengguna aplikasi.
import 'package:flutter_test/flutter_test.dart';

import 'package:trackie/main.dart';

void main() {
  // Pengujian dasar untuk memastikan aplikasi bisa berjalan dan merender halaman login
  testWidgets('App renders login page correctly', (WidgetTester tester) async {
    // Memuat aplikasi dan melakukan render frame pertama
    await tester.pumpWidget(const TrackieApp());

    // Memverifikasi bahwa teks judul 'Trackie.' berhasil ditampilkan di layar
    expect(find.text('Trackie.'), findsOneWidget);
  });
}
