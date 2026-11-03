import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: cart.items.isNotEmpty
            ? [
                IconButton(
                  tooltip: 'Clear cart',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmClear(context, cart),
                ),
              ]
            : null,
      ),
      body: cart.items.isEmpty
          ? _emptyCart(context)
          : Column(
              children: [
                _billSummary(cart),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _cartItemCard(context, cart, cart.items[i]),
                  ),
                ),
                _checkoutBar(context, cart),
              ],
            ),
    );
  }

  Widget _billSummary(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} • ${_money(cart.subtotal)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
            child: const Text('Bill Details', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _cartItemCard(BuildContext context, CartProvider cart, item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: item.image,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(width: 76, height: 76, color: AppColors.lightGrey, child: const Icon(Icons.fastfood, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _vegDot(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                      ),
                    ),
                    InkWell(
                      onTap: () => _confirmRemoveItem(context, cart, item),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(item.lineTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${_money(item.price)} each)',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    _qtyStepper(cart, item),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyStepper(CartProvider cart, item) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => cart.updateQuantity(item.id, item.quantity - 1),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.remove, color: Colors.white, size: 15)),
          ),
          Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          InkWell(
            onTap: () => cart.updateQuantity(item.id, item.quantity + 1),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.add, color: Colors.white, size: 15)),
          ),
        ],
      ),
    );
  }

  Widget _checkoutBar(BuildContext context, CartProvider cart) {
    final total = cart.subtotal + 40;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To Pay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(_money(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.ink, letterSpacing: -0.3)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(210, 52)),
                    onPressed: () {
                      final auth = context.read<AuthProvider>();
                      if (!auth.isLoggedIn) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                    },
                    child: const Text('Proceed to Checkout  ›'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(color: AppColors.blueLight, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_outlined, size: 68, color: AppColors.blue),
            ),
            const SizedBox(height: 24),
            const Text('Your cart is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Hmm, so empty! Add some tasty items', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Browse Food'),
              ),
            ),
          ],
        ),
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

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('This will remove all items from your cart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveItem(BuildContext context, CartProvider cart, item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from your cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          TextButton(
            onPressed: () {
              cart.updateQuantity(item.id, 0);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
