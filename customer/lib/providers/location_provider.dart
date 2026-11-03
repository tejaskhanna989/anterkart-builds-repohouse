import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
