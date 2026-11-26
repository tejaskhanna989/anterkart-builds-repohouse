import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  bool _isCreating = false;
  String? _checkoutAttemptId;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;

  /// Stable idempotency key for one checkout attempt.
  ///
  /// It remains unchanged across gateway callbacks and user retries. It is
  /// reset after the server confirms the order or when checkout details are
  /// deliberately changed.
  String get checkoutAttemptId {
    if (_checkoutAttemptId != null) return _checkoutAttemptId!;
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    _checkoutAttemptId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _checkoutAttemptId!;
  }

  void resetCheckoutAttempt() {
    _checkoutAttemptId = null;
  }

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

  Future<Map<String, dynamic>> createRazorpayOrder(double amount, {String? checkoutAttemptId}) async {
    final attemptId = checkoutAttemptId ?? this.checkoutAttemptId;
    final res = await ApiService.post('orders/razorpay_order.php', body: {
      'amount': amount,
      'checkout_attempt_id': attemptId,
    }, auth: true);
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
    String? checkoutAttemptId,
  }) async {
    _isCreating = true;
    notifyListeners();
    final attemptId = checkoutAttemptId ?? this.checkoutAttemptId;
    final body = <String, dynamic>{
      'address': address,
      'payment_method': paymentMethod,
      'checkout_attempt_id': attemptId,
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
