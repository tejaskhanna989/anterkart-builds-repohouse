import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/earnings_provider.dart';
import '../providers/location_provider.dart';
import '../services/onesignal_service.dart';
import '../services/order_alarm.dart';
import '../widgets/order_card.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Timer? _pollTimer;
  final Set<int> _shownOfferIds = {};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _refreshOrders();
      context.read<EarningsProvider>().loadEarnings();
      context.read<LocationProvider>().startTracking();
      _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (!mounted) return;
        _refreshOrders();
      });
      // Show push popups when the app is open (foreground).
      OneSignalService.addListeners();
      OneSignalService.onForegroundPush = () async {
        if (!mounted || _dialogOpen) return;
        await _refreshOrders();
        final prov = context.read<OrderProvider>();
        final newOffers = prov.offers.where((o) => !_shownOfferIds.contains(int.tryParse('${o['offer_id']}') ?? -1)).toList();
        if (newOffers.isNotEmpty) {
          for (final o in newOffers) _shownOfferIds.add(int.tryParse('${o['offer_id']}') ?? -1);
          _showRiderOfferModal(newOffers.first);
        }
      };
    });
  }

  Future<void> _refreshOrders() async {
    final prov = context.read<OrderProvider>();
    await prov.loadOffers();
    await prov.loadPending();
    await prov.loadAssigned();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
  }

  /// Persistent full-screen alarm for a new delivery offer. Rings until the
  /// rider accepts or declines — cannot be dismissed by tapping outside.
  Future<void> _showRiderOfferModal(Map<String, dynamic> off) async {
    _dialogOpen = true;
    await OrderAlarm.start();
    if (!mounted) return;
    final offerId = int.tryParse('${off['offer_id']}') ?? 0;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('New Delivery Offer', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Order #${off['order_number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('₹${off['total']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Respond now — the alarm keeps ringing until you accept or decline.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                await OrderAlarm.stop();
                final r = await context.read<OrderProvider>().respondOffer(offerId, false);
                _dialogOpen = false;
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack(r['message'] ?? 'Declined', r['ok'] as bool);
                await _refreshOrders();
              },
              child: const Text('Decline'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                await OrderAlarm.stop();
                final r = await context.read<OrderProvider>().respondOffer(offerId, true);
                _dialogOpen = false;
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack(r['message'] ?? 'Accepted', r['ok'] as bool);
                if ((r['ok'] as bool) && mounted) setState(() => _tab = 1);
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    await OrderAlarm.stop();
  }

  Future<void> _askPickupCode(Order o) async {