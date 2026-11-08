import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool showBack;
  const OrdersScreen({super.key, this.showBack = false});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OrderProvider>().loadOrders());
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

  @override
  Widget build(BuildContext context) {
    final orderProv = context.watch<OrderProvider>();
    return Scaffold(
      appBar: widget.showBack ? AppBar(title: const Text('My Orders')) : null,
      body: orderProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProv.orders.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 80, color: Colors.grey), SizedBox(height: 16), Text('No orders yet', style: TextStyle(fontSize: 18, color: Colors.grey))]))
              : RefreshIndicator(
                  onRefresh: () async => context.read<OrderProvider>().loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orderProv.orders.length,
                    itemBuilder: (_, i) {
                      final o = orderProv.orders[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _statusColor(o.status).withOpacity( 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(_statusText(o.status), style: TextStyle(color: _statusColor(o.status), fontWeight: FontWeight.w600, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${o.itemCount} items • ₹${o.total.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600])),
                                if (o.createdAt.isNotEmpty)
                                  Builder(builder: (_) {
                                    try {
                                      return Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(o.createdAt)), style: TextStyle(color: Colors.grey[500], fontSize: 12));
                                    } catch (_) {
                                      return Text(o.createdAt, style: TextStyle(color: Colors.grey[500], fontSize: 12));
                                    }
                                  }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
