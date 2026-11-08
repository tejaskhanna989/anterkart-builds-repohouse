import 'package:flutter/material.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';

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
                              ]),
                            ),
                          ),
                        if (order.pickupCode.isNotEmpty && (order.status == 'ready' || order.status == 'preparing')) const SizedBox(height: 4),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
              ),
            );
          }

  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      case 'confirmed':
        color = Colors.blue;
        icon = Icons.check_circle;
        label = 'Confirmed';
        break;
      case 'preparing':
        color = Colors.orange;
        icon = Icons.restaurant;
        label = 'Preparing';
        break;
      case 'ready':
        color = Colors.purple;
        icon = Icons.inventory;
        label = 'Ready';
        break;
      case 'out_for_delivery':
        color = Colors.blue;
        icon = Icons.local_shipping;
        label = 'Out for Delivery';
        break;
      case 'delivered':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        label = status;
    }
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String formatClock(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String elapsedSince(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  List<Widget> _actionButtons(Order order) {
    if (_acting) return [const Center(child: CircularProgressIndicator())];
    switch (order.status) {
      case 'pending':
        return [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                onPressed: () => _advance('cancelled'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
                onPressed: () => _advance('confirmed'),
              ),
            ),
          ],
        );
      case 'confirmed':
        return [
          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant),
            label: const Text('Start Cooking'),
            onPressed: () => _advance('preparing'),
          ),
        ];
      case 'preparing':
        return [
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark Ready'),
            onPressed: () => _advance('ready'),
          ),
        ];
      case 'ready':
        return [
          ElevatedButton.icon(
            icon: const Icon(Icons.assignment_return),
            label: const Text('Mark Picked Up'),
            onPressed: () => _advance('out_for_delivery'),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
