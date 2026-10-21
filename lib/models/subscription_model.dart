// File: lib/models/subscription_model.dart
// Konfigurasi terpusat batas grup (PlanLimits) dan model data Subscription.

/// Jenis paket langganan yang tersedia di Trackie.
enum SubscriptionPlan {
  free,
  premium;

  String get value => name;

  static SubscriptionPlan fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'premium':
        return SubscriptionPlan.premium;
      case 'free':
      default:
        return SubscriptionPlan.free;
    }
  }
}

/// Status masa aktif langganan pengguna.
enum SubscriptionStatus {
  active,
  expired,
  canceled;

  String get value => name;

  static SubscriptionStatus fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'expired':
        return SubscriptionStatus.expired;
      case 'canceled':
      case 'cancelled':
        return SubscriptionStatus.canceled;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }
}

/// Siklus penagihan paket Premium.
enum BillingCycle {
  monthly,
  yearly;

  String get value => name;

  static BillingCycle fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'monthly':
        return BillingCycle.monthly;
      case 'yearly':
      default:
        return BillingCycle.yearly;
    }
  }
}

/// Konfigurasi terpusat batas grup dan harga paket langganan.
/// Ubah nilai konstanta di sini untuk menyesuaikan batas grup seluruh aplikasi.
class PlanLimits {
  PlanLimits._();

  /// Batas maksimal grup yang bisa dibuat/diikuti oleh pengguna paket Free.
  static const int freeMaxGroups = 2;

  /// Batas maksimal grup yang bisa dibuat/diikuti oleh pengguna paket Premium.
  static const int premiumMaxGroups = 20;

  /// Product ID untuk integrasi Google Play Billing / App Store In-App Purchase / RevenueCat.
  static const String monthlyProductId = 'trackie_premium_monthly';
  static const String yearlyProductId = 'trackie_premium_yearly';
  static const String revenueCatEntitlementId = 'premium_access';

  /// Informasi harga tampilan (UI)
  static const String monthlyPriceText = 'Rp 49.000';
  static const String monthlyPeriodText = '/ bulan';
  static const String monthlySubtext = 'Ditagih bulanan, batalkan kapan saja';

  static const String yearlyPriceText = 'Rp 299.000';
  static const String yearlyOriginalPriceText = 'Rp 588.000';
  static const String yearlyPeriodText = '/ tahun';
  static const String yearlyMonthlyEquivalentText = 'Setara Rp 24.900 / bulan';
  static const String yearlyDiscountBadge = 'PALING POPULER • HEMAT 49%';

  /// URL pengelolaan langganan Play Store & App Store
  static const String playStoreSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';
  static const String appStoreSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';

  /// Daftar benefit paket Free
  static const List<String> freeBenefits = [
    'Maksimal $freeMaxGroups grup perjalanan (buat / gabung)',
    'Pelacakan lokasi anggota secara real-time',
    'Navigasi rute standar & tombol darurat SOS',
  ];

  /// Daftar benefit paket Premium
  static const List<String> premiumBenefits = [
    'Hingga $premiumMaxGroups grup perjalanan (buat & gabung)',
    'Navigasi rute real-time & multi-checkpoint',
    'Riwayat perjalanan & statistik lengkap tanpa batas',
    'Prioritas sinyal darurat SOS & pembaruan lokasi cepat',
    'Badge eksklusif Rider Premium di profil & peta',
  ];

  /// Mengembalikan batas grup berdasarkan plan dan status aktif.
  static int maxGroupsFor({
    required SubscriptionPlan plan,
    required SubscriptionStatus status,
    DateTime? expiresAt,
  }) {
    final isExpiredByDate =
        expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isPremiumActive = plan == SubscriptionPlan.premium &&
        status == SubscriptionStatus.active &&
        !isExpiredByDate;
    return isPremiumActive ? premiumMaxGroups : freeMaxGroups;
  }
}

/// Model informasi langganan pengguna.
class SubscriptionInfo {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final BillingCycle billingCycle;
  final DateTime? expiresAt;
  final bool autoRenew;
  final bool hasSeenSubscriptionPage;

  const SubscriptionInfo({
    this.plan = SubscriptionPlan.free,
    this.status = SubscriptionStatus.active,
    this.billingCycle = BillingCycle.yearly,
    this.expiresAt,
    this.autoRenew = false,
    this.hasSeenSubscriptionPage = false,
  });

  /// Apakah tanggal berakhir sudah lewat dari waktu sekarang.
  bool get isPastExpiration =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Apakah user memiliki akses penuh fitur Premium saat ini.
  bool get isPremiumActive =>
      plan == SubscriptionPlan.premium &&
      (status == SubscriptionStatus.active ||
          status == SubscriptionStatus.canceled) &&
      !isPastExpiration;

  /// Apakah langganan Premium sudah berakhir (expired).
  bool get isPremiumExpired =>
      plan == SubscriptionPlan.premium &&
      (status == SubscriptionStatus.expired || isPastExpiration);

  /// Plan efektif yang berlaku untuk pembatasan grup saat ini.
  SubscriptionPlan get effectivePlan =>
      isPremiumActive ? SubscriptionPlan.premium : SubscriptionPlan.free;

  /// Status efektif yang memperhitungkan tanggal kedaluwarsa.
  SubscriptionStatus get effectiveStatus {
    if (plan == SubscriptionPlan.premium && isPastExpiration) {
      return SubscriptionStatus.expired;
    }
    return status;
  }

  /// Batas maksimal grup berdasarkan plan efektif saat ini.
  int get maxGroups => isPremiumActive
      ? PlanLimits.premiumMaxGroups
      : PlanLimits.freeMaxGroups;

  /// Nama paket untuk ditampilkan di UI.
  String get planDisplayName => isPremiumActive ? 'Premium' : 'Free';

  SubscriptionInfo copyWith({
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    BillingCycle? billingCycle,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? autoRenew,
    bool? hasSeenSubscriptionPage,
  }) {
    return SubscriptionInfo(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      billingCycle: billingCycle ?? this.billingCycle,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      autoRenew: autoRenew ?? this.autoRenew,
      hasSeenSubscriptionPage:
          hasSeenSubscriptionPage ?? this.hasSeenSubscriptionPage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan.value,
      'subscription_status': effectiveStatus.value,
      'billing_cycle': billingCycle.value,
      'subscription_expires_at': expiresAt?.toIso8601String(),
      'auto_renew': autoRenew,
      'has_seen_subscription_page': hasSeenSubscriptionPage,
    };
  }

  factory SubscriptionInfo.fromMap(Map<String, dynamic> map) {
    DateTime? parsedExpires;
    final rawExpires = map['subscription_expires_at'] ?? map['expiresAt'];
    if (rawExpires is DateTime) {
      parsedExpires = rawExpires;
    } else if (rawExpires is String && rawExpires.isNotEmpty) {
      parsedExpires = DateTime.tryParse(rawExpires);
    }

    final plan = SubscriptionPlan.fromString(map['plan'] as String?);
    var status = SubscriptionStatus.fromString(
      (map['subscription_status'] ?? map['subscriptionStatus']) as String?,
    );
    if (plan == SubscriptionPlan.premium &&
        parsedExpires != null &&
        parsedExpires.isBefore(DateTime.now())) {
      status = SubscriptionStatus.expired;
    }

    final rawHasSeen =
        map['has_seen_subscription_page'] ?? map['hasSeenSubscriptionPage'];
    final hasSeen = rawHasSeen is bool ? rawHasSeen : false;

    final rawAutoRenew = map['auto_renew'] ?? map['autoRenew'];
    final autoRenew = rawAutoRenew is bool
        ? rawAutoRenew
        : (plan == SubscriptionPlan.premium &&
            status == SubscriptionStatus.active);

    return SubscriptionInfo(
      plan: plan,
      status: status,
      billingCycle: BillingCycle.fromString(
        (map['billing_cycle'] ?? map['billingCycle']) as String?,
      ),
      expiresAt: parsedExpires,
      autoRenew: autoRenew,
      hasSeenSubscriptionPage: hasSeen,
    );
  }
}
