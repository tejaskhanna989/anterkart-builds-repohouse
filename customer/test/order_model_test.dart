import 'package:flutter_test/flutter_test.dart';
import 'package:food_multi_customer/models/order.dart';

void main() {
  group('Customer Order.fromJson - live API shapes', () {
    test('reads rider_lat / rider_lng columns', () {
      final o = Order.fromJson({
        'id': 38,
        'order_number': 'AK20261114A2A31E',
        'rider_lat': '24.8600000',
        'rider_lng': '74.6300000',
        'rider_name': 'Ravi',
        'rider_phone': '9999999999',
      });
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
      expect(o.riderName, 'Ravi');
      expect(o.riderPhone, '9999999999');
    });

    test('reads rider_location as a "lat, lng" string', () {
      final o = Order.fromJson({'id': 38, 'rider_location': '24.86, 74.63'});
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
    });

    test('reads a nested rider object', () {
      final o = Order.fromJson({
        'id': 38,
        'rider': {'lat': 24.86, 'lng': 74.63, 'name': 'Ravi', 'phone': '9999999999'},
      });
      expect(o.riderLat, 24.86);
      expect(o.riderLng, 74.63);
      expect(o.riderName, 'Ravi');
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

    test('treats a missing rider position as null', () {
      final o = Order.fromJson({'id': 38, 'rider_location': null});
      expect(o.riderLat, isNull);
      expect(o.riderLng, isNull);
    });
  });
}
