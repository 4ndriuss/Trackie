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
  Future<bool> createGroup({required String name, required String type, required String hostUid}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      _activeGroup = await _groupService.createGroup(name: name, type: type, hostUid: hostUid);
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
  Future<bool> joinGroup({required String inviteCode, required String uid}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      _activeGroup = await _groupService.joinGroup(inviteCode: inviteCode, uid: uid);
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
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
