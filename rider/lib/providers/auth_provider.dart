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

  Rider? get rider => _rider;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _rider != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('rider_token');
    final rData = prefs.getString('rider_data');
    if (_token != null && rData != null) {
      try {
        _rider = Rider.fromJson(jsonDecode(rData));
        OneSignalService.loginAsRider(_rider!.id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.post('rider/auth/login.php', body: {'email': email, 'password': password});
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
