import 'order_item.dart';

class Order {
  final int id;
  final String orderNumber;
  final double subtotal;
  final double tax;
  final double deliveryFee;
  final double total;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? customerName;
  final String? customerPhone;
  final String? address;
  final List<OrderItem> items;
  final String createdAt;
  final int itemCount;
  final String? riderName;
  final String? riderPhone;
  final double? riderLat;
  final double? riderLng;
  final int? etaMinutes;

  Order({
    required this.id,
    required this.orderNumber,
    this.subtotal = 0,
    this.tax = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.status = 'pending',
    this.paymentMethod = 'COD',
    this.paymentStatus = 'unpaid',
    this.customerName,
    this.customerPhone,
    this.address,
    this.items = const [],
    this.createdAt = '',
    this.itemCount = 0,
    this.riderName,
    this.riderPhone,
    this.riderLat,
    this.riderLng,
    this.etaMinutes,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    List<OrderItem> items = [];
    if (j['items'] != null) {
      items = (j['items'] as List).map((x) => OrderItem.fromJson(x)).toList();
    }
    double? riderLat, riderLng;
    if (j['rider_location'] != null && j['rider_location'].toString().contains(',')) {
      final parts = j['rider_location'].toString().split(',');
      riderLat = double.tryParse(parts[0].trim());
      riderLng = double.tryParse(parts[1].trim());
    }
    return Order(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      orderNumber: j['order_number'] ?? '',
      subtotal: double.tryParse('${j['subtotal']}') ?? 0,
      tax: double.tryParse('${j['tax']}') ?? 0,
      deliveryFee: double.tryParse('${j['delivery_fee']}') ?? 0,
      total: double.tryParse('${j['total']}') ?? 0,
      status: j['status'] ?? 'pending',
      paymentMethod: j['payment_method'] ?? 'COD',
      paymentStatus: j['payment_status'] ?? 'unpaid',
      customerName: j['customer_name'],
      customerPhone: j['customer_phone'],
      address: j['address'],
      items: items,
      createdAt: j['created_at'] ?? '',
      itemCount: j['item_count'] is int ? j['item_count'] : int.tryParse('${j['item_count']}') ?? items.length,
      riderName: j['rider']?['name'],
      riderPhone: j['rider']?['phone'],
      riderLat: riderLat,
      riderLng: riderLng,
      etaMinutes: j['eta_minutes'] is int ? j['eta_minutes'] : int.tryParse('${j['eta_minutes']}'),
    );
  }
}
