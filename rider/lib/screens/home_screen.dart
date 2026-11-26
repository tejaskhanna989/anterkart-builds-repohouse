import 'dart:async';



import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import 'package:provider/provider.dart';

import '../models/order.dart';

import '../providers/auth_provider.dart';

import '../providers/order_provider.dart';

import '../providers/earnings_provider.dart';

import '../providers/location_provider.dart';

import '../services/api_service.dart';




import '../services/onesignal_service.dart';

import '../services/order_alarm.dart';
import '../services/alert_service.dart';

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

      await _refreshOrders();

      if (mounted) {
        final alertOrderId = await AlertService.pendingOrderId();
        final offers = context.read<OrderProvider>().offers;
        for (final offer in offers) {
          final orderId = int.tryParse('${offer['order_id']}') ?? 0;
          if (alertOrderId > 0 && orderId == alertOrderId) {
            final offerId = int.tryParse('${offer['offer_id']}') ?? -1;
            _shownOfferIds.add(offerId);
            await _handleNewOffer(offer);
            break;
          }
        }
      }

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

          await _handleNewOffer(newOffers.first);

        }

      };

      // Make sure the app may pull itself to the front for a new offer even
      // while the phone is in use ("Display over other apps").
      AlertService.ensureOverlayPermission();

    });

  }



  Future<void> _refreshOrders() async {

    final prov = context.read<OrderProvider>();

    await prov.loadOffers();

    await prov.loadPending();

    await prov.loadAssigned();

  }

  Future<void> _setAvailability(bool available) async {
    try {
      final res = await ApiService.post('rider/orders/availability_override.php', auth: true, body: {
        'is_available': available ? 1 : 0,
        'reason': available ? 'Available again' : 'Marked unavailable by rider',
      });
      if (!mounted) return;
      if (res['success'] == true) {
        final effectiveRaw = res['data']?['effective_available'];
        final effective = effectiveRaw is int
            ? effectiveRaw == 1
            : int.tryParse('${effectiveRaw ?? ''}') == 1;
        final auth = context.read<AuthProvider>();
        await auth.setEffectiveAvailability(effective);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(available ? 'You are now available' : 'You are now unavailable'), backgroundColor: Colors.green));
        await auth.refreshProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to update'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }


  Future<void> _reofferPendingOffers() async {

    final prov = context.read<OrderProvider>();

    final offers = prov.offers.where((o) => !_shownOfferIds.contains(int.tryParse('${o['offer_id']}') ?? -1)).toList();

    if (offers.isNotEmpty) {

      for (final o in offers) {

        final offerId = int.tryParse('${o['offer_id']}') ?? 0;

        if (offerId > 0) {

          // NOTE: rider/orders/reoffer.php does not exist on the live server
          // (404). The offer is already live, so surface it directly instead
          // of calling a dead endpoint.

        }

        _shownOfferIds.add(int.tryParse('${o['offer_id']}') ?? -1);

        await _handleNewOffer(o);

        break; // Show one at a time

      }

    }

  }

  /// Only riders that are close to the store get the full screen alarm.
  ///
  /// The distance is measured from the rider's own GPS position to the
  /// pickup point of the offer. Offers that are too far away are shown as a
  /// quiet notice instead, so the phone does not ring for a delivery the
  /// rider cannot reach in time.
  Future<void> _handleNewOffer(Map<String, dynamic> offer) async {

    // Every offer rings and pops up — assignment is pure first-tap-wins on
    // the server, so no distance filtering happens on the device.

    if (_dialogOpen) return;

    await _showRiderOfferModal(offer);

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



  /// Stop both the native alert (notification, wake lock, unlock listener) and
  /// the looping alarm sound.
  Future<void> _stopOfferAlert() async {
    await AlertService.stop();
    await OrderAlarm.stop();
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  String _kmText(dynamic km) {
    final d = _num(km);
    return d == null ? '—' : '${d.toStringAsFixed(1)} km';
  }

  String _minsText(dynamic mins) {
    final m = _num(mins);
    return m == null ? '' : ' (~${m.round()} min)';
  }

  String? _coordText(dynamic lat, dynamic lng) {
    final a = _num(lat);
    final b = _num(lng);
    if (a == null || b == null || (a == 0 && b == 0)) return null;
    return '${a.toStringAsFixed(4)}, ${b.toStringAsFixed(4)}';
  }

  String _storeText(Map<String, dynamic> off) {
    final name = '${off['store_name'] ?? ''}'.trim();
    final coords = _coordText(off['store_lat'], off['store_lng']);
    if (name.isNotEmpty && coords != null) return '$name · $coords';
    if (name.isNotEmpty) return name;
    return coords ?? '—';
  }

  LatLng? _point(dynamic lat, dynamic lng) {
    final a = _num(lat);
    final b = _num(lng);
    if (a == null || b == null || (a == 0 && b == 0)) return null;
    return LatLng(a, b);
  }

  Widget _offerInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _mapPin(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  /// Small route preview inside the offer dialog: rider → store → customer.
  Widget _offerMiniMap(Map<String, dynamic> off) {
    final rider = _point(off['rider_lat'], off['rider_lng']);
    final store = _point(off['store_lat'], off['store_lng']);
    final cust = _point(off['customer_lat'], off['customer_lng']);
    final center = rider ?? store ?? cust;
    if (center == null) return const SizedBox.shrink();
    final points = <LatLng>[
      if (rider != null) rider,
      if (store != null) store,
      if (cust != null) cust,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.otamzo.rider',
            ),
            if (points.length > 1)
              PolylineLayer(polylines: [Polyline(points: points, color: const Color(0xFF2563EB), strokeWidth: 4)]),
            MarkerLayer(markers: [
              if (rider != null) Marker(point: rider, width: 34, height: 34, child: _mapPin(const Color(0xFF2563EB), Icons.delivery_dining)),
              if (store != null) Marker(point: store, width: 34, height: 34, child: _mapPin(const Color(0xFF10B981), Icons.store)),
              if (cust != null) Marker(point: cust, width: 34, height: 34, child: _mapPin(const Color(0xFFEF4444), Icons.home)),
            ]),
          ],
        ),
      ),
    );
  }



  /// Persistent full-screen alarm for a new delivery offer. Rings until the

  /// rider accepts or declines — cannot be dismissed by tapping outside.

  Future<void> _showRiderOfferModal(Map<String, dynamic> off) async {

    _dialogOpen = true;

    // Native alert first: max alarm volume, wake lock, full-screen
    // notification and (when allowed) pull the app to the front — this is what
    // makes the phone ring even from the lock screen.
    await AlertService.start(
      title: 'New Delivery Offer',
      body: 'Order #${off['order_number']} · ₹${off['total']} — tap to accept',
      orderId: int.tryParse('${off['order_id']}') ?? 0,
    );

    if (!mounted) {

      _dialogOpen = false;

      await _stopOfferAlert();

      return;

    }

    final offerId = int.tryParse('${off['offer_id']}') ?? 0;

    await showDialog(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => WillPopScope(

        onWillPop: () async => false,

        child: AlertDialog(

          title: const Text('New Delivery Offer', style: TextStyle(fontWeight: FontWeight.bold)),

          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

              Text('Order #${off['order_number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

              const SizedBox(height: 4),

              Text('₹${off['total']}', style: const TextStyle(fontSize: 16)),

              const SizedBox(height: 12),

              _offerInfoRow(Icons.my_location, 'Your location', _coordText(off['rider_lat'], off['rider_lng']) ?? 'Locating…', const Color(0xFF2563EB)),

              _offerInfoRow(Icons.store, 'Pickup', _storeText(off), const Color(0xFF10B981)),

              _offerInfoRow(Icons.home, 'Deliver to', '${off['address'] ?? ''}'.trim().isEmpty ? '—' : '${off['address']}', const Color(0xFFEF4444)),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total trip: ${_kmText(off['total_km'])}${_minsText(off['total_mins'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('You → store: ${_kmText(off['to_store_km'])}${_minsText(off['to_store_mins'])}', style: const TextStyle(fontSize: 12)),
                  Text('Store → customer: ${_kmText(off['store_to_customer_km'])}${_minsText(off['store_to_customer_mins'])}', style: const TextStyle(fontSize: 12)),
                ]),
              ),

              const SizedBox(height: 10),

              _offerMiniMap(off),

              const SizedBox(height: 8),

              Text('Respond now — the alarm keeps ringing until you accept or decline.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),

            ]),
          ),

          actions: [

            TextButton(

              onPressed: () async {

                await _stopOfferAlert();

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

                await _stopOfferAlert();

                final r = await context.read<OrderProvider>().respondOffer(offerId, true);

                _dialogOpen = false;

                if (!mounted) return;

                Navigator.pop(ctx);

                _snack(r['message'] ?? 'Accepted', r['ok'] as bool);

                if ((r['ok'] as bool) && mounted) setState(() => _tab = 1);

                // Accepting locks the order, but the food only leaves the
                // counter once the rider proves the handover code. Ask for it
                // straight away instead of hiding it in the order detail.
                if ((r['ok'] as bool) && mounted) {

                  final data = r['data'];

                  final needsCode = data is Map && data['needs_code'] == true;

                  if (needsCode) {

                    final oid = int.tryParse('${off['order_id'] ?? 0}') ?? 0;

                    final onum = '${off['order_number'] ?? oid}';

                    if (oid > 0) await _askPickupCodeFor(oid, onum);

                  }

                }

              },

              child: const Text('Accept'),

            ),

          ],

        ),

      ),

    );

    _dialogOpen = false;

    await _stopOfferAlert();

  }



  Future<void> _askPickupCode(Order o) async {

    await _askPickupCodeFor(o.id, o.orderNumber);

  }



  /// Ask for the 4-digit counter handover code and verify it with the server.

  Future<void> _askPickupCodeFor(int orderId, String orderNumber) async {

    final ctrl = TextEditingController();

    final code = await showDialog<String>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => AlertDialog(

        title: Text('Pickup Code — #$orderNumber'),

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

    final r = await context.read<OrderProvider>().pickupOrder(orderId, code);

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

    final ok = r['ok'] as bool;

    _snack(r['message'] ?? 'Done', ok);

    if (!ok) return;

    // The server locks the order and asks for the counter code before the
    // handover: prompt for it right away instead of leaving it buried in the
    // "Assigned" tab.
    final data = r['data'];
    final needsCode = data is Map && data['needs_code'] == true;

    if (needsCode) {
      await _askPickupCode(o);
    }

    if (mounted) setState(() => _tab = 1);

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

        // Availability toggle for today
        StatefulBuilder(
          builder: (context, setState) {
            final isAvailable = rider?.available == 1;
            return SwitchListTile(
              secondary: Icon(isAvailable ? Icons.check_circle : Icons.cancel,
                  color: isAvailable ? Colors.green : Colors.red),
              title: Text(isAvailable ? 'Available today' : 'Unavailable today',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: isAvailable ? Colors.green[700] : Colors.red[700])),
              subtitle: Text(isAvailable
                  ? 'You will receive delivery offers'
                  : 'You will NOT receive delivery offers today'),
              value: isAvailable,
              activeColor: Colors.green,
              onChanged: (val) => _setAvailability(val),
            );
          },
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
