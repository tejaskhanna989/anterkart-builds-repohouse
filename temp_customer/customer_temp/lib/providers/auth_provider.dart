import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/onesignal_service.dart';

class AuthProvider extends ChangeNotifier {
  Customer? _customer;
  String? _token;
  bool _isLoading = false;

  Customer? get customer => _customer;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _customer != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final cData = prefs.getString('customer_data');
    if (_token != null && cData != null) {
      try {
        _customer = Customer.fromJson(jsonDecode(cData));
        _setOneSignalLogin(_customer!.id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.post('auth/login.php', body: {'email': email, 'password': password});
    _isLoading = false;
    if (res['success'] == true) {
      _customer = Customer.fromJson(res['data']['customer']);
      _token = res['data']['token'];
      await ApiService.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_data', jsonEncode(res['data']['customer']));
      _setOneSignalLogin(_customer!.id);
      await OneSignalService.requestPermission();
      notifyListeners();
      return null;
    }
    notifyListeners();
    return res['message'] ?? 'Login failed';
  }

  Future<String?> register(String name, String email, String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.post('auth/register.php', body: {'name': name, 'email': email, 'phone': phone, 'password': password});
    _isLoading = false;
    if (res['success'] == true) {
      _customer = Customer.fromJson(res['data']['customer']);
      _token = res['data']['token'];
      await ApiService.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_data', jsonEncode(res['data']['customer']));
      _setOneSignalLogin(_customer!.id);
      await OneSignalService.requestPermission();
      notifyListeners();
      return null;
    }
    notifyListeners();
    return res['message'] ?? 'Registration failed';
  }

  Future<void> logout() async {
    await ApiService.post('auth/logout.php', auth: true);
    _customer = null;
    _token = null;
    await ApiService.clearToken();
    _setOneSignalLogout();
    notifyListeners();
  }

  void _setOneSignalLogin(int customerId) {
    OneSignalService.loginAsCustomer(customerId);
  }

  void _setOneSignalLogout() {
    OneSignalService.logout();
  }

  Future<void> updateProfile({String? name, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    final res = await ApiService.post('auth/profile.php', body: body, auth: true);
    if (res['success'] == true) {
      _customer = Customer.fromJson(res['data']['customer']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_data', jsonEncode(res['data']['customer']));
      notifyListeners();
    }
  }
}
