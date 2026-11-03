import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import 'chat_screen.dart';

/// Rider order workspace: arrived swipes, counter-code pickup, navigation,
/// customer call, and delivery swipe — driven by live detail reloads.
class OrderDetailScreen extends StatefulWidget {
  final int? orderId;
  final Order? order;
  const OrderDetailScreen({super.key, this.orderId, this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = false;
  bool _acting = false;

  int get _id => widget.orderId ?? widget.order?.id ?? 0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload();
  }

  Future<void> _reload() async {
    if (_id == 0) return;
    setState(() => _loading = true);
    final list = context.read<OrderProvider>().assignedOrders;
    Order? found;
    for (final o in list) {
      if (o.id == _id) found = o;
    }
    found ??= await context.read<OrderProvider>().loadDetail(_id);
    if (mounted) {
      setState(() {
        if (found != null) _order = found;
        _loading = false;
      });
    }
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
  }

  Future<void> _arrived(String at) async {
    setState(() => _acting = true);
    final r = await context.read<OrderProvider>().markArrived(_id, at);
    if (mounted) setState(() => _acting = false);
    _snack(r['message'] ?? 'Done', r['ok'] as bool);
    if (r['ok'] == true) _reload();
  }

  Future<void> _askCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pickup code — #${_order?.orderNumber ?? ''}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ask the counter for the 4-digit handover code.'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Verify Pickup')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _acting = true);
    final r = await context.read<OrderProvider>().pickupOrder(_id, code);
    if (mounted) setState(() => _acting = false);
    _snack(r['message'] ?? 'Done', r['ok'] as bool);
    if (r['ok'] == true) _reload();
  }

  Future<void> _deliver() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery code?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ask the customer for the code shown in their app, then hand over the food.'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Customer code', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not yet')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Complete delivery')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _acting = true);
    final r = await context.read<OrderProvider>().updateStatusEx(_id, 'delivered', code: code);
    if (mounted) setState(() => _acting = false);
    _snack(r['message'] ?? 'Done', r['ok'] as bool);
    if (r['ok'] == true) {
      _reload();
    } else if (mounted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Code not accepted'),
          content: const Text('Wrong code? Ask the customer to resend it from their app, or tap below to send them a fresh code.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resend code')),
          ],
        ),
      );
      if (retry == true && mounted) {
        final rs = await context.read<OrderProvider>().resendDeliveryCode(_id);
        _snack(rs['message'] ?? 'Done', rs['ok'] as bool);
      }
    }
  }

  Future<void> _callCustomer() async {
    final r = await context.read<OrderProvider>().callCustomer(_id);
    if (!mounted) return;
    if (r['masked'] == true) {
      _snack(r['message'] ?? 'Connecting your call…', true);
    } else if ('${r['number'] ?? ''}'.isNotEmpty) {
      launchUrl(Uri.parse('tel:${r['number']}'));
    } else {
      _snack(r['message'] ?? 'Call failed', false);
    }
  }

  void _navigate() {
    final addr = Uri.encodeComponent(_order?.address ?? '');
    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$addr&travelmode=driving&dir_action=navigate'));
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(order != null ? 'Order #${order.orderNumber}' : 'Order'), actions: [
        if (order != null)
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: order.id, title: 'Customer Chat', myRole: 'rider'))),
          ),
      ]),
      body: _loading && order == null
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _statusBadge(order.status),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(order.customerName ?? 'Customer'),
                          subtitle: Text(order.customerPhone ?? ''),
                          trailing: order.customerPhone != null
                              ? IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: _callCustomer)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: const Text('Delivery Address'),
                          subtitle: Text(order.address ?? 'No address'),
                          trailing: IconButton(icon: const Icon(Icons.directions, color: Color(0xFF2563EB)), onPressed: _navigate),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('${item.name} x${item.quantity}'),
                              Text('₹${(item.price * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          )),
                      const Divider(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('₹${order.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ]),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Payment'),
                        Chip(label: Text('${order.paymentMethod} • ${order.paymentStatus}', style: const TextStyle(fontSize: 12))),
                      ]),
                      const SizedBox(height: 16),
                      if (_acting) const Center(child: CircularProgressIndicator()) else ..._actions(order),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
    );
  }

  List<Widget> _actions(Order order) {
    switch (order.status) {
      case 'ready':
        return [
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _arrived('store'), icon: const Icon(Icons.storefront), label: const Text("I've arrived at the restaurant"))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _askCode, child: const Text('Enter pickup code'))),
        ];
      case 'out_for_delivery':
        return [
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _navigate, icon: const Icon(Icons.navigation), label: const Text('Navigate'))),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: order.customerPhone != null ? _callCustomer : null,
                icon: const Icon(Icons.phone),
                label: const Text('Call customer'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _arrived('customer'), icon: const Icon(Icons.location_on), label: const Text("I've arrived at the door"))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: _deliver,
              child: const Text('Swipe delivered — order complete'),
            ),
          ),
        ];
      default:
        return [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_statusHint(order.status), style: const TextStyle(fontSize: 13)))),
        ];
    }
  }

  String _statusHint(String s) {
    switch (s) {
      case 'confirmed':
      case 'preparing':
        return 'Waiting for the kitchen to finish cooking. You will be notified when the food is ready for pickup.';
      case 'delivered':
        return 'Delivered. Nothing more to do here.';
      case 'cancelled':
        return 'This order was cancelled.';
      default:
        return 'Status: $s';
    }
  }

  Widget _statusBadge(String status) {
    final colors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': Colors.purple,
      'ready': Colors.teal,
      'out_for_delivery': const Color(0xFFF97316),
      'delivered': const Color(0xFF10B981),
      'cancelled': Colors.red,
    };
    final labels = {
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'preparing': 'Preparing',
      'ready': 'Ready for pickup',
      'out_for_delivery': 'Out for Delivery',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(labels[status] ?? status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
