import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/api_config.dart';

/// Centralized wrapper for every OneSignal SDK interaction in this app.
///
/// No other Dart file may import `onesignal_flutter` or call the OneSignal
/// SDK directly — route all push/identity calls through this class so SDK
/// upgrades and behavior changes stay in one place.
class OneSignalService {
  OneSignalService._();

  static bool get isEnabled => ApiConfig.onesignalAppId.isNotEmpty;

  /// Initialize the SDK. Safe to call when push is disabled (no-op).
  /// Must run before any other OneSignal call.
  static void initialize() {
    if (!isEnabled) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      OneSignal.initialize(ApiConfig.onesignalAppId);
    } catch (_) {}
  }

  /// Bind the device to a signed-in vendor store (external ID `vendor:<tenantId>`).
  static void loginAsVendor(int tenantId) {
    if (!isEnabled) return;
    try {
      OneSignal.login('vendor:$tenantId');
      OneSignal.User.addTags({'role': 'vendor'});
    } catch (_) {}
  }

  static void logout() {
    if (!isEnabled) return;
    try {
      OneSignal.logout();
    } catch (_) {}
  }

  static Future<void> requestPermission() async {
    if (!isEnabled) return;
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (_) {}
  }

  /// Fired when a push arrives while the app is open. Home wires this to
  /// refresh orders and ring the new-order alarm.
  static void Function()? onForegroundPush;

  /// Fired when the user taps a push notification. Home wires this to open
  /// the Orders tab.
  static void Function()? onPushClick;

  static bool _listenersAdded = false;

  /// Register foreground + click handlers. Safe to call more than once.
  static void addListeners() {
    if (!isEnabled || _listenersAdded) return;
    _listenersAdded = true;
    try {
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        try {
          event.notification.display();
        } catch (_) {}
        try {
          onForegroundPush?.call();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      OneSignal.Notifications.addClickListener((event) {
        try {
          onPushClick?.call();
        } catch (_) {}
      });
    } catch (_) {}
  }
}
