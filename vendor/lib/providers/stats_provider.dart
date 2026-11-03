import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StatsProvider extends ChangeNotifier {
  double todayRevenue = 0;
  int todayOrders = 0;
  int pendingOrders = 0;
  int totalProducts = 0;
  int activeProducts = 0;
  int lowStock = 0;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('vendor/stats.php', auth: true);
    if (res['success'] == true) {
      final d = res['data'];
      todayRevenue = double.tryParse('${d['today_revenue']}') ?? 0;
      todayOrders = int.tryParse('${d['today_orders']}') ?? 0;
      pendingOrders = int.tryParse('${d['pending_orders']}') ?? 0;
      totalProducts = int.tryParse('${d['total_products']}') ?? 0;
      activeProducts = int.tryParse('${d['active_products']}') ?? 0;
      lowStock = int.tryParse('${d['low_stock']}') ?? 0;
    }
    _isLoading = false;
    notifyListeners();
  }
}
