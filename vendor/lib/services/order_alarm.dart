import 'dart:async';

/// Placeholder alarm for new vendor orders (audio removed for build compatibility).
class OrderAlarm {
  OrderAlarm._();
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    _ringing = false;
  }

  static Future<void> stop() async {
    _ringing = false;
  }
}
