import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await ApiService.get('vendor/products/list.php', auth: true);
    if (res['success'] == true) {
      _products = (res['data']['products'] as List? ?? []).map((j) => Product.fromJson(j)).toList();
    } else {
      _error = res['message'];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> toggleStatus(int productId) async {
    final res = await ApiService.post('vendor/products/toggle.php', body: {'product_id': productId}, auth: true);
    if (res['success'] == true) {
      await loadProducts();
      return true;
    }
    return false;
  }

  Future<String?> saveProduct({
    int? productId,
    required String name,
    required double price,
    double? mrp,
    int? categoryId,
    String description = '',
    int stock = 0,
    String status = 'active',
    int isVeg = 0,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'price': price,
      'mrp': mrp ?? price,
      'description': description,
      'stock': stock,
      'status': status,
      'is_veg': isVeg,
    };
    if (categoryId != null) body['category_id'] = categoryId;
    if (productId != null) body['product_id'] = productId;
    final res = await ApiService.post('vendor/products/save.php', body: body, auth: true);
    if (res['success'] == true) {
      await loadProducts();
      return null;
    }
    return res['message'] ?? 'Save failed';
  }
}
