import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await ApiService.get('categories/list.php', auth: true);
    if (res['success'] == true) {
      _categories = (res['data']['categories'] as List? ?? []).map((j) => Category.fromJson(j)).toList();
    } else {
      _error = res['message'];
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearCategories() {
    _categories = [];
    notifyListeners();
  }
}