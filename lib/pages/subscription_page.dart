// File: lib/pages/subscription_page.dart
// Halaman Subscription (Paywall Pertama Kali Masuk & Halaman Pengelolaan Subscription dari Settings).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subscription_model.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_page.dart';

class SubscriptionPage extends StatefulWidget {
  /// Jika `true`, halaman ini tampil otomatis setelah login/sign up pertama kali
  /// sebelum masuk ke Home, dan tombol back dikunci agar tidak kembali ke halaman login.
  final bool isFirstTimeFlow;

  const SubscriptionPage({
    super.key,
    this.isFirstTimeFlow = false,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  static const Color _successColor = Color(0xFF16A34A);
  static const Color _errorColor = Colors.redAccent;

  BillingCycle _selectedCycle = BillingCycle.yearly;
  String? _statusBannerMessage;
  bool _isStatusError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        final subProvider = context.read<SubscriptionProvider>();
        subProvider.initializeForUser(uid);
        setState(() {
          _selectedCycle = subProvider.billingCycle;
        });
      }
    });
  }

  Future<void> _handleContinueAsFree() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final subProvider = context.read<SubscriptionProvider>();
    final ok = await subProvider.continueAsFree(uid);
    if (!mounted) return;

    if (ok) {
      if (widget.isFirstTimeFlow) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamu menggunakan paket Trackie Free.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _statusBannerMessage =
            subProvider.errorMessage ?? 'Gagal menyimpan pilihan paket.';
        _isStatusError = true;
      });
    }
  }

  Future<void> _handleSubscribe({bool simulateCancel = false}) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      setState(() {
        _statusBannerMessage =
            'Sesi pengguna tidak ditemukan. Silakan login ulang.';
        _isStatusError = true;
      });
      return;
    }

    setState(() {
      _statusBannerMessage = null;
    });

    final subProvider = context.read<SubscriptionProvider>();
    final result = await subProvider.subscribePremium(
      uid: uid,
      billingCycle: _selectedCycle,
      simulateCancel: simulateCancel,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.isFirstTimeFlow) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        setState(() {
          _statusBannerMessage = result.message;
          _isStatusError = false;
        });
      }
    } else {
      setState(() {
        _statusBannerMessage = result.message;
        _isStatusError = true;
      });
    }
  }

  Future<void> _handleRestorePurchase() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    setState(() => _statusBannerMessage = null);
    final subProvider = context.read<SubscriptionProvider>();
    final result = await subProvider.restorePurchases(uid);

    if (!mounted) return;
    setState(() {
      _statusBannerMessage = result.message;
      _isStatusError = !result.success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? _successColor : null,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.success && widget.isFirstTimeFlow) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _showManageSubscriptionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? PlanLimits.appStoreSubscriptionsUrl
        : PlanLimits.playStoreSubscriptionsUrl;
    final storeName = defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple App Store'
        : 'Google Play Store';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF23262A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.manage_history_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kelola Langganan $storeName',
                      style: GoogleFonts.urbanist(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Langganan Trackie Premium dikelola melalui akun $storeName kamu. Kamu dapat mengubah siklus tagihan atau membatalkan perpanjangan otomatis kapan saja melalui tautan resmi berikut:',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF6B6F9A),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1C1E)
                      : const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFEDEDF2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        storeUrl,
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Salin URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: storeUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tautan $storeName disalin ke clipboard.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTermsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23262A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Syarat & Ketentuan Langganan',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            '1. Paket Free memberikan kuota maksimal ${PlanLimits.freeMaxGroups} grup perjalanan.\n\n'
            '2. Paket Premium memberikan kuota hingga ${PlanLimits.premiumMaxGroups} grup perjalanan beserta fitur prioritas selama masa berlangganan aktif.\n\n'
            '3. Langganan diperpanjang secara otomatis kecuali dibatalkan minimal 24 jam sebelum periode berjalan berakhir.\n\n'
            '4. Jika masa berlangganan Premium berakhir, data grup dan riwayat perjalanan yang sudah ada tetap tersimpan dan dapat dilihat, namun pembuatan atau penggabungan grup baru akan mengikuti batas paket Free sampai kamu melakukan perpanjangan.',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF5B5F97),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tutup',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subProvider = context.watch<SubscriptionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final uid = authProvider.user?.uid;

    final bgColor = isDark ? const Color(0xFF141619) : const Color(0xFFF7F7FA);
    final cardColor = isDark ? const Color(0xFF1E2126) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? const Color(0xFFA8ABB8) : const Color(0xFF6B6F9A);
    final borderColor =
        isDark ? const Color(0xFF2E323B) : const Color(0xFFEDEDF2);

    return PopScope(
      canPop: !widget.isFirstTimeFlow,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: widget.isFirstTimeFlow
            ? null
            : AppBar(
                backgroundColor: cardColor,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  'Subscription',
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Brand & Tagline
                    _buildHeader(isDark, textPrimary, textSecondary),
                    const SizedBox(height: 20),

                    // Banner pesan error / sukses pembayaran
                    if (_statusBannerMessage != null) ...[
                      _buildStatusBanner(
                        _statusBannerMessage!,
                        _isStatusError,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Kartu Status Langganan Saat Ini (Tampil saat dibuka dari Settings / Home)
                    if (!widget.isFirstTimeFlow) ...[
                      _buildCurrentStatusCard(
                        subProvider: subProvider,
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Toggle Bulanan / Tahunan
                    _buildBillingCycleToggle(
                      isDark,
                      cardColor,
                      textPrimary,
                      textSecondary,
                    ),
                    const SizedBox(height: 24),

                    // Kartu Paket Premium (Dengan highlight "PALING POPULER" & Pilihan Siklus)
                    _buildPremiumPackageCard(
                      subProvider: subProvider,
                      isDark: isDark,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 20),

                    // Kartu Paket Free
                    _buildFreePackageCard(
                      subProvider: subProvider,
                      isDark: isDark,
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 24),

                    // Panel Developer Mock Toggle (SEC-02: Terproteksi hanya tampil saat mode debug / development)
                    if (kDebugMode && uid != null) ...[
                      _buildDeveloperMockCard(
                        uid: uid,
                        subProvider: subProvider,
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Footer: Restore Purchase, Syarat & Ketentuan, Kebijakan Privasi
                    _buildFooterLinks(textSecondary),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Loading Overlay saat memproses pembayaran / restore
              if (subProvider.isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Memproses langganan...',
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF4A0FBF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Trackie Premium',
          style: GoogleFonts.urbanist(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pilih paket yang cocok untukmu',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nikmati kebebasan membuat lebih banyak grup touring, navigasi rute lengkap, dan koordinasi konvoi tanpa batas.',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontSize: 14,
            color: textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String message, bool isError, bool isDark) {
    final color = isError ? _errorColor : _successColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.urbanist(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard({
    required SubscriptionProvider subProvider,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final isPremium = subProvider.isPremium;
    final isExpired = subProvider.isPremiumExpired;
    final used = subProvider.usedGroupsCount;
    final max = subProvider.maxGroups;
    final progress = max > 0 ? (used / max).clamp(0.0, 1.0) : 0.0;
    final expiresAt = subProvider.expiresAt;

    final String statusBadgeText = isPremium
        ? 'PREMIUM AKTIF'
        : (isExpired ? 'PREMIUM BERAKHIR' : 'PAKET FREE');
    final Color statusBadgeColor = isPremium
        ? AppTheme.primary
        : (isExpired ? _errorColor : const Color(0xFF4A0FBF));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Langganan Saat Ini',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBadgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusBadgeText,
                  style: GoogleFonts.urbanist(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.layers_outlined,
                color: isPremium ? AppTheme.primary : const Color(0xFF4A0FBF),
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                'Paket ${subProvider.subscription.planDisplayName}',
                style: GoogleFonts.urbanist(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          if (isPremium && expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Perpanjangan berikutnya: ${DateFormat('dd MMM yyyy').format(expiresAt)}',
              style: GoogleFonts.urbanist(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  subProvider.autoRenew
                      ? Icons.autorenew_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 16,
                  color: subProvider.autoRenew ? _successColor : textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  subProvider.autoRenew
                      ? 'Auto-renew: Aktif (${subProvider.billingCycle == BillingCycle.yearly ? 'Tahunan' : 'Bulanan'})'
                      : 'Auto-renew: Nonaktif',
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        subProvider.autoRenew ? _successColor : textSecondary,
                  ),
                ),
              ],
            ),
          ] else if (isExpired) ...[
            const SizedBox(height: 8),
            Text(
              'Masa aktif Premium kamu telah berakhir. Grup lama tetap bisa dilihat, namun kamu perlu upgrade kembali untuk menambah grup baru di atas batas Free.',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                color: _errorColor,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Penggunaan Grup',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                '$used / $max grup terpakai',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: used >= max ? _errorColor : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  isDark ? Colors.white12 : const Color(0xFFEDEDF2),
              valueColor: AlwaysStoppedAnimation<Color>(
                used >= max ? _errorColor : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isPremium)
            OutlinedButton.icon(
              onPressed: _showManageSubscriptionSheet,
              icon: const Icon(Icons.settings_suggest_rounded, size: 18),
              label: Text(
                'Kelola Langganan (Play Store / App Store)',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.white : const Color(0xFF4A0FBF),
                side: BorderSide(
                  color: isDark ? Colors.white24 : const Color(0xFF4A0FBF),
                ),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleToggle(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFEDEDF2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCycle = BillingCycle.monthly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedCycle == BillingCycle.monthly
                      ? AppTheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Bulanan',
                  style: GoogleFonts.urbanist(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedCycle == BillingCycle.monthly
                        ? Colors.white
                        : textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCycle = BillingCycle.yearly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedCycle == BillingCycle.yearly
                      ? AppTheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tahunan',
                      style: GoogleFonts.urbanist(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedCycle == BillingCycle.yearly
                            ? Colors.white
                            : textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedCycle == BillingCycle.yearly
                            ? Colors.white.withValues(alpha: 0.22)
                            : AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'HEMAT 49%',
                        style: GoogleFonts.urbanist(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _selectedCycle == BillingCycle.yearly
                              ? Colors.white
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPackageCard({
    required SubscriptionProvider subProvider,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isYearly = _selectedCycle == BillingCycle.yearly;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primary,
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dua kartu opsi harga bergaya referensi Gentler Streak
              _buildSelectablePricingTile(
                title: 'Premium Tahunan',
                price:
                    '${PlanLimits.yearlyPriceText} ${PlanLimits.yearlyPeriodText}',
                originalPrice: PlanLimits.yearlyOriginalPriceText,
                subtitle: PlanLimits.yearlyMonthlyEquivalentText,
                isSelected: isYearly,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () =>
                    setState(() => _selectedCycle = BillingCycle.yearly),
              ),
              const SizedBox(height: 12),
              _buildSelectablePricingTile(
                title: 'Premium Bulanan',
                price:
                    '${PlanLimits.monthlyPriceText} ${PlanLimits.monthlyPeriodText}',
                originalPrice: null,
                subtitle: PlanLimits.monthlySubtext,
                isSelected: !isYearly,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () =>
                    setState(() => _selectedCycle = BillingCycle.monthly),
              ),
              const SizedBox(height: 20),

              Text(
                'BENEFIT PAKET PREMIUM',
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ...PlanLimits.premiumBenefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          benefit,
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tombol Berlangganan
              ElevatedButton(
                onPressed: subProvider.isLoading
                    ? null
                    : () => _handleSubscribe(simulateCancel: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  subProvider.isPremium
                      ? 'Perbarui Paket Premium'
                      : 'Berlangganan Sekarang',
                  style: GoogleFonts.urbanist(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating Badge "PALING POPULER • HEMAT 49%" di bagian atas kartu
        Positioned(
          top: -13,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFFFF8800)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              PlanLimits.yearlyDiscountBadge,
              style: GoogleFonts.urbanist(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectablePricingTile({
    required String title,
    required String price,
    required String? originalPrice,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.07)
              : (isDark ? const Color(0xFF15181C) : const Color(0xFFF7F7FA)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.urbanist(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.primary : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.urbanist(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (originalPrice != null) ...[
                        Text(
                          originalPrice,
                          style: GoogleFonts.urbanist(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.urbanist(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : (isDark ? Colors.white30 : const Color(0xFFC4C4D4)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreePackageCard({
    required SubscriptionProvider subProvider,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paket Free',
                    style: GoogleFonts.urbanist(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Maksimal ${PlanLimits.freeMaxGroups} grup perjalanan',
                    style: GoogleFonts.urbanist(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                'Gratis',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFFB58CFF)
                      : const Color(0xFF4A0FBF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...PlanLimits.freeBenefits.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.urbanist(
                        fontSize: 13.5,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: subProvider.isLoading ? null : _handleContinueAsFree,
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(color: borderColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Continue as Free',
              style: GoogleFonts.urbanist(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperMockCard({
    required String uid,
    required SubscriptionProvider subProvider,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF4A0FBF).withValues(alpha: 0.15)
            : const Color(0xFF4A0FBF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4A0FBF).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.developer_mode_rounded,
                size: 18,
                color: Color(0xFF4A0FBF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Developer Mock Controls (Testing)',
                  style: GoogleFonts.urbanist(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFB58CFF)
                        : const Color(0xFF4A0FBF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gunakan tombol di bawah untuk menguji perpindahan paket Free/Premium/Expired atau simulasi pembatalan pembayaran:',
            style: GoogleFonts.urbanist(
              fontSize: 12.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMockActionChip(
                label: 'Toggle Free ↔ Premium',
                icon: Icons.swap_horiz_rounded,
                onTap: () async {
                  final updated = await subProvider.toggleMockPlan(uid);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Mock Plan diubah ke: ${updated.planDisplayName} (Maks ${updated.maxGroups} grup)',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildMockActionChip(
                label: 'Simulasi Premium Habis',
                icon: Icons.timer_off_outlined,
                onTap: () async {
                  await subProvider.toggleMockPlan(
                    uid,
                    targetPlan: SubscriptionPlan.premium,
                    targetStatus: SubscriptionStatus.expired,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Simulasi: Langganan Premium berakhir (Expired). Batas kembali ke Free.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildMockActionChip(
                label: 'Simulasi Batal Bayar',
                icon: Icons.cancel_outlined,
                onTap: () => _handleSubscribe(simulateCancel: true),
              ),
              _buildMockActionChip(
                label: 'Simulasi 2 Grup Terpakai',
                icon: Icons.group_add_outlined,
                onTap: () {
                  subProvider.setMockUsedGroupsCount(PlanLimits.freeMaxGroups);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Simulasi: Penggunaan diset ke 2 grup (Batas Free tercapai).',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: AppTheme.primary),
      label: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildFooterLinks(Color textSecondary) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: _handleRestorePurchase,
          icon: Icon(Icons.restore_rounded, size: 18, color: textSecondary),
          label: Text(
            'Restore Purchase',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            GestureDetector(
              onTap: _showTermsDialog,
              child: Text(
                'Syarat & Ketentuan',
                style: GoogleFonts.urbanist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
            Text('•', style: TextStyle(color: textSecondary)),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              },
              child: Text(
                'Kebijakan Privasi',
                style: GoogleFonts.urbanist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
