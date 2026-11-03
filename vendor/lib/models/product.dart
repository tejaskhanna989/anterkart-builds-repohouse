class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final double mrp;
  final int? categoryId;
  final String categoryName;
  final int stock;
  final String status;
  final int isVeg;
  final String image;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    this.price = 0,
    this.mrp = 0,
    this.categoryId,
    this.categoryName = '',
    this.stock = 0,
    this.status = 'active',
    this.isVeg = 0,
    this.image = '',
  });

  bool get isActive => status == 'active';

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: j['name'] ?? '',
    description: j['description'] ?? '',
    price: double.tryParse('${j['price']}') ?? 0,
    mrp: double.tryParse('${j['mrp']}') ?? 0,
    categoryId: j['category_id'] == null ? null : int.tryParse('${j['category_id']}'),
    categoryName: j['category_name'] ?? '',
    stock: j['stock'] is int ? j['stock'] : int.tryParse('${j['stock']}') ?? 0,
    status: j['status'] ?? 'active',
    isVeg: j['is_veg'] is int ? j['is_veg'] : int.tryParse('${j['is_veg']}') ?? 0,
    image: j['image'] ?? '',
  );
}
