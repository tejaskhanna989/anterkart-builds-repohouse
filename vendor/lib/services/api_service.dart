import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static String? _token;

  static Future<String?> getToken() async {
    return _token;
  }

  static Future<void> setToken(String? token) async {
    _token = token;
  }

  static Future<void> clearToken() async {
    _token = null;
  }

  static Map<String, String> _headers({String? token}) {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = false, Map<String, String>? queryParams}) async {
    try {
      String url = '${ApiConfig.baseUrl}/$path';
      if (queryParams != null && queryParams.isNotEmpty) {
        final qs = queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
        url += '?$qs';
      }
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
      String? token;
      if (auth) token = await getToken();
      final response = await http.post(Uri.parse(url), headers: _headers(token: token), body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) return {'success': false, 'message': 'Server error', 'data': {}};
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }
}
