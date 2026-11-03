import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  List<Order> get newOrders => _orders.where((o) => o.status == 'confirmed').toList();
  List<Order> get awaitingOrders => _orders.where((o) => o.status == 'pending').toList();
  List<Order> get activeOrders => _orders.where((o) => o.status == 'preparing' || o.status == 'ready' || o.status == 'out_for_delivery').toList();
  List<Order> get pastOrders => _orders.where((o) => o.status == 'delivered' || o.status == 'cancelled').toList();

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('vendor/orders/list.php', auth: true);
    if (res['success'] == true) {
      _orders = (res['data']['orders'] as List? ?? []).map((j) => Order.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Ids of currently pending orders (for new-order detection).
  Set<int> get pendingIds => _orders.where((o) => o.status == 'pending').map((o) => o.id).toSet();

  Future<Order?> loadDetail(int orderId) async {
    final res = await ApiService.get('vendor/orders/detail.php', auth: true, queryParams: {'order_id': '$orderId'});
    if (res['success'] == true) {
      return Order.fromJson(res['data']['order']);
    }
    return null;
  }

  Future<bool> updateStatus(int orderId, String status) async {
    final res = await ApiService.post('vendor/orders/status.php', body: {'order_id': orderId, 'status': status}, auth: true);
    if (res['success'] == true) {
      await loadOrders();
      return true;
    }
    return false;
  }

  Future<Map<String, int>> loadPrepTime() async {
    final res = await ApiService.get('vendor/settings/processing.php', auth: true);
    if (res['success'] == true) {
      final d = res['data'] as Map? ?? {};
      return {
        'min': int.tryParse('${d['min_processing_mins']}') ?? 15,
        'max': int.tryParse('${d['max_processing_mins']}') ?? 25,
      };
    }
    return {'min': 15, 'max': 25};
  }

  Future<bool> savePrepTime(int min, int max) async {
    final res = await ApiService.post('vendor/settings/processing.php',
        body: {'min_processing_mins': min, 'max_processing_mins': max}, auth: true);
    return res['success'] == true;
  }
}
