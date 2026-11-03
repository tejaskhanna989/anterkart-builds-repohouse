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

  /// Bind the device to a signed-in rider (external ID `rider:<id>`).
  static void loginAsRider(int riderId) {
    if (!isEnabled) return;
    try {
      OneSignal.login('rider:$riderId');
      OneSignal.User.addTags({'role': 'rider'});
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
}
