class Category {
  final int id;
  final String name;
  final String? icon;
  final String? image;
  final String? themeColor;
  final int sortOrder;
  final int productCount;

  Category({
    required this.id,
    required this.name,
    this.icon,
    this.image,
    this.themeColor,
    this.sortOrder = 0,
    this.productCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        name: j['name'] ?? '',
        icon: j['icon'],
        image: j['image'],
        themeColor: j['theme_color'] ?? j['themeColor'],
        sortOrder: j['sort_order'] ?? j['sortOrder'] ?? 0,
        productCount: j['product_count'] ?? 0,
      );
}