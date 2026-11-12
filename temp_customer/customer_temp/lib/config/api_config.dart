class ApiConfig {
  static const String baseUrl = 'https://otamzo.com/api/mobile';
  static const String fallbackUrl = 'https://otamzo.com/api/mobile';

  // OneSignal push. Set to your app id (dashboard -> Settings -> Keys & IDs).
  // Native Application.onCreate initializes with the same id; the Dart
  // wrapper below re-uses it for login/tags/permission.
  static const String onesignalAppId = '99648958-99e9-4e1e-a015-96e4b512af7d';

  // Marketplace mode: 'all' mixes every vendor's products and reads the
  // platform-level config (marketplace_settings). Pass a store slug to scope.
  static const String store = 'all';
}
