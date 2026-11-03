import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Products'), automaticallyImplyLeading: false),
      body: pp.isLoading && pp.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<ProductProvider>().loadProducts(),
              child: pp.products.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No products yet. Tap + to add one.', style: TextStyle(color: Colors.grey)))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: pp.products.length,
                      itemBuilder: (_, i) => _productTile(context, pp.products[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditSheet(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _productTile(BuildContext context, Product p) {
    final pp = context.read<ProductProvider>();
    return Card(
      child: ListTile(
        leading: p.image.isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: p.image, width: 52, height: 52, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.fastfood)))
            : const CircleAvatar(child: Icon(Icons.fastfood)),
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('₹${p.price.toStringAsFixed(0)}  •  Stock ${p.stock}${p.categoryName.isNotEmpty ? '  •  ${p.categoryName}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (p.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.isActive ? 'Live' : 'Off', style: TextStyle(color: p.isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'toggle') pp.toggleStatus(p.id);
                if (v == 'edit') _showEditSheet(context, p);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text(p.isActive ? 'Take offline' : 'Put live')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, Product? p) {
    final nameC = TextEditingController(text: p?.name ?? '');
    final priceC = TextEditingController(text: p != null ? '${p.price}' : '');
    final mrpC = TextEditingController(text: p != null ? '${p.mrp}' : '');
    final stockC = TextEditingController(text: p != null ? '${p.stock}' : '0');
    final descC = TextEditingController(text: p?.description ?? '');
    bool isVeg = (p?.isVeg ?? 0) == 1;
    bool active = p?.isActive ?? true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p == null ? 'Add product' : 'Edit product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price *', border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: mrpC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MRP', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: stockC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()))),
                ]),
                SwitchListTile(title: const Text('Vegetarian'), value: isVeg, onChanged: (v) => setSheet(() => isVeg = v)),
                SwitchListTile(title: const Text('Visible to customers'), value: active, onChanged: (v) => setSheet(() => active = v)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final price = double.tryParse(priceC.text) ?? 0;
                      if (nameC.text.trim().isEmpty || price <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name and valid price required')));
                        return;
                      }
                      final err = await context.read<ProductProvider>().saveProduct(
                        productId: p?.id,
                        name: nameC.text.trim(),
                        price: price,
                        mrp: double.tryParse(mrpC.text),
                        stock: int.tryParse(stockC.text) ?? 0,
                        description: descC.text.trim(),
                        status: active ? 'active' : 'inactive',
                        isVeg: isVeg ? 1 : 0,
                      );
                      if (ctx.mounted) {
                        if (err == null) {
                          Navigator.pop(ctx);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                        }
                      }
                    },
                    child: Text(p == null ? 'Add' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
