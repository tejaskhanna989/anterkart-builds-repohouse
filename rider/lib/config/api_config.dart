class ApiConfig {
  static const String baseUrl = 'https://otamzo.com/api/mobile';
  static const String fallbackUrl = 'https://otamzo.com/api/mobile';

  // OneSignal push (same OneSignal app as the customer app; riders are
  // addressed as external ID `rider:<id>`). Native RiderApplication
  // initializes with the same id; the Dart wrapper re-uses it.
  static const String onesignalAppId = '99648958-99e9-4e1e-a015-96e4b512af7d';

  // Pickup point of the store, used as a fallback when an offer payload
  // carries no coordinates of its own. Update when the store moves.
  static const double storeLat = 24.853545;
  static const double storeLng = 74.620191;

  // Only offers within this radius of the rider ring the phone.
  static const double nearbyRadiusKm = 1.0;
}
