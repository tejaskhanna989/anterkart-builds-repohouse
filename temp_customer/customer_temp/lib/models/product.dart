class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final double mrp;
  final String image;
  final int stock;
  final int? categoryId;
  final String? categoryName;
  final String? unit;
  final String status;
  final double discount;
  final double avgRating;
  final int reviewCount;
  final String vendor;
  final String vendorSlug;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.mrp = 0,
    this.image = '',
    this.stock = 0,
    this.categoryId,
    this.categoryName,
    this.unit,
    this.status = 'active',
    this.discount = 0,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.vendor = '',
    this.vendorSlug = '',
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: j['name'] ?? '',
    description: j['description'] ?? '',
    price: double.tryParse('${j['price']}') ?? 0,
    mrp: double.tryParse('${j['mrp']}') ?? 0,
    image: j['image'] ?? '',
    stock: j['stock'] is int ? j['stock'] : int.tryParse('${j['stock']}') ?? 0,
    categoryId: j['category_id'] is int ? j['category_id'] : int.tryParse('${j['category_id']}'),
    categoryName: j['category_name'],
    unit: j['unit'],
    status: j['status'] ?? 'active',
    discount: double.tryParse('${j['discount']}') ?? 0,
    avgRating: double.tryParse('${j['avg_rating']}') ?? 0,
    reviewCount: j['review_count'] is int ? j['review_count'] : int.tryParse('${j['review_count']}') ?? 0,
    vendor: j['vendor'] ?? '',
    vendorSlug: j['vendor_slug'] ?? '',
  );
}
