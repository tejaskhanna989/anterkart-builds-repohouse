import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/stats_provider.dart';
import '../services/onesignal_service.dart';
import '../services/order_alarm.dart';
import '../theme/app_theme.dart';
import '../widgets/order_card.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import 'products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Timer? _pollTimer;
  Set<int> _knownPending = {};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<OrderProvider>().loadOrders();
      if (mounted) {
        _knownPending = context.read<OrderProvider>().pendingIds;
        context.read<StatsProvider>().loadStats();
        _startPolling();
      }
      // Ring + refresh when a push lands while the app is open.
      OneSignalService.addListeners();
      OneSignalService.onForegroundPush = () {
        if (!mounted) return;
        context.read<OrderProvider>().loadOrders().then((_) {
          if (mounted) _checkForNewOrders();
        });
      };
      // Tapping a push opens the Orders tab.
      OneSignalService.onPushClick = () {
        if (mounted) setState(() => _tab = 1);
      };
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Vendors keep this app open in the kitchen; poll so a new order rings
    // even if the push is missed or arrives silently.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      await context.read<OrderProvider>().loadOrders();
      if (mounted) _checkForNewOrders();
    });
  }

  /// Compare pending ids before/after refresh; ring for genuinely new orders.
  void _checkForNewOrders() {
    final prov = context.read<OrderProvider>();
    final current = prov.pendingIds;
    final fresh = current.difference(_knownPending);
    _knownPending = current;
    if (fresh.isNotEmpty && mounted && !_dialogOpen) {
      final order = prov.awaitingOrders.firstWhere(
        (o) => fresh.contains(o.id),
        orElse: () => prov.awaitingOrders.first,
      );
      _ringForOrder(order);
    }
    if (current.isEmpty) OrderAlarm.stop();
  }

  Future<void> _ringForOrder(Order order) async {
    _dialogOpen = true;
    await OrderAlarm.start();
    if (!mounted) {
      _dialogOpen = false;
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications_active, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('New Order!'),
        ]),
        content: Text('Order #${order.orderNumber} · ₹${order.total.toStringAsFixed(0)} · ${order.itemCount} items\n${order.customerName ?? ''}'),
        actions: [
          TextButton(
            onPressed: () async {
              await OrderAlarm.stop();
              if (mounted) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
              }
            },
            child: const Text('View'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () async {
              await OrderAlarm.stop();
              if (mounted) Navigator.pop(ctx);
              _advanceOrder(order.id, 'confirmed');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    await OrderAlarm.stop();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    OrderAlarm.stop();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await context.read<OrderProvider>().loadOrders();
    if (mounted) {
      _knownPending = context.read<OrderProvider>().pendingIds;
      await context.read<StatsProvider>().loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<AuthProvider>().vendor;
    return Scaffold(
      appBar: AppBar(
        title: Text(vendor?.tenantName.isNotEmpty == true ? vendor!.tenantName : 'My Store'),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildDashboard(),
          _buildOrders(),
          const ProductsScreen(),
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF97316),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = context.watch<StatsProvider>();
    final orders = context.watch<OrderProvider>();
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('Today', '₹${stats.todayRevenue.toStringAsFixed(0)}', '${stats.todayOrders} orders', Icons.payments_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('New orders', '${stats.pendingOrders}', 'need action', Icons.notifications_active_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Products', '${stats.totalProducts}', '${stats.activeProducts} active', Icons.inventory_2_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Low stock', '${stats.lowStock}', 'restock soon', Icons.warning_amber_outlined)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Needs your action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (orders.newOrders.isEmpty && orders.awaitingOrders.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('All caught up! No new orders.', style: TextStyle(color: Colors.grey))))),
          for (final o in [...orders.awaitingOrders, ...orders.newOrders].take(5))
            _orderCard(o),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, String sub, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.orange),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders() {
    final orderProv = context.watch<OrderProvider>();
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFFF97316),
            unselectedLabelColor: Colors.grey,
            tabs: [Tab(text: 'New'), Tab(text: 'Active'), Tab(text: 'Past')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _orderList([...orderProv.awaitingOrders, ...orderProv.newOrders], empty: 'No new orders', acceptPending: true),
                _orderList(orderProv.activeOrders, empty: 'No active orders'),
                _orderList(orderProv.pastOrders, empty: 'No past orders'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Order o) {
    final isPending = o.status == 'pending';
    final canAdvance = o.status == 'confirmed' || o.status == 'preparing';
    final showReady = o.status == 'ready';
    return OrderCard(
      order: o,
      showAccept: isPending,
      onAccept: isPending ? () => _advanceOrder(o.id, 'confirmed') : null,
      onReject: isPending ? () => _rejectOrder(o.id) : null,
      showActions: canAdvance || showReady,
      onAdvance: (canAdvance || showReady) && !isPending ? (next) => _advanceOrder(o.id, next) : null,
      onTap: () => _openDetail(o.id),
    );
  }

  Widget _orderList(List orders, {required String empty, bool acceptPending = false}) {
    if (orders.isEmpty) {
      return Center(child: Text(empty, style: const TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return RefreshIndicator(
      onRefresh: () => context.read<OrderProvider>().loadOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final o = orders[i] as Order;
          final isPending = o.status == 'pending';
          final canAdvance = o.status == 'confirmed' || o.status == 'preparing';
          final showReady = o.status == 'ready';
          return OrderCard(
            order: o,
            showAccept: acceptPending && isPending,
            onAccept: acceptPending && isPending ? () => _advanceOrder(o.id, 'confirmed') : null,
            onReject: acceptPending && isPending ? () => _rejectOrder(o.id) : null,
            showActions: !isPending && (canAdvance || showReady),
            onAdvance: !isPending && (canAdvance || showReady) ? (next) => _advanceOrder(o.id, next) : null,
            onTap: () => _openDetail(o.id),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(int orderId) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
    if (mounted) _refreshAll();
  }

  Future<void> _advanceOrder(int orderId, String next) async {
    final ok = await context.read<OrderProvider>().updateStatus(orderId, next);
    if (!mounted) return;
    if (next == 'confirmed') OrderAlarm.stop();
    if (mounted) _knownPending = context.read<OrderProvider>().pendingIds;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (next == 'confirmed'
              ? 'Order accepted'
              : next == 'preparing'
                  ? 'Cooking started'
                  : next == 'ready'
                      ? 'Marked ready — rider will pick up'
                      : next == 'cancelled'
                          ? 'Order rejected'
                          : 'Updated to $next')
          : 'Update failed'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  Future<void> _rejectOrder(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject order?'),
        content: const Text('The customer will be notified. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm == true) _advanceOrder(orderId, 'cancelled');
  }

  Widget _buildProfile() {
    final auth = context.watch<AuthProvider>();
    final v = auth.vendor;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront)),
            title: Text(v?.tenantName.isNotEmpty == true ? v!.tenantName : 'My Store'),
            subtitle: Text('${v?.name ?? ''}\n${v?.email ?? ''}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_outlined, color: Color(0xFFF97316)),
            title: const Text('Preparation time'),
            subtitle: const Text('How long your kitchen usually takes (mins)'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _editPrepTime,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            await auth.logout();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }

  Future<void> _editPrepTime() async {
    final prov = context.read<OrderProvider>();
    final cur = await prov.loadPrepTime();
    if (!mounted) return;
    final minCtrl = TextEditingController(text: '${cur['min'] ?? 15}');
    final maxCtrl = TextEditingController(text: '${cur['max'] ?? 25}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preparation time'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Shown to customers as "Usually takes X–Y min" and used for live ETA.'),
          const SizedBox(height: 12),
          TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum (mins)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum (mins)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final ok = await prov.savePrepTime(int.tryParse(minCtrl.text) ?? 15, int.tryParse(maxCtrl.text) ?? 25);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Preparation time saved' : 'Save failed'), backgroundColor: ok ? Colors.green : Colors.red));
  }
}
