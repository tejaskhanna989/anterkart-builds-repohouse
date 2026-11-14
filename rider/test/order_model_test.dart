import 'package:flutter_test/flutter_test.dart';
import 'package:food_multi_rider/models/order.dart';

void main() {
  group('Rider Order.fromJson - live API shapes', () {
    test('reads rider_lat / rider_lng columns', () {
      final o = Order.fromJson({
        'id': 38,
        'order_number': 'AK20261114A2A31E',
        'rider_lat': '24.8600000',
        'rider_lng': '74.6300000',
      });
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
    });

    test('reads rider_location as a "lat, lng" string', () {
      final o = Order.fromJson({
        'id': 38,
        'rider_location': '24.86, 74.63',
      });
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
    });

    test('reads a nested rider object', () {
      final o = Order.fromJson({
        'id': 38,
        'rider': {'lat': 24.86, 'lng': 74.63},
      });
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
    });

    test('reads delivery_lat / delivery_lng as strings', () {
      final o = Order.fromJson({
        'id': 38,
        'delivery_lat': '24.8535000',
        'delivery_lng': '74.6201000',
      });
      expect(o.deliveryLat, 24.8535);
      expect(o.deliveryLng, 74.6201);
    });

    test('reads the store map', () {
      final o = Order.fromJson({
        'id': 38,
        'store': {'lat': 24.853545, 'lng': 74.620191},
      });
      expect(o.storeLat, 24.853545);
      expect(o.storeLng, 74.620191);
    });

    test('treats a missing rider position as null', () {
      final o = Order.fromJson({
        'id': 38,
        'rider_lat': null,
        'rider_lng': null,
        'rider_location': null,
        'delivery_boy_id': null,
      });
      expect(o.riderLat, isNull);
      expect(o.riderLng, isNull);
    });

    test('treats a 0,0 rider position as null', () {
      final o = Order.fromJson({'id': 38, 'rider_lat': 0, 'rider_lng': 0});
      expect(o.riderLat, isNull);
      expect(o.riderLng, isNull);
    });
  });
}
