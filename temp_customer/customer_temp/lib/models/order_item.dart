class OrderItem {
  final int id;
  final int? productId;
  final String name;
  final double price;
  final int quantity;
  final String? image;

  OrderItem({required this.id, this.productId, required this.name, required this.price, required this.quantity, this.image});

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    productId: j['product_id'] is int ? j['product_id'] : int.tryParse('${j['product_id']}'),
    name: j['name'] ?? '',
    price: double.tryParse('${j['price']}') ?? 0,
    quantity: j['quantity'] is int ? j['quantity'] : int.tryParse('${j['quantity']}') ?? 1,
    image: j['image'],
  );
}
