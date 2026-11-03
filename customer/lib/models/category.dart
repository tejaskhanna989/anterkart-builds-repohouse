class Category {
  final int id;
  final String name;
  final String icon;
  final String image;
  final int sortOrder;
  final int productCount;

  Category({
    required this.id,
    required this.name,
    this.icon = '',
    this.image = '',
    this.sortOrder = 0,
    this.productCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    name: j['name'] ?? '',
    icon: j['icon'] ?? '',
    image: j['image'] ?? '',
    sortOrder: j['sort_order'] is int ? j['sort_order'] : int.tryParse('${j['sort_order']}') ?? 0,
    productCount: j['product_count'] is int ? j['product_count'] : int.tryParse('${j['product_count']}') ?? 0,
  );
}
