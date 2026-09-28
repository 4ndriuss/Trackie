// File: custom_textfield.dart
// Widget kustom untuk input teks (TextField) yang seragam di seluruh aplikasi.
// Mendukung fitur seperti input kata sandi (password) dengan tombol toggle visibilitas.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// [CustomTextField] adalah widget form input yang digunakan berulang kali.
/// Membungkus [TextFormField] standar dengan label di atasnya.
class CustomTextField extends StatefulWidget {
  /// Teks label yang ditampilkan di atas input.
  final String label;
  /// Teks petunjuk (hint) yang muncul di dalam input saat kosong.
  final String? hint;
  /// Menentukan apakah input ini digunakan untuk kata sandi (menyembunyikan teks).
  final bool isPassword;
  /// Controller untuk membaca dan memanipulasi nilai input.
  final TextEditingController? controller;
  /// Jenis keyboard yang ditampilkan (misalnya, angka, email, teks biasa).
  final TextInputType? keyboardType;
  /// Fungsi untuk memvalidasi nilai input, mengembalikan string error jika tidak valid.
  final String? Function(String?)? validator;
  /// Callback yang dipanggil setiap kali nilai input berubah.
  final void Function(String)? onChanged;
  /// Tombol aksi yang muncul di keyboard (misalnya, "Next" atau "Done").
  final TextInputAction? textInputAction;
  /// Node fokus untuk mengontrol fokus pada input ini.
  final FocusNode? focusNode;
  /// Menentukan apakah input ini dapat diedit (aktif) atau tidak.
  final bool enabled;
  /// Pesan error yang ditampilkan di bawah input (opsional).
  final String? errorText;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.isPassword = false,
    this.controller,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.errorText,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  // State untuk melacak apakah teks disembunyikan (untuk password)
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Memperbarui state jika properti isPassword berubah dari luar
    if (oldWidget.isPassword != widget.isPassword) {
      _obscureText = widget.isPassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menyesuaikan warna teks berdasarkan status aktif/non-aktif
    final textColor = widget.enabled 
        ? Theme.of(context).primaryColor 
        : Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Menampilkan label di atas TextField
        Text(
          // Menampilkan label dalam huruf kapital sesuai desain
          widget.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // TextField utama
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          textInputAction: widget.textInputAction,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          // Menonaktifkan sugesti dan koreksi otomatis untuk password
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            // Menambahkan ikon mata untuk password guna melihat/menyembunyikan teks
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
