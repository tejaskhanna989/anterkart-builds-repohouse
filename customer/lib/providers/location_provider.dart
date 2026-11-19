import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/delivery_zone.dart';
import '../services/api_service.dart';

class LocationProvider extends ChangeNotifier {
  double? _lat;
  double? _lng;
  String _address = '';
  DeliveryZone? _detectedZone;
  List<DeliveryZone> _zones = [];
  // ignore: prefer_final_fields
  bool _isLoading = false;

  double? get lat => _lat;
  double? get lng => _lng;
  String get address => _address;
  DeliveryZone? get detectedZone => _detectedZone;
  List<DeliveryZone> get zones => _zones;
  bool get isLoading => _isLoading;
  bool get hasLocation => _lat != null && _lng != null && _address.isNotEmpty;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _lat = p.getDouble('user_lat');
    _lng = p.getDouble('user_lng');
    _address = p.getString('user_address') ?? '';
    notifyListeners();
  }

  Future<void> setCoordinates(double lat, double lng, String address) async {
    _lat = lat;
    _lng = lng;
    _address = address;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('user_lat', lat);
    await p.setDouble('user_lng', lng);
    await p.setString('user_address', address);
    notifyListeners();
  }

  /// Detect current location using GPS and update state.
  Future<bool> detectCurrentLocation() async {
    try {
      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Reverse geocode to get address
      String address = '';
      try {
        final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=en&addressdetails=1');
        final client = http.Client();
        final res = await client.get(uri, headers: {'User-Agent': 'Otamzo/1.0'}).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          address = j['display_name'] ?? '';
        }
      } catch (_) {
        address = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }

      await setCoordinates(position.latitude, position.longitude, address);
      return true;
    } catch (e) {
      print('[LocationProvider] Error detecting location: $e');
      return false;
    }
  }

  Future<void> clearLocation() async {
    _lat = null;
    _lng = null;
    _address = '';
    final p = await SharedPreferences.getInstance();
    await p.remove('user_lat');
    await p.remove('user_lng');
    await p.remove('user_address');
    notifyListeners();
  }

  Future<void> loadZones() async {
    final res = await ApiService.get('settings/zones.php');
    if (res['success'] == true) {
      _zones = (res['data']['zones'] as List? ?? []).map((j) => DeliveryZone.fromJson(j)).toList();
      notifyListeners();
    }
  }
}
