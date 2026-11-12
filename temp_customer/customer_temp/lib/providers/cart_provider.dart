import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);

  int quantityInCart(int productId) {
    final item = _items.where((i) => i.productId == productId);
    return item.isNotEmpty ? item.first.quantity : 0;
  }

  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('cart/get.php', auth: true);
    if (res['success'] == true) {
      _items = (res['data']['items'] as List? ?? []).map((j) => CartItem.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(int productId, {int quantity = 1}) async {
    final res = await ApiService.post('cart/add.php', body: {'product_id': productId, 'quantity': quantity}, auth: true);
    if (res['success'] == true) {
      await loadCart();
    }
  }

  Future<void> updateQuantity(int cartId, int quantity) async {
    final res = await ApiService.post('cart/update.php', body: {'cart_id': cartId, 'quantity': quantity}, auth: true);
    if (res['success'] == true) {
      await loadCart();
    }
  }

  Future<void> clear() async {
    await ApiService.post('cart/clear.php', auth: true);
    _items = [];
    notifyListeners();
  }
}
