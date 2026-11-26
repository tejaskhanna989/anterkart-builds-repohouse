import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('rider_token');
    return _token;
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('rider_token', token);
    } else {
      await prefs.remove('rider_token');
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rider_token');
    await prefs.remove('rider_data');
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
  /// sent". Form encoded bodies are parsed by PHP into `$_POST` and keep
  /// working in that situation. Nested values are JSON encoded so nothing is
  /// silently dropped.
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
      if (queryParams != null && queryParams.isNotEmpty) {
        final qs = queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
        url += '?$qs';
      }
      String? token;
      if (auth) token = await getToken();
      final response = await http.get(Uri.parse(url), headers: _headers(token: token)).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        try {
          final errorBody = jsonDecode(response.body);
          return {'success': false, 'message': errorBody['message'] ?? 'Request failed with status ${response.statusCode}', 'data': {}, 'statusCode': response.statusCode};
        } catch (_) {
          return {'success': false, 'message': 'Request failed with status ${response.statusCode}', 'data': {}, 'statusCode': response.statusCode};
        }
      }
      return jsonDecode(response.body);
    } catch (e) {
      // Log detailed error for debugging
      print('[ApiService] POST error: $e');
      print('[ApiService] Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException')) {
        return {'success': false, 'message': 'Connection failed. Check internet connection.', 'data': {}};
      } else if (e.toString().contains('TimeoutException')) {
        return {'success': false, 'message': 'Request timed out. Server may be slow.', 'data': {}};
      } else if (e.toString().contains('HttpException')) {
        return {'success': false, 'message': 'Server error. Please try again.', 'data': {}};
      } else if (e.toString().contains('FormatException')) {
        return {'success': false, 'message': 'Invalid server response.', 'data': {}};
      }
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      String url = '${ApiConfig.baseUrl}/$path';
      String? token;
      if (auth) token = await getToken();
      final response = await http.post(Uri.parse(url), headers: _headers(token: token, contentType: 'application/x-www-form-urlencoded'), body: _encodeBody(body)).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        try {
          final errorBody = jsonDecode(response.body);
          return {'success': false, 'message': errorBody['message'] ?? 'Request failed with status ${response.statusCode}', 'data': {}, 'statusCode': response.statusCode};
        } catch (_) {
          return {'success': false, 'message': 'Request failed with status ${response.statusCode}', 'data': {}, 'statusCode': response.statusCode};
        }
      }
      return jsonDecode(response.body);
    } catch (e) {
      // Log detailed error for debugging
      print('[ApiService] POST error: $e');
      print('[ApiService] Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException')) {
        return {'success': false, 'message': 'Connection failed. Check internet connection.', 'data': {}};
      } else if (e.toString().contains('TimeoutException')) {
        return {'success': false, 'message': 'Request timed out. Server may be slow.', 'data': {}};
      } else if (e.toString().contains('HttpException')) {
        return {'success': false, 'message': 'Server error. Please try again.', 'data': {}};
      } else if (e.toString().contains('FormatException')) {
        return {'success': false, 'message': 'Invalid server response.', 'data': {}};
      }
      return {'success': false, 'message': 'Network error: $e', 'data': {}};
    }
  }
}
