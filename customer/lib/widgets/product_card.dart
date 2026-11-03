import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qtyInCart = cart.quantityInCart(product.id);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Hero(
                    tag: 'product_${product.id}',
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: product.image,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.lightGrey, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(color: AppColors.lightGrey, child: const Icon(Icons.fastfood, size: 40, color: Colors.grey)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _vegDot(),
                  ),
                  if (product.discount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(6)),
                        child: Text('${product.discount.round()}% OFF', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _addOverlay(context, product, qtyInCart, cart),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.15)),
                  if (product.vendor.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 4, bottom: 1),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.blue),
                        ),
                        Expanded(
                          child: Text(product.vendor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.blue)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${product.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15)),
                      if (product.mrp > product.price) ...[
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: Text('₹${product.mrp.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                        ),
                      ],
                    ],
                  ),
                  if (product.unit != null && product.unit!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Per ${product.unit}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                  if (product.avgRating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(product.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        if (product.reviewCount > 0) ...[
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text('(${product.reviewCount})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addOverlay(BuildContext context, Product product, int qtyInCart, CartProvider cart) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qtyInCart > 0)
            InkWell(
              onTap: () {
                try {
                  final item = cart.items.firstWhere((i) => i.productId == product.id);
                  cart.updateQuantity(item.id, qtyInCart - 1);
                } catch (_) {}
              },
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.remove, color: AppColors.orange, size: 16)),
            ),
          if (qtyInCart > 0)
            Text('$qtyInCart', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 13)),
          InkWell(
            onTap: () {
              cart.addItem(product.id);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 900),
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Added ${product.name} to cart', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: qtyInCart > 0 ? 8 : 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ADD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange)),
                  const SizedBox(width: 2),
                  const Icon(Icons.add, color: AppColors.orange, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vegDot() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade700, width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      ),
    );
  }
}
