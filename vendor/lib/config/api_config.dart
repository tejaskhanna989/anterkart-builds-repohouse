class ApiConfig {
  static const String baseUrl = 'https://otamzo.com/api/mobile';
  static const String fallbackUrl = 'https://otamzo.com/api/mobile';

  // OneSignal push (same OneSignal app as customer/rider; vendors are
  // addressed as external ID `vendor:<tenant_id>`). Native VendorApplication
  // initializes with the same id; the Dart wrapper re-uses it.
  static const String onesignalAppId = '99648958-99e9-4e1e-a015-96e4b512af7d';
}
