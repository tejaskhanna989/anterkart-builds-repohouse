import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import 'products_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cats = context.watch<ProductProvider>().categories;
    return Scaffold(
      appBar: AppBar(title: const Text('All Categories')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(categoryId: c.id, categoryName: c.name))),
            borderRadius: BorderRadius.circular(12),
            child: Column(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: c.image.isNotEmpty ? Image.network(c.image, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2563EB).withValues(alpha: 0.1), child: const Icon(Icons.category, color: Color(0xFF2563EB)))) : Container(color: const Color(0xFF2563EB).withValues(alpha: 0.1), child: const Icon(Icons.category, color: Color(0xFF2563EB))))),
              const SizedBox(height: 6),
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${c.productCount} items', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ]),
          );
        },
      ),
    );
  }
}
