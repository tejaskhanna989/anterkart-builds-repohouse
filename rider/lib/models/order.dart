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
  final double? deliveryLat;
  final double? deliveryLng;
  final double? storeLat;
  final double? storeLng;
  final double? riderLat;
  final double? riderLng;

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
    this.deliveryLat,
    this.deliveryLng,
    this.storeLat,
    this.storeLng,
    this.riderLat,
    this.riderLng,
  });

  /// Read a coordinate from a number or a numeric string.
  static double? _coord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  factory Order.fromJson(Map<String, dynamic> j) {
    List<OrderItem> items = [];
    if (j['items'] != null) {
      items = (j['items'] as List).map((x) => OrderItem.fromJson(x)).toList();
    }

    // Coordinates. The API has used several key spellings over time, so try
    // the common ones and fall back to null when nothing is available.
    final dest = _map(j['destination']);
    final deliveryLat = _coord(dest?['lat'] ?? j['delivery_lat'] ?? j['customer_lat'] ?? j['lat']);
    final deliveryLng = _coord(dest?['lng'] ?? j['delivery_lng'] ?? j['customer_lng'] ?? j['lng']);

    final store = _map(j['store']);
    final storeLat = _coord(store?['lat'] ?? j['store_lat'] ?? j['pickup_lat'] ?? j['tenant_lat']);
    final storeLng = _coord(store?['lng'] ?? j['store_lng'] ?? j['pickup_lng'] ?? j['tenant_lng']);

    final riderLoc = _map(j['rider_location']);
    double? riderLat;
    double? riderLng;
    if (riderLoc != null) {
      riderLat = _coord(riderLoc['lat']);
      riderLng = _coord(riderLoc['lng'] ?? riderLoc['lon'] ?? riderLoc['longitude']);
    } else {
      final raw = j['rider_location']?.toString().trim() ?? '';
      if (raw.contains(',')) {
        final parts = raw.split(',');
        riderLat = double.tryParse(parts[0].trim());
        riderLng = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
      }
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
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      storeLat: storeLat,
      storeLng: storeLng,
      riderLat: riderLat,
      riderLng: riderLng,
    );
  }
}
