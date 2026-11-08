import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/banner_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../services/onesignal_service.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'location_picker_screen.dart';
import 'categories_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().init();
      context.read<LocationProvider>().loadZones();
      context.read<BannerProvider>().loadBanners();
      context.read<ProductProvider>().loadCategories();
      context.read<ProductProvider>().loadBestsellers();
      context.read<ProductProvider>().loadNewArrivals();
      context.read<ProductProvider>().loadProducts();
      context.read<CartProvider>().loadCart();
      context.read<SettingsProvider>().loadHomeSections();
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<NotificationProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHome(),
          const ProductsScreen(showBack: false),
          const CartScreen(),
          const OrdersScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0C55E0),
          unselectedItemColor: const Color(0xFF9A9A9A),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
              icon: Consumer<CartProvider>(
                builder: (_, cart, __) => Badge(
                  isLabelVisible: cart.itemCount > 0,
                  backgroundColor: const Color(0xFFF97316),
                  label: Text('${cart.itemCount}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
              activeIcon: Consumer<CartProvider>(
                builder: (_, cart, __) => Badge(
                  isLabelVisible: cart.itemCount > 0,
                  backgroundColor: const Color(0xFFF97316),
                  label: Text('${cart.itemCount}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  child: const Icon(Icons.shopping_cart),
                ),
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildHome() {
    final products = context.watch<ProductProvider>();
    final banners = context.watch<BannerProvider>();
    final loc = context.watch<LocationProvider>();
    final settings = context.watch<SettingsProvider>();
    final configured = settings.sectionConfigAvailable;

    List<Widget> bannerSliver() =>
        banners.banners.isNotEmpty
            ? [SliverToBoxAdapter(child: BannerCarousel(banners: banners.banners))]
            : const [];

    List<Widget> categoriesSliver() {
      if (products.categories.isEmpty) return const [];
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: SectionHeader(title: 'Categories', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final cat = products.categories[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(categoryId: cat.id, categoryName: cat.name))),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF0C55E0).withOpacity( 0.08),
                        child: cat.image.isNotEmpty
                            ? ClipOval(child: Image.network(cat.image, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.category, color: Color(0xFF0C55E0))))
                            : const Icon(Icons.category, color: Color(0xFF0C55E0)),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ];
    }

    List<Widget> bestsellersSliver() {
      if (products.bestsellers.isEmpty) return const [];
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: SectionHeader(title: 'Best Sellers', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(title: 'Best Sellers')))),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.bestsellers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 160, child: ProductCard(product: products.bestsellers[i])),
            ),
          ),
        ),
      ];
    }

    List<Widget> newArrivalsSliver() {
      if (products.newArrivals.isEmpty) return const [];
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: SectionHeader(title: 'New Arrivals', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(title: 'New Arrivals')))),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.newArrivals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 160, child: ProductCard(product: products.newArrivals[i])),
            ),
          ),
        ),
      ];
    }

    List<Widget> featureSliver(HomeSection s) {
      final feats = s.categories.isNotEmpty
          ? products.products.where((p) => p.categoryName != null && s.categories.contains(p.categoryName)).toList()
          : products.products.take(10).toList();
      if (feats.isEmpty) return const [];
      final title = s.title.isNotEmpty ? s.title : 'Featured';
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: SectionHeader(title: title, onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(title: title)))),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: feats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 160, child: ProductCard(product: feats[i])),
            ),
          ),
        ),
      ];
    }

    List<Widget> allProductsSliver() {
      if (products.products.isEmpty) return const [];
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: SectionHeader(title: 'All Products', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(title: 'All Products')))),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.62),
            delegate: SliverChildBuilderDelegate(
              (_, i) => ProductCard(product: products.products[i]),
              childCount: products.products.length,
            ),
          ),
        ),
      ];
    }

    final content = <Widget>[];
    if (configured) {
      for (final s in settings.homeSections) {
        if (!s.show) continue;
        switch (s.type) {
          case 'banners':
            content.addAll(bannerSliver());
          case 'categories':
            content.addAll(categoriesSliver());
          case 'bestsellers':
            content.addAll(bestsellersSliver());
          case 'new_arrivals':
            content.addAll(newArrivalsSliver());
          case 'all_products':
            content.addAll(allProductsSliver());
          case 'feature':
            content.addAll(featureSliver(s));
        }
      }
    } else {
      content
        ..addAll(bannerSliver())
        ..addAll(categoriesSliver())
        ..addAll(bestsellersSliver())
        ..addAll(newArrivalsSliver())
        ..addAll(allProductsSliver());
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: const Color(0xFF0C55E0),
          foregroundColor: Colors.white,
          expandedHeight: 0,
          title: Consumer<LocationProvider>(builder: (_, loc, __) {
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerScreen())),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Deliver to', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                      Text(loc.hasLocation ? loc.address : 'Select location', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
                ],
              ),
            );
          }),
          actions: [
            IconButton(
              icon: const Icon(Icons.storefront, color: Colors.white),
              onPressed: () {},
            ),
            Consumer<NotificationProvider>(
              builder: (_, notif, __) => IconButton(
                icon: Badge(
                  isLabelVisible: notif.unread > 0,
                  label: Text('${notif.unread}',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: const Color(0xFFF97316),
                  child: const Icon(Icons.notifications_none, color: Colors.white),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                controller: _searchController,
                onSubmitted: (q) {
                  if (q.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(searchQuery: q)));
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search for restaurants & food...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
        ),
        if (!loc.hasLocation)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0C55E0).withOpacity( 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0C55E0).withOpacity( 0.3))),
              child: Row(children: [
                const Icon(Icons.location_off, color: Color(0xFF0C55E0), size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('No Location Setup — Tap to set delivery location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0C55E0)))),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerScreen())), child: const Text('Set', style: TextStyle(color: Color(0xFF0C55E0)))),
              ]),
            ),
          ),
        ...content,
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
