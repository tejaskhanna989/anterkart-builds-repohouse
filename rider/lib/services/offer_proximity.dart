import 'dart:math';

/// Decides whether a delivery offer is close enough to the rider to be
/// worth ringing for.
///
/// The requirement is "riders within 1 km of the store ring when the order
/// is prepared". The distance check is done on the device so it works even
/// when the server sends the offer to every rider of the tenant.
///
/// If the rider position or the store position is unknown the offer is
/// treated as nearby — a missing coordinate must never swallow an alert.
class OfferProximity {
  OfferProximity._();

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180.0;

  static double? _coord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// The pickup point of the offer, or null when the payload has no
  /// coordinates at all.
  ///
  /// The API has used several spellings over time, so all the known ones
  /// are checked.
  static ({double lat, double lng})? storePoint(Map<String, dynamic> offer) {
    final store = _map(offer['store']) ?? _map(offer['vendor']) ?? _map(offer['tenant']);
    final lat = _coord(store?['lat'] ?? store?['latitude'] ??
        offer['store_lat'] ?? offer['store_latitude'] ?? offer['pickup_lat'] ??
        offer['pickup_latitude'] ?? offer['vendor_lat'] ?? offer['tenant_lat'] ??
        offer['lat']);
    final lng = _coord(store?['lng'] ?? store?['lon'] ?? store?['longitude'] ??
        offer['store_lng'] ?? offer['store_lngitude'] ?? offer['pickup_lng'] ??
        offer['pickup_lngitude'] ?? offer['vendor_lng'] ?? offer['tenant_lng'] ??
        offer['lng']);
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return (lat: lat, lng: lng);
  }

  /// Distance in km between the rider and the offer, or null when it cannot
  /// be computed (no GPS yet, no store coordinates, ...).
  static double? distanceToOffer(
    Map<String, dynamic> offer, {
    required double? riderLat,
    required double? riderLng,
    double? fallbackLat,
    double? fallbackLng,
  }) {
    if (riderLat == null || riderLng == null) return null;
    final point = storePoint(offer) ??
        (fallbackLat != null && fallbackLng != null ? (lat: fallbackLat, lng: fallbackLng) : null);
    if (point == null) return null;
    return distanceKm(riderLat, riderLng, point.lat, point.lng);
  }

  /// True when the offer should ring the phone.
  ///
  /// [radiusKm] defaults to 1 km. An unknown distance counts as "nearby" so
  /// that the rider is never left without an alert because of a missing
  /// coordinate.
  static bool shouldRing(
    Map<String, dynamic> offer, {
    required double? riderLat,
    required double? riderLng,
    double radiusKm = 1.0,
    double? fallbackLat,
    double? fallbackLng,
  }) {
    final distance = distanceToOffer(
      offer,
      riderLat: riderLat,
      riderLng: riderLng,
      fallbackLat: fallbackLat,
      fallbackLng: fallbackLng,
    );
    if (distance == null) return true;
    return distance <= radiusKm;
  }
}
