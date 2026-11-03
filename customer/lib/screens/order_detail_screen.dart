import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import 'order_tracking_screen.dart';
import 'chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await context.read<OrderProvider>().loadOrderDetail(widget.orderId);
    if (!mounted) return;
    setState(() { _order = o; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('Order Detail')), body: const Center(child: CircularProgressIndicator()));
    if (_order == null) return Scaffold(appBar: AppBar(title: const Text('Order Detail')), body: const Center(child: Text('Order not found')));

    final o = _order!;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${o.orderNumber}'), actions: [
        IconButton(
          icon: const Icon(Icons.chat_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: o.id, title: 'Rider Chat', myRole: 'customer'))),
        ),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Status', Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _statusColor(o.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusText(o.status), style: TextStyle(color: _statusColor(o.status), fontWeight: FontWeight.bold)),
            )),
            if (o.etaMinutes != null) ...[
              const SizedBox(height: 8),
              Text('ETA: ${o.etaMinutes} minutes', style: const TextStyle(color: Color(0xFF2563EB))),
            ],
            const SizedBox(height: 16),
            _section('Items', Column(
              children: o.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${item.name} x${item.quantity}')),
                    Text('₹${(item.price * item.quantity).toStringAsFixed(0)}'),
                  ],
                ),
              )).toList(),
            )),
            const Divider(height: 32),
            _priceRow('Subtotal', '₹${o.subtotal.toStringAsFixed(0)}'),
            _priceRow('Tax', '₹${o.tax.toStringAsFixed(0)}'),
            _priceRow('Delivery', '₹${o.deliveryFee.toStringAsFixed(0)}'),
            const Divider(),
            _priceRow('Total', '₹${o.total.toStringAsFixed(0)}', bold: true),
            const SizedBox(height: 16),
            if (o.riderName != null) ...[
              _section('Rider', Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
                title: Text(o.riderName!),
                subtitle: Text(o.riderPhone ?? ''),
              ))),
              const SizedBox(height: 12),
            ],
            if (o.status != 'delivered' && o.status != 'cancelled')
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: o.id))),
                  child: const Text('Track Order'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      child,
    ]);
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: bold ? Colors.black : Colors.grey)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: bold ? const Color(0xFF2563EB) : Colors.black)),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'preparing': return Colors.purple;
      case 'out_for_delivery': return const Color(0xFFF97316);
      case 'delivered': return const Color(0xFF10B981);
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'out_for_delivery': return 'On the Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return s;
    }
  }
}
