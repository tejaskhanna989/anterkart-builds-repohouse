class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? image;

  Customer({required this.id, required this.name, required this.email, this.phone = '', this.address = '', this.image});

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    address: j['address'] ?? '',
    image: j['image'],
  );
}
