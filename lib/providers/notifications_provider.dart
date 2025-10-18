import 'package:flutter/material.dart';
import '../services/APIService.dart';

class NotificationsProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> refresh({int? userId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await APIService().fetchNotifications(userId: userId, unread: true);
      _unreadCount = list.length;
    } catch (e) {
      _error = e.toString();
      _unreadCount = 0;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    final result = await APIService().markNotificationRead(notificationId);
    if (result) {
      // decrement but don't go negative
      if (_unreadCount > 0) _unreadCount = _unreadCount - 1;
      notifyListeners();
    }
    return result;
  }

  /// Clear provider state (used during global logout)
  void clear() {
    _unreadCount = 0;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
