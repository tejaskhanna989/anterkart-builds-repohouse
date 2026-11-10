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

  Timer? _reofferTimer;

  final Set<int> _shownOfferIds = {};

  bool _dialogOpen = false;

  bool _isBackground = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      _refreshOrders();

      context.read<EarningsProvider>().loadEarnings();

      context.read<LocationProvider>().startTracking();

      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {

        if (!mounted) return;

        _refreshOrders();

      });

      // Re-offer timer: re-send offers every 2 seconds until accepted

      _reofferTimer = Timer.periodic(const Duration(seconds: 2), (_) {

        if (!mounted) return;

        _reofferPendingOffers();

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



  Future<void> _reofferPendingOffers() async {

    final prov = context.read<OrderProvider>();

    final offers = prov.offers.where((o) => !_shownOfferIds.contains(int.tryParse('${o['offer_id']}') ?? -1)).toList();

    if (offers.isNotEmpty) {

      for (final o in offers) {

        final offerId = int.tryParse('${o['offer_id']}') ?? 0;

        if (offerId > 0) {

          await prov.reofferOrder(offerId);

        }

        _shownOfferIds.add(int.tryParse('${o['offer_id']}') ?? -1);

        _showRiderOfferModal(o);

        break; // Show one at a time

      }

    }

  }



  @override

  void dispose() {

    _pollTimer?.cancel();

    _reofferTimer?.cancel();

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

            Text('Respond now — the alarm keeps ringing until you accept or decline.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),

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

    final ctrl = TextEditingController();

    final code = await showDialog<String>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => AlertDialog(

        title: Text('Pickup Code — #${o.orderNumber}'),

        content: Column(mainAxisSize: MainAxisSize.min, children: [

          const Text('Ask the counter for the 4-digit handover code.'),

          const SizedBox(height: 12),

          TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder())),

        ]),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),

          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Verify')),

        ],

      ),

    );

    if (code == null || code.isEmpty) return;

    final r = await context.read<OrderProvider>().pickupOrder(o.id, code);

    _snack(r['message'] ?? (r['ok'] as bool ? 'Picked up!' : 'Failed'), r['ok'] as bool);

  }



  Future<void> _advanceOrder(int orderId, String status) async {

    final r = await context.read<OrderProvider>().updateStatusEx(orderId, status);

    _snack(r['message'] ?? (r['ok'] as bool ? 'Done' : 'Failed'), r['ok'] as bool);

  }



  @override

  Widget build(BuildContext context) {

    final orderProv = context.watch<OrderProvider>();

    return Scaffold(

      body: IndexedStack(

        index: _tab,

        children: [

          _buildPendingOrders(),

          _buildMyDeliveries(),

          _buildEarnings(),

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

          BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Pending'),

          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), activeIcon: Icon(Icons.local_shipping), label: 'My Orders'),

          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),

          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),

        ],

      ),

    );

  }



  Widget _buildPendingOrders() {

    final orderProv = context.watch<OrderProvider>();

    return RefreshIndicator(

      onRefresh: _refreshOrders,

      child: ListView(

        padding: const EdgeInsets.all(12),

        children: [

          if (orderProv.offers.isNotEmpty) ...[

            const Padding(

              padding: EdgeInsets.symmetric(vertical: 4),

              child: Text('Delivery offers — fastest finger first', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),

            ),

            for (final off in orderProv.offers) _offerCard(off),

            const Divider(height: 24),

          ],

          const Padding(

            padding: EdgeInsets.symmetric(vertical: 4),

            child: Text('Ready for pickup near you', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),

          ),

          if (orderProv.pendingOrders.isEmpty)

            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No pending orders', style: TextStyle(color: Colors.grey, fontSize: 16)))),

          for (final o in orderProv.pendingOrders)

            OrderCard(

              order: o,

              showAccept: true,

              onAccept: () => _acceptPool(o),

              onTap: () async {

                await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));

                if (mounted) _refreshOrders();

              },

            ),

        ],

      ),

    );

  }



  Future<void> _acceptPool(Order o) async {

    final r = await context.read<OrderProvider>().acceptOrder(o.id);

    if (!mounted) return;

    _snack(r['message'] ?? 'Done', r['ok'] as bool);

    if ((r['ok'] as bool) && mounted) setState(() => _tab = 1);

  }



  Widget _offerCard(Map<String, dynamic> off) {

    final secs = int.tryParse('${off['expires_in']}') ?? 0;

    return Card(

      color: const Color(0xFFFFF7ED),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFF97316))),

      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

            Text('Order #${off['order_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

            Text('₹${off['total']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 16)),

          ]),

          const SizedBox(height: 4),

          Text('${off['address'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 13)),

          const SizedBox(height: 4),

          Text('Expires in ${secs}s', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),

          const SizedBox(height: 8),

          Row(children: [

            Expanded(child: OutlinedButton(onPressed: () async {

              final r = await context.read<OrderProvider>().respondOffer(int.parse('${off['offer_id']}'), false);

              _snack(r['message'] ?? 'Declined', r['ok'] as bool);

            }, child: const Text('Decline'))),

            const SizedBox(width: 12),

            Expanded(child: ElevatedButton(

              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),

              onPressed: () async {

                final r = await context.read<OrderProvider>().respondOffer(int.parse('${off['offer_id']}'), true);

                _snack(r['message'] ?? 'Accepted', r['ok'] as bool);

                if ((r['ok'] as bool) && mounted) setState(() => _tab = 1);

              },

              child: const Text('Accept'),

            )),

          ]),

        ]),

      ),

    );

  }



  Widget _buildMyDeliveries() {

    final orderProv = context.watch<OrderProvider>();

    return RefreshIndicator(

      onRefresh: () => context.read<OrderProvider>().loadAssigned(),

      child: orderProv.assignedOrders.isEmpty

          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.local_shipping, size: 80, color: Colors.grey), SizedBox(height: 16), Text('No active deliveries', style: TextStyle(color: Colors.grey, fontSize: 16))]))

          : ListView.builder(

              padding: const EdgeInsets.all(12),

              itemCount: orderProv.assignedOrders.length,

              itemBuilder: (_, i) {

                final o = orderProv.assignedOrders[i];

                return OrderCard(

                  order: o,

                  showActions: o.status == 'ready' || o.status == 'out_for_delivery',

                  actionLabel: o.status == 'out_for_delivery' ? 'Deliver with code' : null,

                  onStatusUpdate: o.status == 'ready'

                      ? () => _askPickupCode(o)

                      : o.status == 'out_for_delivery'

                          ? () async {

                              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));

                              if (mounted) _refreshOrders();

                            }

                          : null,

                  onTap: () async {

                    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));

                    if (mounted) _refreshOrders();

                  },

                );

              },

            ),

    );

  }



  Widget _buildEarnings() {

    final ep = context.watch<EarningsProvider>();

    final earnings = ep.earnings;

    final codOut = earnings?.codOutstanding ?? 0;

    return ListView(

      padding: const EdgeInsets.all(16),

      children: [

        const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

        const SizedBox(height: 16),

        if (codOut > 0)

          Card(

            color: const Color(0xFFFEF3C7),

            child: Padding(

              padding: const EdgeInsets.all(16),

              child: Row(children: [

                const Icon(Icons.payments_outlined, color: Color(0xFFB45309), size: 30),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    Text('₹${codOut.toStringAsFixed(0)} cash with you', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),

                    const Text('COD collected — hand it to the store/admin', style: TextStyle(fontSize: 12, color: Colors.grey)),

                  ]),

                ),

              ]),

            ),

          ),

        if (codOut > 0) const SizedBox(height: 12),

        Row(

          children: [

            _statCard('Total', '₹${earnings?.totalEarnings.toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet, Colors.blue),

            const SizedBox(width: 12),

            _statCard('Today', '₹${earnings?.todayEarnings.toStringAsFixed(0) ?? '0'}', Icons.today, Colors.green),

          ],

        ),

        const SizedBox(height: 12),

        Row(

          children: [

            _statCard('Total Deliveries', '${earnings?.totalDeliveries ?? 0}', Icons.delivery_dining, Colors.purple),

            const SizedBox(width: 12),

            _statCard('Today Deliveries', '${earnings?.todayDeliveries ?? 0}', Icons.check_circle, Colors.orange),

          ],

        ),

        const SizedBox(height: 24),

        const Text('This Week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

        const SizedBox(height: 12),

        if (earnings?.weekly.isEmpty ?? true)

          const Center(child: Text('No deliveries this week', style: TextStyle(color: Colors.grey)))

        else

          ...earnings!.weekly.map((w) => Card(child: ListTile(title: Text(w.date), trailing: Text('₹${w.earnings.toStringAsFixed(0)} (${w.deliveries} deliveries)', style: const TextStyle(fontWeight: FontWeight.w600))))),

      ],

    );

  }



  Widget _statCard(String label, String value, IconData icon, Color color) {

    return Expanded(

      child: Card(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(children: [

            Icon(icon, color: color, size: 30),

            const SizedBox(height: 8),

            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),

            const SizedBox(height: 4),

            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),

          ]),

        ),

      ),

    );

  }



  Widget _buildProfile() {

    final auth = context.watch<AuthProvider>();

    final rider = auth.rider;

    return ListView(

      padding: const EdgeInsets.all(16),

      children: [

        CircleAvatar(radius: 40, backgroundColor: const Color(0xFF2563EB).withOpacity( 0.1), child: Text(rider?.name.isNotEmpty == true ? rider!.name[0].toUpperCase() : 'R', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),

        const SizedBox(height: 12),

        Center(child: Text(rider?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),

        Center(child: Text(rider?.email ?? '', style: TextStyle(color: Colors.grey[600]))),

        const SizedBox(height: 8),

        Center(child: Text('${rider?.vehicle ?? ''} • ${rider?.phone ?? ''}', style: TextStyle(color: Colors.grey[500]))),

        const SizedBox(height: 24),

        ListTile(leading: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB)), title: const Text('Vehicle'), subtitle: Text(rider?.vehicle ?? 'Not set')),

        const Divider(),

        ListTile(

          leading: Icon(rider?.status == 'active' ? Icons.check_circle : Icons.cancel, color: rider?.status == 'active' ? Colors.green : Colors.red),

          title: Text('Status: ${rider?.status == 'active' ? 'Active' : 'Inactive'}'),

        ),

        const Divider(),

        ListTile(

          leading: const Icon(Icons.logout, color: Colors.red),

          title: const Text('Logout', style: TextStyle(color: Colors.red)),

          onTap: () async {

            context.read<LocationProvider>().stopTracking();

            await auth.logout();

            if (!mounted) return;

            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));

          },

        ),

      ],

    );

  }

}