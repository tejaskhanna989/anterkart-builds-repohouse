import 'package:flutter/material.dart';
import '../models/order.dart';
import 'order_time.dart';

/// Vendor order card with per-status actions:
/// pending -> Accept / Reject, confirmed -> Start Cooking,
/// preparing -> Mark Ready, ready -> "waiting for rider" info,
/// delivered -> completion time, cancelled -> chip. No dead ends.
class OrderCard extends StatelessWidget {
  final Order order;
  final bool showAccept;
  final bool showActions;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final ValueChanged<String>? onAdvance;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.showAccept = false,
    this.showActions = false,
    this.onAccept,
    this.onReject,
    this.onAdvance,
    this.onTap,
    // ignore: unused_element_parameter
    VoidCallback? onStatusUpdate,
  });

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
              const SizedBox(height: 4),
              // Timing row: placed time + elapsed, updated/completed time.
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Placed ${formatClock(order.createdAt)}${elapsedSince(order.createdAt).isEmpty ? '' : ' · ${elapsedSince(order.createdAt)}'}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
              if (order.updatedAt.isNotEmpty && order.updatedAt != order.createdAt && (order.status == 'delivered' || order.status == 'cancelled' || order.status == 'ready' || order.status == 'out_for_delivery'))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    order.status == 'delivered'
                        ? 'Completed ${formatClock(order.updatedAt)}'
                        : order.status == 'cancelled'
                            ? 'Cancelled ${formatClock(order.updatedAt)}'
                            : 'Updated ${formatClock(order.updatedAt)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: order.status == 'delivered' ? FontWeight.w600 : FontWeight.w400),
                  ),
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
                  if (order.deliveryBoyId != 0 && (order.status == 'ready' || order.status == 'preparing')) ...[
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.delivery_dining, size: 14, color: Colors.white),
                      label: Text(order.riderArrivedAt.isNotEmpty ? 'Rider waiting' : 'Rider coming', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: order.riderArrivedAt.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFF97316),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                  const Spacer(),
                  ..._actionButtons(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actionButtons(BuildContext context) {
    final s = order.status;
    if (s == 'pending' && showAccept) {
      return [
        TextButton(onPressed: onReject, child: const Text('Reject', style: TextStyle(color: Colors.red))),
        const SizedBox(width: 4),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          onPressed: onAccept ?? (onAdvance != null ? () => onAdvance!('confirmed') : null),
          child: const Text('Accept'),
        ),
      ];
    }
    if (!showActions) return const [];
    if (s == 'confirmed') {
      return [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          onPressed: onAdvance != null ? () => onAdvance!('preparing') : null,
          child: const Text('Start Cooking'),
        ),
      ];
    }
    if (s == 'preparing') {
      return [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
          onPressed: onAdvance != null ? () => onAdvance!('ready') : null,
          child: const Text('Mark Ready'),
        ),
      ];
    }
    if (s == 'ready') {
      return const [
        Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 6),
          Text('Waiting for rider', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ];
    }
    return const [];
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
      case 'ready': return 'Ready';
      case 'out_for_delivery': return 'On the Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return s;
    }
  }
}
