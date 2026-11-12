import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import 'orders_screen.dart';
import 'product_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  Future<void> _refresh() async {
    await context.read<NotificationProvider>().load();
  }

  String _timeAgo(String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _open(NotificationProvider provider, AppNotification n) {
    if (!n.isRead) {
      provider.markRead([n.id]);
    }
    final orderMatch = RegExp(r'^/order/(\d+)$').firstMatch(n.link);
    if (orderMatch != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen()));
      return;
    }
    final productMatch = RegExp(r'^/product/(\d+)$').firstMatch(n.link);
    if (productMatch != null) {
      final pid = int.tryParse(productMatch.group(1)!) ?? 0;
      if (pid > 0) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: pid)));
      }
    }
  }

  void _markAll() async {
    final provider = context.read<NotificationProvider>();
    await provider.markAllRead();
    await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0C55E0),
        foregroundColor: Colors.white,
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.isLoading ? null : _markAll,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: provider.isLoading && provider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.notifications.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final n = provider.notifications[i];
                      return Material(
                        color: n.isRead ? Colors.white : const Color(0xFF0C55E0).withOpacity( 0.06),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _open(provider, n),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: n.isRead ? const Color(0xFFEEEEEE) : const Color(0xFF0C55E0).withOpacity( 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active,
                                    color: const Color(0xFF0C55E0), size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(n.title,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                          ),
                                          if (!n.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(left: 6),
                                              decoration: const BoxDecoration(
                                                  color: Color(0xFFF97316), shape: BoxShape.circle),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(n.message,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                                      const SizedBox(height: 6),
                                      Text(_timeAgo(n.createdAt),
                                          style:
                                              const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A))),
                                    ],
                                  ),
                                ),
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