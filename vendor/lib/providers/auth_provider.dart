import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../services/onesignal_service.dart';

class AuthProvider extends ChangeNotifier {
  Vendor? _vendor;
  String? _token;
  bool _isLoading = false;

  Vendor? get vendor => _vendor;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _vendor != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _token = null;
    _vendor = null;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.post('vendor/auth/login.php', body: {'email': email, 'password': password});
    _isLoading = false;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      _vendor = Vendor.fromJson(data['vendor'], data['tenant']);
      _token = data['token'];
      await ApiService.setToken(_token);
      OneSignalService.loginAsVendor(_vendor!.tenantId);
      await OneSignalService.requestPermission();
      notifyListeners();
      return null;
    }
    notifyListeners();
    return res['message'] ?? 'Login failed';
  }

  Future<void> logout() async {
    _vendor = null;
    _token = null;
    await ApiService.clearToken();
    OneSignalService.logout();
    notifyListeners();
  }
}
