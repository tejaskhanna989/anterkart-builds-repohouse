import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('customer_data');
  }

  static Map<String, String> _headers({String? token}) {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = false, Map<String, String>? queryParams}) async {
    try {
      String url = '${ApiConfig.baseUrl}/$path';
      final qs = <String, String>{'store': ApiConfig.store, ...?queryParams};
      final q = qs.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      if (q.isNotEmpty) url += '?$q';
      String? token;
      if (auth) token = await getToken();
      final response = await http.get(Uri.parse(url), headers: _headers(token: token)).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) return {'success': false, 'message': 'Server error', 'data': {}};
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      String url = '${ApiConfig.baseUrl}/$path';
      url += (path.contains('?') ? '&' : '?') + 'store=' + Uri.encodeComponent(ApiConfig.store);
      String? token;
      if (auth) token = await getToken();
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) return {'success': false, 'message': 'Server error', 'data': {}};
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }
}
