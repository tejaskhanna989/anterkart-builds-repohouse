import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  bool _isCreating = false;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('orders/list.php', auth: true);
    if (res['success'] == true) {
      _orders = (res['data']['orders'] as List? ?? []).map((j) => Order.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Order?> loadOrderDetail(int id) async {
    final res = await ApiService.get('orders/detail.php', auth: true, queryParams: {'id': id.toString()});
    if (res['success'] == true) {
      return Order.fromJson(res['data']['order']);
    }
    return null;
  }

  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    final res = await ApiService.post('orders/razorpay_order.php', body: {'amount': amount}, auth: true);
    if (res['success'] == true) return {'success': true, 'data': res['data']};
    return {'success': false, 'message': res['message'] ?? 'Failed to create Razorpay order'};
  }

  Future<Map<String, dynamic>> createOrder({
    required String address,
    required String paymentMethod,
    int? deliveryZoneId,
    double? lat,
    double? lng,
    String? customerName,
    String? customerPhone,
    String? couponCode,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    bool perKm = false,
  }) async {
    _isCreating = true;
    notifyListeners();
    final body = <String, dynamic>{
      'address': address,
      'payment_method': paymentMethod,
    };
    if (perKm) body['per_km'] = '1';
    if (deliveryZoneId != null) body['delivery_zone_id'] = deliveryZoneId;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;
    if (customerName != null) body['customer_name'] = customerName;
    if (customerPhone != null) body['customer_phone'] = customerPhone;
    if (couponCode != null && couponCode.isNotEmpty) body['coupon_code'] = couponCode;
    if (razorpayPaymentId != null) body['razorpay_payment_id'] = razorpayPaymentId;
    if (razorpayOrderId != null) body['razorpay_order_id'] = razorpayOrderId;
    if (razorpaySignature != null) body['razorpay_signature'] = razorpaySignature;

    final res = await ApiService.post('orders/create.php', body: body, auth: true);
    _isCreating = false;
    notifyListeners();

    if (res['success'] == true) {
      return {'success': true, 'data': res['data']};
    }
    return {'success': false, 'message': res['message'] ?? 'Failed to place order'};
  }

  Future<Map<String, dynamic>> trackOrder(int orderId) async {
    final res = await ApiService.get('orders/track.php', auth: true, queryParams: {'order_id': orderId.toString()});
    if (res['success'] == true) {
      return res['data'];
    }
    return {};
  }

  Future<Map<String, dynamic>> callRider(int orderId) async {
    final res = await ApiService.post('orders/call.php', body: {'order_id': orderId}, auth: true);
    if (res['success'] == true) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'masked': false, 'number': '', 'message': res['message'] ?? 'Call failed'};
  }

  Future<List<Map<String, dynamic>>> loadChat(int orderId, {int afterId = 0}) async {
    final res = await ApiService.get('orders/chat.php', auth: true,
        queryParams: {'order_id': orderId.toString(), 'after_id': afterId.toString()});
    if (res['success'] == true) {
      return ((res['data']['messages'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }

  Future<bool> sendChat(int orderId, String message) async {
    final res = await ApiService.post('orders/chat-send.php', body: {'order_id': orderId, 'message': message}, auth: true);
    return res['success'] == true;
  }
}
