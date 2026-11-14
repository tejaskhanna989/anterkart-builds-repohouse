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
  final double? deliveryLat;
  final double? deliveryLng;

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
    this.deliveryLat,
    this.deliveryLng,
  });

  /// Read a coordinate pair from either `"lat, lng"` strings or
  /// `{lat: .., lng: ..}` maps, tolerating the different key spellings the
  /// API uses across endpoints.
  static double? _coord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.contains(',')) {
      final first = raw.split(',').first.trim();
      return double.tryParse(first);
    }
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

    // Live rider GPS. The API exposes it as the `rider_location` column
    // ("lat, lng") on the order, and sometimes as a `rider` object.
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
    if (riderLat == null || riderLng == null || (riderLat == 0 && riderLng == 0)) {
      riderLat = null;
      riderLng = null;
    }
    final rider = _map(j['rider']);

    // Customer drop-off coordinates (present on newer API responses).
    final dest = _map(j['destination']);
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
      updatedAt: j['updated_at'] ?? j['created_at'] ?? '',
      etaMinutes: j['eta_minutes'] is int ? j['eta_minutes'] : int.tryParse('${j['eta_minutes']}') ?? 0,
      pickupCode: '${j['pickup_code'] ?? ''}',
      deliveryBoyId: j['delivery_boy_id'] is int ? j['delivery_boy_id'] : int.tryParse('${j['delivery_boy_id']}') ?? 0,
      riderArrivedAt: '${j['rider_arrived_at'] ?? ''}',
      riderLat: riderLat,
      riderLng: riderLng,
      riderName: rider?['name']?.toString() ?? j['rider_name']?.toString(),
      riderPhone: rider?['phone']?.toString() ?? j['rider_phone']?.toString(),
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      itemCount: j['item_count'] is int ? j['item_count'] : int.tryParse('${j['item_count']}') ?? items.length,
    );
  }
}
