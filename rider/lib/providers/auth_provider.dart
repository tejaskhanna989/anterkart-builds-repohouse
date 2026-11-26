import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider.dart';
import '../services/api_service.dart';
import '../services/onesignal_service.dart';

class AuthProvider extends ChangeNotifier {
  Rider? _rider;
  String? _token;
  bool _isLoading = false;
  Future<void>? _initFuture;

  Rider? get rider => _rider;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _rider != null;
  bool get isLoading => _isLoading;

  Future<void> init() => _initFuture ??= _restoreSession();

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('rider_token');
    final rData = prefs.getString('rider_data');
    if (_token != null && rData != null) {
      try {
        _rider = Rider.fromJson(jsonDecode(rData));
        OneSignalService.loginAsRider(_rider!.id);
      } catch (_) {
        _rider = null;
        _token = null;
        await ApiService.clearToken();
      }
    } else {
      _rider = null;
      _token = null;
      await ApiService.clearToken();
    }
    notifyListeners();

    // Cached rider data can contain yesterday's availability. Refresh it from
    // the server before the profile screen is opened so the toggle reflects
    // the effective dated override used by dispatch.
    if (isLoggedIn) {
      await refreshProfile();
    }
  }

  Future<void> _persistRider(Rider rider) async {
    _rider = rider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_data', jsonEncode({
      'id': rider.id,
      'name': rider.name,
      'email': rider.email,
      'phone': rider.phone,
      'vehicle': rider.vehicle,
      'status': rider.status,
      'available': rider.available,
      'lat': rider.lat,
      'lng': rider.lng,
    }));
  }

  /// Refresh the rider profile and effective availability from the server.
  Future<bool> refreshProfile() async {
    if (_token == null) return false;
    final res = await ApiService.get('rider/auth/profile.php', auth: true);
    if (res['success'] != true) return false;
    final raw = res['data']?['rider'];
    if (raw is! Map) return false;
    try {
      final rider = Rider.fromJson(Map<String, dynamic>.from(raw));
      await _persistRider(rider);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Apply the authoritative effective availability returned by an availability
  /// mutation immediately, without waiting for another profile request.
  Future<void> setEffectiveAvailability(bool available) async {
    final rider = _rider;
    if (rider == null) return;
    await _persistRider(rider.copyWith(available: available ? 1 : 0));
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.post('rider/auth/login.php',
        body: {'email': email, 'password': password});
    _isLoading = false;
    if (res['success'] == true) {
      _rider = Rider.fromJson(res['data']['rider']);
      _token = res['data']['token'];
      await ApiService.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rider_data', jsonEncode(res['data']['rider']));
      OneSignalService.loginAsRider(_rider!.id);
      await OneSignalService.requestPermission();
      notifyListeners();
      return null;
    }
    notifyListeners();
    return res['message'] ?? 'Login failed';
  }

  Future<void> logout() async {
    _rider = null;
    _token = null;
    await ApiService.clearToken();
    OneSignalService.logout();
    notifyListeners();
  }
}
