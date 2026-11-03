import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unread = 0;
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unread => _unread;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('notifications/list.php', auth: true);
    if (res['success'] == true) {
      _notifications = (res['data']['notifications'] as List? ?? []).map((j) => AppNotification.fromJson(j)).toList();
      _unread = res['data']['unread'] is int ? res['data']['unread'] : int.tryParse('${res['data']['unread'] ?? 0}') ?? 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await ApiService.post('notifications/mark_read.php', body: {'ids': ids}, auth: true);
  }

  Future<void> markAllRead() async {
    await ApiService.post('notifications/mark_read.php', body: {}, auth: true);
  }
}