import 'package:flutter/services.dart';

/// Bridge to the native alert engine (AlertManager.kt).
///
/// A new order must be impossible to miss: the native side raises the alarm
/// stream to maximum, keeps the CPU awake, posts a full-screen notification and
/// (when allowed) pulls the app to the front — even over the lock screen. The
/// looping sound itself is played by [OrderAlarm]; this class drives the rest.
class AlertService {
  AlertService._();

  static const MethodChannel _channel = MethodChannel('otamzo/alert');

  /// Start the hard-to-miss alert for a new order.
  static Future<void> start({
    required String title,
    required String body,
    int orderId = 0,
  }) async {
    try {
      await _channel.invokeMethod('startAlert', {
        'title': title,
        'body': body,
        'orderId': orderId,
      });
    } catch (_) {
      // Missing channel (e.g. tests) must never crash the order flow.
    }
  }

  /// Stop the alert: cancel the notification, release the wake lock and stop
  /// listening for the screen unlock.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAlert');
    } catch (_) {}
  }

  /// Whether the app may draw over other apps (needed to auto-launch while the
  /// phone is in use).
  static Future<bool> canDrawOverlays() async {
    try {
      return (await _channel.invokeMethod<bool>('canDrawOverlays')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Order ID that caused a native push alert, including on cold app start.
  static Future<int> pendingOrderId() async {
    try {
      return (await _channel.invokeMethod<int>('pendingAlertOrderId')) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Open the system "Display over other apps" screen for this app.
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Ask for the overlay permission only when it is not already granted, so a
  /// new order can jump to the front even while the phone is in use.
  static Future<void> ensureOverlayPermission() async {
    if (await canDrawOverlays()) return;
    await requestOverlayPermission();
  }
}
