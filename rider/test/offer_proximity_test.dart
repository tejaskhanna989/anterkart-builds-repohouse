import 'package:flutter_test/flutter_test.dart';
import 'package:food_multi_rider/services/offer_proximity.dart';

void main() {
  group('OfferProximity.distanceKm', () {
    test('is zero for the same point', () {
      expect(
        OfferProximity.distanceKm(24.853545, 74.620191, 24.853545, 74.620191),
        closeTo(0, 0.0001),
      );
    });

    test('matches a known distance', () {
      // ~111.2 km per degree of latitude at the equator.
      final d = OfferProximity.distanceKm(0, 0, 1, 0);
      expect(d, closeTo(111.19, 0.5));
    });

    test('is symmetric', () {
      final a = OfferProximity.distanceKm(24.853545, 74.620191, 24.863545, 74.620191);
      final b = OfferProximity.distanceKm(24.863545, 74.620191, 24.853545, 74.620191);
      expect(a, closeTo(b, 0.000001));
    });
  });

  group('OfferProximity.storePoint', () {
    test('reads store_lat / store_lng', () {
      final p = OfferProximity.storePoint({'store_lat': 24.85, 'store_lng': 74.62});
      expect(p, isNotNull);
      expect(p!.lat, 24.85);
      expect(p.lng, 74.62);
    });

    test('reads a nested store object', () {
      final p = OfferProximity.storePoint({
        'store': {'lat': '24.85', 'lng': '74.62'},
      });
      expect(p, isNotNull);
      expect(p!.lat, 24.85);
      expect(p.lng, 74.62);
    });

    test('returns null when there is no coordinate', () {
      expect(OfferProximity.storePoint({'offer_id': 7}), isNull);
    });

    test('ignores a 0,0 coordinate', () {
      expect(OfferProximity.storePoint({'store_lat': 0, 'store_lng': 0}), isNull);
    });
  });

  group('OfferProximity.shouldRing', () {
    test('rings for an offer inside the 1 km radius', () {
      // ~111 m north of the store.
      final offer = {'store_lat': 24.853545, 'store_lng': 74.620191};
      expect(
        OfferProximity.shouldRing(offer, riderLat: 24.854545, riderLng: 74.620191),
        isTrue,
      );
    });

    test('does not ring for an offer outside the 1 km radius', () {
      final offer = {'store_lat': 24.853545, 'store_lng': 74.620191};
      expect(
        OfferProximity.shouldRing(offer, riderLat: 24.873545, riderLng: 74.620191),
        isFalse,
      );
    });

    test('rings when the rider position is unknown', () {
      expect(
        OfferProximity.shouldRing({'offer_id': 1}, riderLat: null, riderLng: null),
        isTrue,
      );
    });

    test('falls back to the configured store point', () {
      final offer = {'offer_id': 1};
      expect(
        OfferProximity.shouldRing(
          offer,
          riderLat: 24.853545,
          riderLng: 74.620191,
          fallbackLat: 24.853545,
          fallbackLng: 74.620191,
        ),
        isTrue,
      );
    });
  });
}
