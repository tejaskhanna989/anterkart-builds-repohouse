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
  final double? deliveryLat;
  final double? deliveryLng;
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
    this.deliveryLat,
    this.deliveryLng,
    this.etaMinutes,
  });

  /// Read a coordinate from a number or a numeric string.
  static double? _coord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  factory Order.fromJson(Map<String, dynamic> j) {
    List<OrderItem> items = [];
    if (j['items'] != null) {
      items = (j['items'] as List).map((x) => OrderItem.fromJson(x)).toList();
    }
    // Live rider GPS. The API exposes it in three different shapes:
    //  - `rider_lat` / `rider_lng` columns (orders/detail.php, orders/list.php)
    //  - `rider_location` as a "lat, lng" string (orders/track.php)
    //  - a `rider` object with lat/lng
    // All of them are checked so the map works with every endpoint.
    final rider = j['rider'] is Map ? Map<String, dynamic>.from(j['rider'] as Map) : null;
    double? riderLat = _coord(j['rider_lat']);
    double? riderLng = _coord(j['rider_lng']);
    if (riderLat == null || riderLng == null) {
      if (rider != null) {
        riderLat = _coord(rider['lat'] ?? rider['latitude']);
        riderLng = _coord(rider['lng'] ?? rider['lon'] ?? rider['longitude']);
      }
    }
    if (riderLat == null || riderLng == null) {
      final raw = j['rider_location']?.toString().trim() ?? '';
      if (raw.contains(',')) {
        final parts = raw.split(',');
        riderLat = double.tryParse(parts[0].trim());
        riderLng = parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
      }
    }
    if (riderLat == null || riderLng == null || (riderLat == 0 && riderLng == 0)) {
      riderLat = null;
      riderLng = null;
    }
    // Customer drop-off coordinates (present on newer API responses).
    final dest = j['destination'] is Map ? Map<String, dynamic>.from(j['destination'] as Map) : null;
    final deliveryLat = _coord(dest?['lat'] ?? j['delivery_lat'] ?? j['customer_lat'] ?? j['lat']);
    final deliveryLng = _coord(dest?['lng'] ?? j['delivery_lng'] ?? j['customer_lng'] ?? j['lng']);
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
      riderName: rider?['name'] ?? j['rider_name']?.toString(),
      riderPhone: rider?['phone'] ?? j['rider_phone']?.toString(),
      riderLat: riderLat,
      riderLng: riderLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      etaMinutes: j['eta_minutes'] is int ? j['eta_minutes'] : int.tryParse('${j['eta_minutes']}'),
    );
  }
}
