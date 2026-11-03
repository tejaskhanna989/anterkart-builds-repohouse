import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import 'write_review_screen.dart';
import 'login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  List<Review> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await context.read<ProductProvider>().getProductDetail(widget.productId);
    if (!mounted) return;
    setState(() { _product = p; _loading = false; });
    await _loadReviews();
  }

  Future<void> _loadReviews() async {
    final reviews = await context.read<ProductProvider>().fetchReviews(widget.productId);
    if (!mounted) return;
    setState(() { _reviews = reviews; _reviewsLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Product not found')));

    final p = _product!;
    final qtyInCart = cart.quantityInCart(p.id);

    final mrpSavings = (p.mrp - p.price) * qtyInCart;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(p.name)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'product_${p.id}',
                    child: Image.network(
                      p.image,
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 260, color: AppColors.lightGrey, child: const Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey))),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.categoryName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.blueLight, borderRadius: BorderRadius.circular(8)),
                              child: Text(p.categoryName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue)),
                            ),
                          const SizedBox(height: 10),
                          Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                          if (p.vendor.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 14, color: AppColors.blue),
                                const SizedBox(width: 4),
                                Text(p.vendor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          if (p.unit != null && p.unit!.isNotEmpty)
                            Text('Per ${p.unit}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
                              if (p.mrp > p.price) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text('₹${p.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(6)),
                                  child: Text('${p.discount.round()}% OFF', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                          if (p.mrp > p.price)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('You save ₹${(p.mrp - p.price).toStringAsFixed(0)} on this item', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                            ),
                          const SizedBox(height: 16),
                          if (p.avgRating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${p.avgRating}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                                  const SizedBox(width: 4),
                                  Text('(${p.reviewCount} reviews)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                          if (p.description.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text('About this item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 8),
                            Text(p.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 14)),
                          ],
                          const SizedBox(height: 24),
                          _reviewsSection(context, p),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _bottomBar(context, p, qtyInCart, mrpSavings),
        ],
      ),
    );
  }

  Widget _reviewsSection(BuildContext context, Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Ratings & Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            TextButton.icon(
              onPressed: () => _openWriteReview(context, p),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue, textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Write a review'),
            ),
          ],
        ),
        if (_reviewsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.reviews_outlined, size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 8),
                Text('No reviews yet. Be the first to review!', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          ..._reviews.map((r) => _reviewCard(r)),
      ],
    );
  }

  Widget _reviewCard(Review r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.blueLight,
                child: Text(
                  r.name.isNotEmpty ? r.name[0].toUpperCase() : 'C',
                  style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (r.date.isNotEmpty)
                Text(r.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < r.rating;
              return Icon(filled ? Icons.star : Icons.star_border, color: filled ? Colors.amber : Colors.grey.shade300, size: 16);
            }),
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.comment, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ],
        ],
      ),
    );
  }

  void _openWriteReview(BuildContext context, Product p) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    _reviewsLoading = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WriteReviewScreen(productId: p.id, productName: p.name)),
    ).then((submitted) {
      if (submitted == true) {
        setState(() { _reviewsLoading = true; });
        _loadReviews();
        _load();
      } else {
        setState(() {});
      }
    });
  }

  Widget _bottomBar(BuildContext context, Product p, int qtyInCart, double mrpSavings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: p.stock <= 0
            ? Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(14)),
                child: const Text('Out of Stock', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 16)),
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.ink, letterSpacing: -0.3)),
                            if (p.mrp > p.price) ...[
                              const SizedBox(width: 5),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('₹${p.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                              ),
                            ],
                          ],
                        ),
                        if (mrpSavings > 0)
                          Text('Save ₹${mrpSavings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  qtyInCart > 0
                      ? _qtyStepper(p, qtyInCart)
                      : SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 52)),
                            onPressed: () => _addToCart(p),
                            child: const Text('Add to Cart  ›'),
                          ),
                        ),
                ],
              ),
      ),
    );
  }

  Widget _qtyStepper(Product p, int qtyInCart) {
    final cart = context.read<CartProvider>();
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              try {
                final cartItem = cart.items.firstWhere((i) => i.productId == p.id);
                cart.updateQuantity(cartItem.id, qtyInCart - 1);
              } catch (_) {}
            },
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Icon(Icons.remove, color: Colors.white, size: 18)),
          ),
          Text('$qtyInCart', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          InkWell(
            onTap: () => cart.addItem(p.id),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Icon(Icons.add, color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product p) {
    final cart = context.read<CartProvider>();
    cart.addItem(p.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Added ${p.name} to cart', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
