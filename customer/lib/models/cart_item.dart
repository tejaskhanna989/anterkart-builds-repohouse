class CartItem {
  final int id;
  final int productId;
  final String name;
  final double price;
  final String image;
  final int quantity;
  final double lineTotal;
  final int tenantId;
  final String vendor;
  final String vendorSlug;

  CartItem({required this.id, required this.productId, required this.name, required this.price, this.image = '', required this.quantity, this.lineTotal = 0, this.tenantId = 0, this.vendor = '', this.vendorSlug = ''});

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    productId: j['product_id'] is int ? j['product_id'] : int.tryParse('${j['product_id']}') ?? 0,
    name: j['name'] ?? '',
    price: double.tryParse('${j['price']}') ?? 0,
    image: j['image'] ?? '',
    quantity: j['quantity'] is int ? j['quantity'] : int.tryParse('${j['quantity']}') ?? 1,
    lineTotal: double.tryParse('${j['line_total']}') ?? 0,
    tenantId: j['tenant_id'] is int ? j['tenant_id'] : int.tryParse('${j['tenant_id']}') ?? 0,
    vendor: j['vendor'] ?? '',
    vendorSlug: j['vendor_slug'] ?? '',
  );
}
