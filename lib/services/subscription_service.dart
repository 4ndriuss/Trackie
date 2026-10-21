// File: lib/services/subscription_service.dart
// Abstraksi layanan Subscription beserta implementasi MockSubscriptionService (development)
// dan StoreSubscriptionService (kerangka siap pakai untuk in_app_purchase / RevenueCat).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_model.dart';
import '../supabase_config.dart';

/// Hasil transaksi pembelian atau restore paket langganan.
class SubscriptionPurchaseResult {
  final bool success;
  final bool isCanceled;
  final String message;
  final SubscriptionInfo? subscriptionInfo;

  const SubscriptionPurchaseResult({
    required this.success,
    this.isCanceled = false,
    required this.message,
    this.subscriptionInfo,
  });
}

/// Kontrak abstrak [SubscriptionService].
/// Memudahkan penggantian antara [MockSubscriptionService] dan [StoreSubscriptionService].
abstract class SubscriptionService {
  /// Memuat status langganan terkini milik user (dari lokal & database backend).
  Future<SubscriptionInfo> loadSubscription(String uid);

  /// Memilih paket Free dan menandai bahwa halaman Subscription sudah dilihat.
  Future<SubscriptionInfo> selectFreePlan(String uid);

  /// Menjalankan proses pembelian paket Premium (Bulanan / Tahunan).
  Future<SubscriptionPurchaseResult> purchasePremium({
    required String uid,
    required BillingCycle billingCycle,
    bool simulateCancel = false,
  });

  /// Memulihkan pembelian sebelumnya (Restore Purchase).
  Future<SubscriptionPurchaseResult> restorePurchases(String uid);

  /// Menandai bahwa halaman Subscription pertama kali sudah dilihat oleh user.
  Future<SubscriptionInfo> markSubscriptionPageSeen(String uid);

  /// Khusus mode development/testing: toggle antara Free, Premium Aktif, atau Premium Expired.
  Future<SubscriptionInfo> toggleMockPlan(
    String uid, {
    SubscriptionPlan? targetPlan,
    SubscriptionStatus? targetStatus,
  });
}

/// Implementasi [MockSubscriptionService] untuk tahap development dan pengujian.
/// Menyimpan data secara lokal di [SharedPreferences] sekaligus menyinkronkan ke
/// dokumen user di Supabase (`public.profiles` dan `auth.users` metadata).
class MockSubscriptionService implements SubscriptionService {
  final SupabaseClient? _injectedClient;

  MockSubscriptionService({SupabaseClient? supabaseClient})
      : _injectedClient = supabaseClient;

  SupabaseClient get _supabase => _injectedClient ?? SupabaseConfig.client;

  static String _prefsKey(String uid) => 'trackie_subscription_$uid';
  static String _seenKey(String uid) => 'trackie_has_seen_sub_$uid';

  @override
  Future<SubscriptionInfo> loadSubscription(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final localSeen = prefs.getBool(_seenKey(uid)) ?? false;

    SubscriptionInfo? localInfo;
    final rawJson = prefs.getString(_prefsKey(uid));
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        localInfo = SubscriptionInfo.fromMap(decoded);
      } catch (e) {
        debugPrint('Error decoding local subscription info: $e');
      }
    }

    // Ambil dari Supabase (tabel profiles & fallback ke userMetadata)
    SubscriptionInfo? remoteInfo;
    try {
      final profileRow = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profileRow != null && profileRow.containsKey('plan')) {
        remoteInfo = SubscriptionInfo.fromMap(profileRow);
      } else {
        final meta = _supabase.auth.currentUser?.userMetadata;
        if (meta != null && meta.containsKey('plan')) {
          remoteInfo = SubscriptionInfo.fromMap(meta);
        }
      }
    } catch (e) {
      debugPrint('Info: fallback to local/metadata subscription state: $e');
      final meta = _supabase.auth.currentUser?.userMetadata;
      if (meta != null && meta.containsKey('plan')) {
        remoteInfo = SubscriptionInfo.fromMap(meta);
      }
    }

    // Gabungkan state remote dan lokal (prioritaskan yang sudah pernah melihat halaman / aktif)
    final mergedHasSeen = localSeen ||
        (localInfo?.hasSeenSubscriptionPage ?? false) ||
        (remoteInfo?.hasSeenSubscriptionPage ?? false);

    final baseInfo = remoteInfo ?? localInfo ?? const SubscriptionInfo();
    final finalInfo = baseInfo.copyWith(hasSeenSubscriptionPage: mergedHasSeen);

    await _saveLocal(uid, finalInfo);
    return finalInfo;
  }

  @override
  Future<SubscriptionInfo> selectFreePlan(String uid) async {
    final current = await loadSubscription(uid);
    // Jika user sebelumnya sudah Premium aktif, jangan timpa status premiumnya, cukup tandai seen.
    final updated = current.isPremiumActive
        ? current.copyWith(hasSeenSubscriptionPage: true)
        : SubscriptionInfo(
            plan: SubscriptionPlan.free,
            status: SubscriptionStatus.active,
            billingCycle: current.billingCycle,
            expiresAt: null,
            autoRenew: false,
            hasSeenSubscriptionPage: true,
          );

    await _persistAll(uid, updated);
    return updated;
  }

  @override
  Future<SubscriptionPurchaseResult> purchasePremium({
    required String uid,
    required BillingCycle billingCycle,
    bool simulateCancel = false,
  }) async {
    // Simulasi loading pembayaran ke gateway Play Store / App Store
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    if (simulateCancel) {
      return const SubscriptionPurchaseResult(
        success: false,
        isCanceled: true,
        message: 'Pembayaran dibatalkan. Kamu belum dikenakan biaya apa pun.',
      );
    }

    final now = DateTime.now();
    final expiresAt = billingCycle == BillingCycle.yearly
        ? DateTime(now.year + 1, now.month, now.day, now.hour, now.minute)
        : now.add(const Duration(days: 30));

    final updated = SubscriptionInfo(
      plan: SubscriptionPlan.premium,
      status: SubscriptionStatus.active,
      billingCycle: billingCycle,
      expiresAt: expiresAt,
      autoRenew: true,
      hasSeenSubscriptionPage: true,
    );

    await _persistAll(uid, updated);

    return SubscriptionPurchaseResult(
      success: true,
      message: billingCycle == BillingCycle.yearly
          ? 'Selamat! Paket Trackie Premium Tahunan kamu sudah aktif.'
          : 'Selamat! Paket Trackie Premium Bulanan kamu sudah aktif.',
      subscriptionInfo: updated,
    );
  }

  @override
  Future<SubscriptionPurchaseResult> restorePurchases(String uid) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final current = await loadSubscription(uid);

    if (current.plan == SubscriptionPlan.premium) {
      final now = DateTime.now();
      final restored = current.copyWith(
        plan: SubscriptionPlan.premium,
        status: SubscriptionStatus.active,
        expiresAt: current.isPastExpiration || current.expiresAt == null
            ? now.add(const Duration(days: 30))
            : current.expiresAt,
        autoRenew: true,
        hasSeenSubscriptionPage: true,
      );
      await _persistAll(uid, restored);
      return SubscriptionPurchaseResult(
        success: true,
        message: 'Pembelian paket Premium berhasil dipulihkan!',
        subscriptionInfo: restored,
      );
    }

    return SubscriptionPurchaseResult(
      success: false,
      message:
          'Tidak ditemukan riwayat langganan Premium aktif pada akun ini.',
      subscriptionInfo: current,
    );
  }

  @override
  Future<SubscriptionInfo> markSubscriptionPageSeen(String uid) async {
    final current = await loadSubscription(uid);
    final updated = current.copyWith(hasSeenSubscriptionPage: true);
    await _persistAll(uid, updated);
    return updated;
  }

  @override
  Future<SubscriptionInfo> toggleMockPlan(
    String uid, {
    SubscriptionPlan? targetPlan,
    SubscriptionStatus? targetStatus,
  }) async {
    final current = await loadSubscription(uid);
    final nextPlan = targetPlan ??
        (current.isPremiumActive
            ? SubscriptionPlan.free
            : SubscriptionPlan.premium);
    final nextStatus = targetStatus ?? SubscriptionStatus.active;

    DateTime? nextExpires;
    if (nextPlan == SubscriptionPlan.premium) {
      if (nextStatus == SubscriptionStatus.expired) {
        nextExpires = DateTime.now().subtract(const Duration(days: 1));
      } else {
        nextExpires = DateTime.now().add(const Duration(days: 30));
      }
    }

    final updated = SubscriptionInfo(
      plan: nextPlan,
      status: nextStatus,
      billingCycle: current.billingCycle,
      expiresAt: nextExpires,
      autoRenew: nextPlan == SubscriptionPlan.premium &&
          nextStatus == SubscriptionStatus.active,
      hasSeenSubscriptionPage: true,
    );

    await _persistAll(uid, updated);
    return updated;
  }

  Future<void> _saveLocal(String uid, SubscriptionInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey(uid), info.hasSeenSubscriptionPage);
      await prefs.setString(_prefsKey(uid), jsonEncode(info.toMap()));
    } catch (e) {
      debugPrint('Warning saving local subscription state: $e');
    }
  }

  Future<void> _persistAll(String uid, SubscriptionInfo info) async {
    await _saveLocal(uid, info);

    // 1. Simpan status has_seen_subscription_page ke tabel public.profiles (diizinkan oleh RLS)
    try {
      await _supabase.from('profiles').update({
        'has_seen_subscription_page': info.hasSeenSubscriptionPage,
      }).eq('id', uid);
    } catch (e) {
      debugPrint('Info saving has_seen_subscription_page to profiles: $e');
    }

    // 2. Sinkronkan plan ke profiles melalui RPC dev_simulate_subscription saat mode debug (BUG-02)
    //    Memastikan kolom profiles.plan sinkron sehingga kuota can_create_or_join_group valid.
    if (kDebugMode) {
      try {
        await _supabase.rpc('dev_simulate_subscription', params: {
          'p_plan': info.plan.value,
          'p_status': info.effectiveStatus.value,
          'p_expires_at': info.expiresAt?.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Info dev_simulate_subscription fallback: $e');
      }
    }

    // 2. Sinkronkan juga ke user_metadata Supabase Auth sebagai cadangan lintas perangkat
    try {
      if (_supabase.auth.currentUser?.id == uid) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'plan': info.plan.value,
              'subscription_status': info.effectiveStatus.value,
              'billing_cycle': info.billingCycle.value,
              'subscription_expires_at': info.expiresAt?.toIso8601String(),
              'auto_renew': info.autoRenew,
              'has_seen_subscription_page': info.hasSeenSubscriptionPage,
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Warning syncing subscription to auth metadata: $e');
    }
  }
}

/// Implementasi produksi [StoreSubscriptionService] untuk Google Play Billing / App Store
/// menggunakan `in_app_purchase` atau RevenueCat (`purchases_flutter`).
///
/// Cara mengaktifkan di produksi:
/// 1. Tambahkan `purchases_flutter` atau `in_app_purchase` di `pubspec.yaml`.
/// 2. Ganti `MockSubscriptionService()` menjadi `StoreSubscriptionService()` di `SubscriptionProvider`.
class StoreSubscriptionService extends MockSubscriptionService {
  @override
  Future<SubscriptionPurchaseResult> purchasePremium({
    required String uid,
    required BillingCycle billingCycle,
    bool simulateCancel = false,
  }) async {
    final productId = billingCycle == BillingCycle.yearly
        ? PlanLimits.yearlyProductId
        : PlanLimits.monthlyProductId;
    debugPrint('Memulai pembelian store untuk productId: $productId');

    // TODO(production): Integrasikan dengan RevenueCat (`Purchases.purchaseStoreProduct`)
    // atau `InAppPurchase.instance.buyNonConsumable(...)`, lalu panggil `super._persistAll`
    // setelah entitlement `PlanLimits.revenueCatEntitlementId` terverifikasi aktif.
    return super.purchasePremium(
      uid: uid,
      billingCycle: billingCycle,
      simulateCancel: simulateCancel,
    );
  }
}
