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
      itemCount: j['item_count'] is int ? j['item_count'] : int.tryParse('${j['item_count']}') ?? items.length,
    );
  }
}
