class Rider {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String vehicle;
  final String status;
  final int available;
  final double? lat;
  final double? lng;

  Rider({required this.id, required this.name, this.email = '', this.phone = '', this.vehicle = '', this.status = 'active', this.available = 1, this.lat, this.lng});

  factory Rider.fromJson(Map<String, dynamic> j) => Rider(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    vehicle: j['vehicle'] ?? '',
    status: j['status'] ?? 'active',
    available: j['available'] is int ? j['available'] : int.tryParse('${j['available']}') ?? 1,
    lat: double.tryParse('${j['lat']}'),
    lng: double.tryParse('${j['lng']}'),
  );
}
