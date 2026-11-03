import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_time.dart';

/// Full order view with timing (placed / updated / completed) and the same
/// accept → cook → ready actions as the order cards. No dead ends.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final Order? order;
  const OrderDetailScreen({super.key, required this.orderId, this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final fresh = await context.read<OrderProvider>().loadDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _loading = false;
    });
  }

  Future<void> _advance(String next) async {
    setState(() => _acting = true);
    final ok = await context.read<OrderProvider>().updateStatus(widget.orderId, next);
    if (!mounted) return;
    setState(() => _acting = false);
    if (ok) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next == 'confirmed'
            ? 'Order accepted'
            : next == 'preparing'
                ? 'Cooking started'
                : next == 'ready'
                    ? 'Marked ready — rider will pick up'
                    : next == 'cancelled'
                        ? 'Order rejected'
                        : 'Updated to $next'),
        backgroundColor: Colors.green,
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(order != null ? 'Order #${order.orderNumber}' : 'Order #${widget.orderId}')),
      body: _loading && order == null
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _statusBadge(order.status),
                        const SizedBox(height: 12),
                        if (order.pickupCode.isNotEmpty && (order.status == 'ready' || order.status == 'preparing'))
                          Card(
                            color: const Color(0xFFFFF7ED),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                const Icon(Icons.key, color: Color(0xFFF97316)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Handover code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(order.pickupCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6)),
                                  ]),
                                ),
                                const Text('Show at\ncounter', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ]),
                            ),
                          ),
                        if (order.pickupCode.isNotEmpty && (order.status == 'ready' || order.status == 'preparing')) const SizedBox(height: 4),
                        if (order.deliveryBoyId != 0 && order.status == 'ready')
                          Card(
                            color: order.riderArrivedAt.isNotEmpty ? const Color(0xFFECFDF5) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Icon(Icons.delivery_dining, color: order.riderArrivedAt.isNotEmpty ? const Color(0xFF10B981) : Colors.grey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    order.riderArrivedAt.isNotEmpty ? 'Rider is waiting at the counter — hand over the food.' : 'Rider secured and on the way to your store.',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        if (order.deliveryBoyId != 0 && order.status == 'ready') const SizedBox(height: 4),
                        // Timing card: placed / elapsed / updated / completed.
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                _timeRow(Icons.schedule, 'Placed', '${formatClock(order.createdAt)}${elapsedSince(order.createdAt).isEmpty ? '' : ' · ${elapsedSince(order.createdAt)}'}'),
                                if (order.updatedAt.isNotEmpty && order.updatedAt != order.createdAt)
                                  _timeRow(
                                    order.status == 'delivered' ? Icons.check_circle : Icons.update,
                                    order.status == 'delivered'
                                        ? 'Completed'
                                        : order.status == 'cancelled'
                                            ? 'Cancelled'
                                            : 'Last update',
                                    formatClock(order.updatedAt),
                                  ),
                                if (order.etaMinutes > 0) _timeRow(Icons.delivery_dining, 'ETA', '${order.etaMinutes} min'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(order.customerName ?? 'Customer'),
                            subtitle: Text(order.customerPhone ?? ''),
                            trailing: order.customerPhone != null
                                ? IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:${order.customerPhone}')))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.red),
                            title: const Text('Delivery Address'),
                            subtitle: Text(order.address ?? 'No address'),
                            trailing: IconButton(
                              icon: const Icon(Icons.directions, color: Color(0xFF2563EB)),
                              onPressed: () {
                                final addr = Uri.encodeComponent(order.address ?? '');
                                launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$addr'));
                              },
                            ),
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
                          Chip(label: Text(order.paymentMethod, style: const TextStyle(fontSize: 12))),
                        ]),
                        const SizedBox(height: 16),
                        ..._actionButtons(order),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _timeRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  List<Widget> _actionButtons(Order order) {
    if (_acting) return [const Center(child: CircularProgressIndicator())];
    switch (order.status) {
      case 'pending':
        return [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _advance('cancelled'),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () => _advance('confirmed'),
                child: const Text('Accept Order'),
              ),
            ),
          ]),
        ];
      case 'confirmed':
        return [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () => _advance('preparing'),
              child: const Text('Start Cooking'),
            ),
          ),
        ];
      case 'preparing':
        return [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
              onPressed: () => _advance('ready'),
              child: const Text('Mark Ready for Pickup'),
            ),
          ),
        ];
      case 'ready':
        return const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Expanded(child: Text('Order is ready. Waiting for rider pickup — no action needed.', style: TextStyle(fontSize: 13))),
              ]),
            ),
          ),
        ];
      case 'out_for_delivery':
        return const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.delivery_dining, color: Color(0xFFF97316)),
                SizedBox(width: 10),
                Expanded(child: Text('Rider has picked up the order.', style: TextStyle(fontSize: 13))),
              ]),
            ),
          ),
        ];
      default:
        return const [];
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
      'ready': 'Ready',
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
