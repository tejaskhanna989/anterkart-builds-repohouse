import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  final String? searchQuery;
  final String? title;
  final bool showBack;
  const ProductsScreen({super.key, this.categoryId, this.categoryName, this.searchQuery, this.title, this.showBack = true});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _sort = 'default';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(
        categoryId: widget.categoryId,
        search: widget.searchQuery,
        sort: _sort,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? widget.categoryName ?? 'Products'),
        leading: widget.showBack ? null : const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (q) {
                context.read<ProductProvider>().loadProducts(search: q, sort: _sort, categoryId: widget.categoryId);
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _sortChip('Default', 'default'),
                _sortChip('Price: Low-High', 'price_asc'),
                _sortChip('Price: High-Low', 'price_desc'),
                _sortChip('Newest', 'newest'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.isLoading && products.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : products.products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await context.read<ProductProvider>().loadProducts(categoryId: widget.categoryId, search: _searchController.text, sort: _sort);
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.62),
                          itemCount: products.products.length,
                          itemBuilder: (_, i) => ProductCard(product: products.products[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sort == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black, fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() => _sort = value);
          context.read<ProductProvider>().loadProducts(categoryId: widget.categoryId, search: _searchController.text, sort: value);
        },
        selectedColor: const Color(0xFF2563EB),
        checkmarkColor: Colors.white,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
