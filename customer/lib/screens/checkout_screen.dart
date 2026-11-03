import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../models/cart_item.dart';
import '../models/store_settings.dart';
import 'order_success_screen.dart';

class _VendorGroup {
  final int tenantId;
  final String name;
  final String slug;
  final List<CartItem> items;
  final double subtotal;
  _VendorGroup({required this.tenantId, required this.name, required this.slug, required this.items, required this.subtotal});
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'COD';
  String _address = '';
  int? _deliveryZoneId;
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  bool _placing = false;
  Razorpay? _razorpay;
  StoreSettings _settings = StoreSettings();
  bool _settingsLoaded = false;
  final Map<int, StoreSettings> _vendorSettings = {};
  // Per-km delivery quote (server-computed). Active only when the store has
  // a per-km rate configured; otherwise flat settings fees apply as before.
  double? _quotedFee;
  double? _quotedKm;

  List<_VendorGroup> _vendorGroups(List<CartItem> items) {
    final order = <int>[];
    final map = <int, List<CartItem>>{};
    for (final i in items) {
      if (!map.containsKey(i.tenantId)) { map[i.tenantId] = []; order.add(i.tenantId); }
      map[i.tenantId]!.add(i);
    }
    return order.map((tid) {
      final list = map[tid]!;
      final sub = list.fold(0.0, (s, i) => s + i.lineTotal);
      return _VendorGroup(tenantId: tid, name: list.first.vendor.isNotEmpty ? list.first.vendor : 'Store', slug: list.first.vendorSlug.isNotEmpty ? list.first.vendorSlug : '$tid', items: list, subtotal: sub);
    }).toList();
  }

  Future<void> _loadVendorSettings() async {
    final cart = context.read<CartProvider>();
    final groups = _vendorGroups(cart.items);
    if (groups.isEmpty) return;
    final out = <int, StoreSettings>{};
    for (final g in groups) {
      if (_vendorSettings.containsKey(g.tenantId)) { out[g.tenantId] = _vendorSettings[g.tenantId]!; continue; }
      final res = await ApiService.get('settings/store.php', queryParams: {'store': g.slug});
      if (!mounted) return;
      out[g.tenantId] = res['success'] == true && res['data'] is Map ? StoreSettings.fromJson(res['data'] as Map<String, dynamic>) : StoreSettings();
    }
    if (mounted) setState(() => _vendorSettings.addAll(out));
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
      _loadSettings();
      _loadVendorSettings();
      final loc = context.read<LocationProvider>();
      if (loc.hasLocation) {
        _addressController.text = loc.address;
        _address = loc.address;
      } else {
        final auth = context.read<AuthProvider>();
        if (auth.customer?.address != null && auth.customer!.address.isNotEmpty) {
          _addressController.text = auth.customer!.address;
          _address = auth.customer!.address;
        }
      }
      _refreshQuote();
    });
  }

  /// Fetch the server-computed per-km delivery quote for the current location.
  /// Sets _quotedFee/_quotedKm only when the store charges per km; the
  /// server recomputes the same formula at order time, so display == charge.
  Future<void> _refreshQuote() async {
    try {
      final loc = context.read<LocationProvider>();
      final lat = loc.lat;
      final lng = loc.lng;
      if (lat == null || lng == null) return;
      final uri = Uri.parse('https://otamzo.com/api/check-zone.php?lat=$lat&lng=$lng&store=anterkart');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || !mounted) return;
      final j = jsonDecode(res.body);
      if (j['fee_basis'] == 'per_km' && j['per_km_fee'] != null) {
        setState(() {
          _quotedFee = double.tryParse('${j['per_km_fee']}');
          _quotedKm = double.tryParse('${j['distance_km']}');
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final res = await ApiService.get('settings/store.php');
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      setState(() {
        _settings = StoreSettings.fromJson(res['data'] as Map<String, dynamic>);
        _settingsLoaded = true;
        final ok = _paymentMethod == 'COD' ? _settings.codEnabled : _settings.razorpayEnabled;
        if (!ok) {
          if (_settings.codEnabled) {
            _paymentMethod = 'COD';
          } else if (_settings.razorpayEnabled) {
            _paymentMethod = 'Razorpay';
          }
        }
      });
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse r) async {
    final loc = context.read<LocationProvider>();
    final result = await context.read<OrderProvider>().createOrder(
      address: _address,
      paymentMethod: 'Razorpay',
      deliveryZoneId: _deliveryZoneId,
      lat: loc.lat,
      lng: loc.lng,
      couponCode: _couponController.text.isNotEmpty ? _couponController.text : null,
      razorpayPaymentId: r.paymentId,
      razorpayOrderId: r.orderId,
      razorpaySignature: r.signature,
      perKm: _quotedFee != null,
    );
    if (!mounted) return;
    setState(() => _placing = false);
    if (result['success'] == true) {
      if (!mounted) return;
      await context.read<CartProvider>().loadCart();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderNumber: result['data']['order_number'])), (r) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Payment verified but order failed'), backgroundColor: Colors.red));
    }
  }

  void _onRazorpayError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() => _placing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: ${r.message ?? 'Unknown'}'), backgroundColor: Colors.red));
  }

  void _onRazorpayWallet(ExternalWalletResponse r) {}

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final addresses = context.watch<AddressProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (addresses.addresses.isNotEmpty)
              ...addresses.addresses.map((a) => RadioListTile<int?>(
                title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(a.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                value: a.id,
                // ignore: deprecated_member_use
                groupValue: _deliveryZoneId,
                activeColor: const Color(0xFF2563EB),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() {
                  _deliveryZoneId = v;
                  _addressController.text = a.address;
                  _address = a.address;
                }),
              )),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter delivery address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => _address = v,
            ),
            const SizedBox(height: 24),
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_settings.codEnabled)
              RadioListTile<String>(
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Pay when you receive'),
                value: 'COD',
                // ignore: deprecated_member_use
                groupValue: _paymentMethod,
                activeColor: const Color(0xFF2563EB),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
            if (_settings.razorpayEnabled)
              RadioListTile<String>(
                title: const Text('Razorpay'),
                subtitle: const Text('Pay online'),
                value: 'Razorpay',
                // ignore: deprecated_member_use
                groupValue: _paymentMethod,
                activeColor: const Color(0xFF2563EB),
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
            if (_settingsLoaded && !_settings.codEnabled && !_settings.razorpayEnabled)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No payment methods enabled for this store', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _couponController,
              decoration: InputDecoration(
                hintText: 'Coupon code (optional)',
                prefixIcon: const Icon(Icons.local_offer_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: TextButton(onPressed: () {}, child: const Text('Apply')),
              ),
            ),
            const SizedBox(height: 24),
            Builder(builder: (context) {
              final cart = context.watch<CartProvider>();
              final groups = _vendorGroups(cart.items);
              double subTotal = 0, feeTotal = 0, taxTotal = 0, grandTotal = 0;
              double minDeficit = 0;
              for (final g in groups) {
                final vs = _vendorSettings[g.tenantId] ?? _settings;
                final fee = _quotedFee ?? vs.deliveryFee;
                final tax = g.subtotal * 0.05;
                subTotal += g.subtotal; feeTotal += fee; taxTotal += tax;
                grandTotal += g.subtotal + tax + fee;
                if (g.subtotal < vs.minOrder) minDeficit = math.max(minDeficit, vs.minOrder - g.subtotal);
              }
              final currency = _settings.currency;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    for (final g in groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                          Text('${currency}${g.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ]),
                      ),
                    ],
                    _priceRow('Subtotal', '$currency${subTotal.toStringAsFixed(2)}'),
                    _priceRow('Tax (GST)', '$currency${taxTotal.toStringAsFixed(2)}'),
                    _priceRow(_quotedKm != null ? 'Delivery Fee (${_quotedKm!.toStringAsFixed(1)} km)' : 'Delivery Fee', feeTotal == 0 ? 'FREE' : '$currency${feeTotal.toStringAsFixed(2)}'),
                    const Divider(),
                    _priceRow('Total', '$currency${grandTotal.toStringAsFixed(2)}', bold: true),
                    if (groups.length > 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Your cart spans multiple stores and will be delivered in separate orders.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                  ],
                ),
              );
            }),
            if (cart.subtotal > 0 && cart.subtotal < _settings.minOrder)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Builder(builder: (context) {
                  final cart = context.watch<CartProvider>();
                  final groups = _vendorGroups(cart.items);
                  double minDeficit = 0;
                  for (final g in groups) {
                    final vs = _vendorSettings[g.tenantId] ?? _settings;
                    minDeficit = math.max(minDeficit, vs.minOrder - g.subtotal);
                  }
                  return Text('Minimum order is ${_settings.currency}${minDeficit.toStringAsFixed(0)} more', style: const TextStyle(color: Colors.red));
                }),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Builder(builder: (context) {
                final cart = context.watch<CartProvider>();
                final groups = _vendorGroups(cart.items);
                double minDeficit = 0;
                for (final g in groups) {
                  final vs = _vendorSettings[g.tenantId] ?? _settings;
                  if (g.subtotal < vs.minOrder) minDeficit = math.max(minDeficit, vs.minOrder - g.subtotal);
                }
                final blocked = _placing || _address.isEmpty || minDeficit > 0 || (!_settings.codEnabled && !_settings.razorpayEnabled);
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: blocked ? null : _placeOrder,
                  child: _placing ? const CircularProgressIndicator(color: Colors.white) : const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: bold ? Colors.black : Colors.grey, fontSize: bold ? 18 : 14)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 18 : 14, color: bold ? const Color(0xFF2563EB) : Colors.black)),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final loc = context.read<LocationProvider>();
    if (_address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter delivery address'), backgroundColor: Colors.red));
      return;
    }
    if (_paymentMethod == 'Razorpay' && !_settings.razorpayEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Online payment is not available for this store'), backgroundColor: Colors.red));
      return;
    }
    if (_paymentMethod == 'COD' && !_settings.codEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash on Delivery is not available for this store'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _placing = true);
    if (_paymentMethod == 'Razorpay') {
      final cart = context.read<CartProvider>();
      final groups = _vendorGroups(cart.items);
      var grandTotal = 0.0;
      for (final g in groups) {
        final vs = _vendorSettings[g.tenantId] ?? _settings;
        grandTotal += g.subtotal + g.subtotal * 0.05 + (_quotedFee ?? vs.deliveryFee);
      }
      final total = grandTotal;
      final rzpRes = await context.read<OrderProvider>().createRazorpayOrder(total);
      if (!mounted) return;
      if (rzpRes['success'] != true) {
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rzpRes['message'] ?? 'Failed to init Razorpay'), backgroundColor: Colors.red));
        return;
      }
      if (rzpRes['data']['mock'] == true) {
        if (!mounted) { setState(() => _placing = false); return; }
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Razorpay (Test Mode)'),
            content: Text('Razorpay keys are not configured (dummy). Simulate payment of ₹${total.toStringAsFixed(0)}?'),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pay (Simulate)'))],
          ),
        );
        if (confirm != true) { if (mounted) setState(() => _placing = false); return; }
        final mockId = rzpRes['data']['razorpay_order_id'];
        final loc2 = context.read<LocationProvider>();
        final result2 = await context.read<OrderProvider>().createOrder(
          address: _address, paymentMethod: 'Razorpay', deliveryZoneId: _deliveryZoneId, lat: loc2.lat, lng: loc2.lng,
          couponCode: _couponController.text.isNotEmpty ? _couponController.text : null,
          razorpayPaymentId: 'pay_mock_${DateTime.now().millisecondsSinceEpoch}', razorpayOrderId: mockId, razorpaySignature: 'mock_sig',
          perKm: _quotedFee != null,
        );
        if (!mounted) return;
        setState(() => _placing = false);
        if (result2['success'] == true) {
          if (!mounted) return;
          await context.read<CartProvider>().loadCart();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderNumber: result2['data']['order_number'])), (r) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result2['message'] ?? 'Failed'), backgroundColor: Colors.red));
        }
        return;
      }
      final auth = context.read<AuthProvider>();
      _razorpay!.open({
        'key': rzpRes['data']['razorpay_key'],
        'amount': (total * 100).toInt(),
        'name': 'Otamzo',
        'description': 'Order payment',
        'order_id': rzpRes['data']['razorpay_order_id'],
        'prefill': {'contact': auth.customer?.phone ?? '', 'email': auth.customer?.email ?? ''},
        'theme': {'color': '#2563EB'}
      });
      return;
    }
    final result = await context.read<OrderProvider>().createOrder(
      address: _address,
      paymentMethod: _paymentMethod,
      deliveryZoneId: _deliveryZoneId,
      lat: loc.lat,
      lng: loc.lng,
      couponCode: _couponController.text.isNotEmpty ? _couponController.text : null,
      perKm: _quotedFee != null,
    );
    if (!mounted) return;
    setState(() => _placing = false);
    if (result['success'] == true) {
      if (!mounted) return;
      await context.read<CartProvider>().loadCart();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderNumber: result['data']['order_number'])), (r) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }
}
