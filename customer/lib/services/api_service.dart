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

  static Map<String, String> _headers({String? token, String contentType = 'application/json'}) {
    final h = {'Content-Type': contentType, 'Accept': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Encode a request body as `application/x-www-form-urlencoded`.
  ///
  /// The live host intermittently delivers an EMPTY `php://input` to the
  /// origin, which makes every JSON POST look like "no parameters were
  /// sent" (login fails, orders are not created, ...). Form encoded bodies
  /// are parsed by PHP into `$_POST` and keep working in that situation,
  /// while still being read correctly when `php://input` is healthy.
  /// Nested values are JSON encoded so nothing is silently dropped.
  static String? _encodeBody(Map<String, dynamic>? body) {
    if (body == null) return null;
    return body.entries
        .where((e) => e.value != null)
        .map((e) {
          final v = e.value;
          final value = (v is Map || v is List) ? jsonEncode(v) : '$v';
          return '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(value)}';
        })
        .join('&');
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
        headers: _headers(token: token, contentType: 'application/x-www-form-urlencoded'),
        body: _encodeBody(body),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) return {'success': false, 'message': 'Server error', 'data': {}};
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }
}
