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
  final String updatedAt;
  final int etaMinutes;
  final int itemCount;
  final String pickupCode;
  final int deliveryBoyId;
  final String riderArrivedAt;
  final double? riderLat;
  final double? riderLng;
  final String? riderName;
  final String? riderPhone;

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
    this.updatedAt = '',
    this.etaMinutes = 0,
    this.itemCount = 0,
    this.pickupCode = '',
    this.deliveryBoyId = 0,
    this.riderArrivedAt = '',
    this.riderLat,
    this.riderLng,
    this.riderName,
    this.riderPhone,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    List<OrderItem> items = [];
    if (j['items'] != null) {
      items = (j['items'] as List).map((x) => OrderItem.fromJson(x)).toList();
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
      updatedAt: j['updated_at'] ?? j['created_at'] ?? '',
      etaMinutes: j['eta_minutes'] is int ? j['eta_minutes'] : int.tryParse('${j['eta_minutes']}') ?? 0,
      pickupCode: '${j['pickup_code'] ?? ''}',
      deliveryBoyId: j['delivery_boy_id'] is int ? j['delivery_boy_id'] : int.tryParse('${j['delivery_boy_id']}') ?? 0,
      riderArrivedAt: '${j['rider_arrived_at'] ?? ''}',
      itemCount: j['item_count'] is int ? j['item_count'] : int.tryParse('${j['item_count']}') ?? items.length,
    );
  }
}
