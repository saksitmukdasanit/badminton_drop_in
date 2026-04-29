import 'package:flutter/material.dart';
import 'package:badminton/shared/api_provider.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // ดึงจำนวนที่ยังไม่อ่านจาก Backend
  Future<void> fetchUnreadCount() async {
    try {
      final response = await ApiProvider().get('/Notifications/unread-count');
      if (response['status'] == 200) {
        _unreadCount = response['data'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch unread count: $e');
    }
  }

  void increment() {
    _unreadCount++;
    notifyListeners();
  }

  void decrement() {
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
  }

  void clear() {
    _unreadCount = 0;
    notifyListeners();
  }
}