import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _pendingOrders = [];
  List<Order> _assignedOrders = [];
  bool _isLoading = false;

  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get assignedOrders => _assignedOrders;
  bool get isLoading => _isLoading;

  Future<void> loadPending() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('rider/orders/pending.php', auth: true);
    if (res['success'] == true) {
      _pendingOrders = (res['data']['orders'] as List? ?? []).map((j) => Order.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAssigned() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('rider/orders/assigned.php', auth: true);
    if (res['success'] == true) {
      _assignedOrders = (res['data']['orders'] as List? ?? []).map((j) => Order.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> acceptOrder(int orderId, {String code = ''}) async {
    final res = await ApiService.post('rider/orders/accept.php', body: {'order_id': orderId, if (code.isNotEmpty) 'code': code}, auth: true);
    if (res['success'] == true) {
      await loadPending();
      await loadAssigned();
    }
    return {'ok': res['success'] == true, 'message': res['message'], 'data': res['data']};
  }

  Future<Map<String, dynamic>> pickupOrder(int orderId, String code) async {
    final res = await ApiService.post('rider/orders/pickup.php', body: {'order_id': orderId, 'code': code}, auth: true);
    if (res['success'] == true) {
      await loadPending();
      await loadAssigned();
    }
    return {'ok': res['success'] == true, 'message': res['message']};
  }

  Future<Map<String, dynamic>> markArrived(int orderId, String at) async {
    final res = await ApiService.post('rider/orders/arrived.php', body: {'order_id': orderId, 'at': at}, auth: true);
    if (res['success'] == true) {
      await loadAssigned();
    }
    return {'ok': res['success'] == true, 'message': res['message']};
  }

  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> get offers => _offers;

  Future<void> loadOffers() async {
    final res = await ApiService.get('rider/orders/offers.php', auth: true);
    if (res['success'] == true) {
      _offers = ((res['data']['offers'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))).toList();
      notifyListeners();
    }
  }

  Future<bool> reofferOrder(int orderId) async {
    final res = await ApiService.post('rider/orders/reoffer.php', body: {'order_id': orderId}, auth: true);
    if (res['success'] == true) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> respondOffer(int offerId, bool accept) async {
    final res = await ApiService.post('rider/orders/respond.php',
        body: {'offer_id': offerId, 'action': accept ? 'accept' : 'decline'}, auth: true);
    await loadOffers();
    if (res['success'] == true) {
      await loadPending();
      await loadAssigned();
    }
    return {'ok': res['success'] == true, 'message': res['message']};
  }

  Future<Order?> loadDetail(int orderId) async {
    final res = await ApiService.get('rider/orders/detail.php', auth: true, queryParams: {'order_id': '$orderId'});
    if (res['success'] == true) {
      return Order.fromJson(res['data']['order']);
    }
    return null;
  }

  Future<Map<String, dynamic>> resendDeliveryCode(int orderId) async {
    final res = await ApiService.post('rider/orders/resend-otp.php', body: {'order_id': orderId}, auth: true);
    return {'ok': res['success'] == true, 'message': res['message']};
  }

  Future<Map<String, dynamic>> callCustomer(int orderId) async {
    final res = await ApiService.post('rider/orders/call.php', body: {'order_id': orderId}, auth: true);
    if (res['success'] == true) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'masked': false, 'number': '', 'message': res['message'] ?? 'Call failed'};
  }

  Future<List<Map<String, dynamic>>> loadChat(int orderId, {int afterId = 0}) async {
    final res = await ApiService.get('rider/orders/chat.php', auth: true,
        queryParams: {'order_id': orderId.toString(), 'after_id': afterId.toString()});
    if (res['success'] == true) {
      return ((res['data']['messages'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }

  Future<bool> sendChat(int orderId, String message) async {
    final res = await ApiService.post('rider/orders/chat-send.php', body: {'order_id': orderId, 'message': message}, auth: true);
    return res['success'] == true;
  }

  Future<bool> updateStatus(int orderId, String status, {String code = ''}) async {
    final res = await ApiService.post('rider/orders/status.php',
        body: {'order_id': orderId, 'status': status, if (code.isNotEmpty) 'code': code}, auth: true);
    if (res['success'] == true) {
      await loadAssigned();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> updateStatusEx(int orderId, String status, {String code = ''}) async {
    final res = await ApiService.post('rider/orders/status.php',
        body: {'order_id': orderId, 'status': status, if (code.isNotEmpty) 'code': code}, auth: true);
    if (res['success'] == true) {
      await loadAssigned();
      return {'ok': true, 'message': res['message']};
    }
    return {'ok': false, 'message': res['message'] ?? 'Failed'};
  }
}
