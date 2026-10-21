// File: lib/providers/subscription_provider.dart
// State management (Provider / ChangeNotifier) untuk fitur Subscription Trackie.

import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../services/group_service.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  final GroupService _groupService;

  SubscriptionProvider({
    SubscriptionService? subscriptionService,
    GroupService? groupService,
  })  : _subscriptionService = subscriptionService ?? MockSubscriptionService(),
        _groupService = groupService ?? GroupService();

  String? _currentUid;
  SubscriptionInfo _subscription = const SubscriptionInfo();
  int _usedGroupsCount = 0;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  SubscriptionInfo get subscription => _subscription;
  SubscriptionPlan get currentPlan => _subscription.effectivePlan;
  SubscriptionStatus get subscriptionStatus => _subscription.effectiveStatus;
  BillingCycle get billingCycle => _subscription.billingCycle;
  DateTime? get expiresAt => _subscription.expiresAt;
  bool get autoRenew => _subscription.autoRenew;
  bool get isPremium => _subscription.isPremiumActive;
  bool get isPremiumExpired => _subscription.isPremiumExpired;
  bool get hasSeenSubscriptionPage => _subscription.hasSeenSubscriptionPage;

  int get maxGroups => _subscription.maxGroups;
  int get usedGroupsCount => _usedGroupsCount;
  int get remainingGroups => (maxGroups - _usedGroupsCount).clamp(0, maxGroups);
  bool get canCreateOrJoinGroup => _usedGroupsCount < maxGroups;
  String get groupUsageText => '$_usedGroupsCount / $maxGroups grup terpakai';

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Inisialisasi atau sinkronkan data langganan & pemakaian grup untuk user yang login.
  Future<void> initializeForUser(String? uid, {bool forceRefresh = false}) async {
    if (uid == null || uid.isEmpty) {
      _currentUid = null;
      _subscription = const SubscriptionInfo();
      _usedGroupsCount = 0;
      _isInitialized = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_currentUid == uid && _isInitialized && !forceRefresh) {
      await refreshGroupUsage(uid);
      return;
    }

    _currentUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _subscriptionService.loadSubscription(uid),
        _groupService.getUserGroupCount(uid),
      ]);
      _subscription = results[0] as SubscriptionInfo;
      _usedGroupsCount = results[1] as int;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing SubscriptionProvider: $e');
      _errorMessage = 'Gagal memuat status langganan.';
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memperbarui jumlah grup yang telah dipakai oleh user dari database.
  Future<void> refreshGroupUsage([String? uid]) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null || targetUid.isEmpty) return;

    try {
      final count = await _groupService.getUserGroupCount(targetUid);
      if (_usedGroupsCount != count) {
        _usedGroupsCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing group usage: $e');
    }
  }

  /// Menambah hitungan penggunaan grup secara optimistik setelah buat/gabung grup berhasil.
  void onGroupCreatedOrJoined([String? uid]) {
    _usedGroupsCount += 1;
    notifyListeners();
    refreshGroupUsage(uid);
  }

  /// User menekan "Continue as Free" di halaman Subscription.
  Future<bool> continueAsFree(String uid) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _subscription = await _subscriptionService.selectFreePlan(uid);
      _currentUid = uid;
      _isInitialized = true;
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan pilihan paket Free.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// User menekan tombol "Berlangganan" untuk membeli paket Premium.
  Future<SubscriptionPurchaseResult> subscribePremium({
    required String uid,
    required BillingCycle billingCycle,
    bool simulateCancel = false,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _subscriptionService.purchasePremium(
        uid: uid,
        billingCycle: billingCycle,
        simulateCancel: simulateCancel,
      );

      if (result.subscriptionInfo != null) {
        _subscription = result.subscriptionInfo!;
      }
      if (!result.success) {
        _errorMessage = result.message;
      }
      _currentUid = uid;
      _isInitialized = true;
      return result;
    } catch (e) {
      final msg = 'Terjadi kesalahan saat memproses pembayaran: $e';
      _errorMessage = msg;
      return SubscriptionPurchaseResult(
        success: false,
        message: msg,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memulihkan pembelian sebelumnya ("Restore Purchase").
  Future<SubscriptionPurchaseResult> restorePurchases(String uid) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _subscriptionService.restorePurchases(uid);
      if (result.subscriptionInfo != null) {
        _subscription = result.subscriptionInfo!;
      }
      if (!result.success) {
        _errorMessage = result.message;
      }
      return result;
    } catch (e) {
      const msg = 'Gagal memulihkan pembelian. Silakan coba lagi.';
      _errorMessage = msg;
      return const SubscriptionPurchaseResult(
        success: false,
        message: msg,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Khusus mode development/testing: toggle antara Free, Premium Aktif, dan Premium Expired.
  Future<SubscriptionInfo> toggleMockPlan(
    String uid, {
    SubscriptionPlan? targetPlan,
    SubscriptionStatus? targetStatus,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _subscription = await _subscriptionService.toggleMockPlan(
        uid,
        targetPlan: targetPlan,
        targetStatus: targetStatus,
      );
      await refreshGroupUsage(uid);
      return _subscription;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Khusus mode development/testing: simulasi jumlah grup terpakai.
  void setMockUsedGroupsCount(int count) {
    _usedGroupsCount = count < 0 ? 0 : count;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
