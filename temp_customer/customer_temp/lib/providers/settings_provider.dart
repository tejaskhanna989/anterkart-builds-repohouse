import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeSection {
  final String key;
  final String type;
  final String title;
  final String sub;
  final String kicker;
  final bool show;
  final List<String> categories;

  const HomeSection({
    required this.key,
    required this.type,
    required this.title,
    required this.sub,
    required this.kicker,
    required this.show,
    this.categories = const [],
  });

  factory HomeSection.fromJson(Map<String, dynamic> j) {
    final data = (j['data'] as Map<String, dynamic>?) ?? {};
    final names = ((data['categories'] as String?) ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rawShow = j['show'] ?? true;
    return HomeSection(
      key: j['key']?.toString() ?? '',
      type: j['type']?.toString() ?? 'banners',
      title: j['title']?.toString() ?? '',
      sub: j['sub']?.toString() ?? '',
      kicker: j['kicker']?.toString() ?? '',
      show: (rawShow == true || rawShow == 1 || rawShow == '1'),
      categories: names,
    );
  }
}

class SettingsProvider extends ChangeNotifier {
  List<HomeSection> _homeSections = [];
  String _appName = '';

  List<HomeSection> get homeSections => _homeSections;
  bool get sectionConfigAvailable => _homeSections.isNotEmpty;
  String get appName => _appName;

  Future<void> loadHomeSections() async {
    final res = await ApiService.get('settings/store.php');
    if (res['success'] == true) {
      final data = (res['data'] as Map<String, dynamic>?) ?? {};
      final list = (data['app_sections'] as List? ?? []);
      _homeSections =
          list.map((j) => HomeSection.fromJson(j as Map<String, dynamic>)).toList();
      final app = (data['app_settings'] as Map<String, dynamic>?) ?? {};
      _appName = app['app_name']?.toString() ?? '';
      notifyListeners();
    }
  }
}