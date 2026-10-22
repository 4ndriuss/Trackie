import 'package:flutter/foundation.dart';
import '../services/group_service.dart';
import '../models/group_model.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService = GroupService();

  GroupModel? _activeGroup;
  bool _isLoading = false;
  String? _error;

  GroupModel? get activeGroup => _activeGroup;
  bool get isLoading => _isLoading;
  bool get hasActiveGroup => _activeGroup != null;
  String? get error => _error;

  // Create a new group
  Future<bool> createGroup({
    required String name,
    required String type,
    required String destination,
    required String hostUid,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _activeGroup = await _groupService.createGroup(
        name: name,
        type: type,
        destination: destination,
        hostUid: hostUid,
      );
      _isLoading = false;
      notifyListeners();
      return _activeGroup != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Join a group
  Future<bool> joinGroup({
    required String inviteCode,
    required String uid,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _activeGroup = await _groupService.joinGroup(
        inviteCode: inviteCode,
        uid: uid,
      );
      _isLoading = false;
      notifyListeners();
      return _activeGroup != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Leave a group
  Future<void> leaveGroup({required String uid}) async {
    if (_activeGroup == null) return;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _groupService.leaveGroup(groupId: _activeGroup!.id, uid: uid);
      _activeGroup = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mengakhiri grup perjalanan (khusus Host).
  Future<void> endGroup() async {
    if (_activeGroup == null) return;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _groupService.endGroup(_activeGroup!.id);
      _activeGroup = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mengosongkan grup aktif secara lokal saat perjalanan diakhiri atau user logout.
  void clearActiveGroup() {
    _activeGroup = null;
    notifyListeners();
  }

  // Load active group for user
  Future<void> loadActiveGroup(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _activeGroup = await _groupService.getActiveGroupForUser(uid);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memperbarui tujuan aktif di state lokal grup saat Host mengubah tujuan.
  void updateActiveGroupDestination(String destination) {
    if (_activeGroup == null) return;
    _activeGroup = _activeGroup!.copyWith(destination: destination);
    notifyListeners();
  }

  /// Memperbarui daftar UID anggota pada grup aktif saat ada teman yang bergabung/keluar.
  void updateActiveGroupMembers(List<String> memberUids) {
    if (_activeGroup == null) return;
    if (listEquals(_activeGroup!.memberUids, memberUids)) return;
    _activeGroup = _activeGroup!.copyWith(memberUids: memberUids);
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
