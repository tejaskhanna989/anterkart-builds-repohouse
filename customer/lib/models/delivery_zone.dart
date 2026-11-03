class DeliveryZone {
  final int id;
  final String zone;
  final String name;
  final double distanceKm;
  final double deliveryFee;
  final int deliveryTime;
  final double minOrder;

  DeliveryZone({required this.id, required this.zone, required this.name, this.distanceKm = 0, this.deliveryFee = 0, this.deliveryTime = 30, this.minOrder = 0});

  factory DeliveryZone.fromJson(Map<String, dynamic> j) => DeliveryZone(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    zone: j['zone'] ?? '',
    name: j['name'] ?? '',
    distanceKm: double.tryParse('${j['distance_km']}') ?? 0,
    deliveryFee: double.tryParse('${j['delivery_fee']}') ?? 0,
    deliveryTime: j['delivery_time'] is int ? j['delivery_time'] : int.tryParse('${j['delivery_time']}') ?? 30,
    minOrder: double.tryParse('${j['min_order']}') ?? 0,
  );
}
