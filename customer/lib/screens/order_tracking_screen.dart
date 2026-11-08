import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/order_provider.dart';
import 'chat_screen.dart';

/// Live order tracking: polls track.php every 15s, shows stage banner,
/// timeline, ETA breakdown, rider marker + home marker, rider call button.
class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic> _data = {};
  Timer? _pollTimer;
  final MapController _mapController = MapController();
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _track();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _track();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _track() async {
    final data = await context.read<OrderProvider>().trackOrder(widget.orderId);
    if (data.isNotEmpty && mounted) {
      setState(() => _data = data);
      final rider = _riderLatLng();
      if (rider != null && !_centered) {
        _centered = true;
        try {
          _mapController.move(rider, 15);
        } catch (_) {}
      }
    }
  }

  Future<void> _callRider() async {
    final res = await context.read<OrderProvider>().callRider(widget.orderId);
    if (!mounted) return;
    if (res['masked'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['message'] ?? 'Connecting your call…'}'), backgroundColor: Colors.green));
    } else if ('${res['number'] ?? ''}'.isNotEmpty) {
      launchUrl(Uri.parse('tel:${res['number']}'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['message'] ?? 'Call failed'}'), backgroundColor: Colors.red));
    }
  }

  LatLng? _riderLatLng() {
    final r = _data['rider'];
    if (r == null) return null;
    final lat = double.tryParse('${r['lat']}') ?? 0;
    final lng = double.tryParse('${r['lng']}') ?? 0;
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  LatLng? _destLatLng() {
    final d = _data['destination'];
    if (d == null) return null;
    final lat = double.tryParse('${d['lat']}') ?? 0;
    final lng = double.tryParse('${d['lng']}') ?? 0;
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_data['status'] ?? ''}';
    final eta = _data['eta'] as Map? ?? {};
    final rider = _data['rider'] as Map?;
    final timeline = (_data['timeline'] as List?) ?? [];
    final riderPos = _riderLatLng();
    final destPos = _destLatLng();
    final center = riderPos ?? destPos ?? LatLng(26.85, 80.95);
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order'), actions: [
        IconButton(
          icon: const Icon(Icons.chat_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: widget.orderId, title: 'Rider Chat', myRole: 'customer'))),
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _track),
      ]),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2563EB),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_data['stage_label'] ?? _statusText(status)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (eta.isNotEmpty)
                  Text('Arriving in ~${eta['eta_mins']} min • by ${eta['eta_at']} (prep ${eta['prep_min']}–${eta['prep_max']} min + travel)',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (rider != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.delivery_dining, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${rider['name'] ?? 'Rider'}${rider['stale'] == true ? ' • updating location…' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      if ('${rider['phone'] ?? ''}'.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          onPressed: _callRider,
                        ),
                    ]),
                  ),
                if ('${_data['delivery_otp'] ?? ''}'.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity( 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.key, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Share this code with your rider: ${_data['delivery_otp']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                    ]),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 14),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.otamzo.store'),
                MarkerLayer(markers: [
                  if (riderPos != null)
                    Marker(point: riderPos, width: 44, height: 44, child: const Icon(Icons.delivery_dining, color: Color(0xFF2563EB), size: 44)),
                  if (destPos != null)
                    Marker(point: destPos, width: 40, height: 40, child: const Icon(Icons.home, color: Colors.green, size: 40)),
                ]),
              ],
            ),
          ),
          if (timeline.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: timeline.length,
                itemBuilder: (_, i) {
                  final t = timeline[i] as Map;
                  final last = i == timeline.length - 1;
                  return Row(children: [
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, color: last ? const Color(0xFF10B981) : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(_statusText('${t['status']}'), style: TextStyle(fontSize: 11, fontWeight: last ? FontWeight.bold : FontWeight.normal)),
                      Text('${t['at'] ?? ''}'.length >= 16 ? '${t['at']}'.substring(11, 16) : '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                    if (!last) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 16, color: Colors.grey)),
                  ]);
                },
              ),
            ),
        ],
      ),
    );
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'Order Placed';
      case 'confirmed': return 'Order Confirmed';
      case 'preparing': return 'Being Prepared';
      case 'ready': return 'Ready for Pickup';
      case 'out_for_delivery': return 'On the Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return s;
    }
  }
}
