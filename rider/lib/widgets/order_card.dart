import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final bool showAccept;
  final bool showActions;
  final VoidCallback? onAccept;
  final VoidCallback? onStatusUpdate;
  final VoidCallback? onTap;
  final String? actionLabel;

  const OrderCard({super.key, required this.order, this.showAccept = false, this.showActions = false, this.onAccept, this.onStatusUpdate, this.onTap, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${order.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(order.customerName ?? 'Customer', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(width: 12),
                  const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${order.itemCount} items', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
              if (order.address != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(order.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(_statusText(order.status), style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: _statusColor(order.status),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(order.paymentMethod, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Spacer(),
                  if (showAccept)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  if (showActions && onStatusUpdate != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      onPressed: onStatusUpdate,
                      child: Text(actionLabel ?? (order.status == 'out_for_delivery' ? 'Delivered' : order.status == 'ready' ? 'Enter Code' : 'Start Delivery')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'preparing': return Colors.purple;
      case 'ready': return Colors.teal;
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
      case 'ready': return 'Ready for pickup';
      case 'out_for_delivery': return 'On the Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return s;
    }
  }
}
