import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/order_provider.dart';

/// Live navigation map for the rider.
///
/// Shows the rider's own GPS position, the store (pickup point) and the
/// customer drop-off point, with a route line between them. The drop-off
/// point is taken from the API when available and otherwise geocoded from
/// the delivery address, so the rider always sees where to go.
class DeliveryMapScreen extends StatefulWidget {
  final int orderId;
  final Order? order;

  const DeliveryMapScreen({super.key, required this.orderId, this.order});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final MapController _mapController = MapController();
  final loc.Location _location = loc.Location();

  Order? _order;
  LatLng? _rider;
  LatLng? _destination;
  LatLng? _store;
  bool _loading = true;
  bool _geocoding = false;
  String? _error;
  Timer? _pollTimer;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final fresh = await context.read<OrderProvider>().loadDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _loading = false;
    });
    await _resolvePoints();
    await _refreshRiderPosition();
  }

  /// Work out the store / drop-off markers from the API payload.
  Future<void> _resolvePoints() async {
    final o = _order;
    if (o == null) return;

    final dest = (o.deliveryLat != null && o.deliveryLng != null)
        ? LatLng(o.deliveryLat!, o.deliveryLng!)
        : null;
    final store = (o.storeLat != null && o.storeLng != null) ? LatLng(o.storeLat!, o.storeLng!) : null;

    if (dest != null) {
      if (mounted) setState(() => _destination = dest);
      return;
    }

    // No coordinates from the API — geocode the delivery address once.
    final address = (o.address ?? '').trim();
    if (address.isEmpty || _geocoding) return;
    _geocoding = true;
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search'
          '?format=json&q=${Uri.encodeComponent(address)}&countrycodes=in&limit=1&accept-language=en');
      final res = await http.get(uri, headers: {'User-Agent': 'OtamzoRider/1.0'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          final first = Map<String, dynamic>.from(list.first as Map);
          final lat = double.tryParse('${first['lat']}');
          final lon = double.tryParse('${first['lon']}');
          if (lat != null && lon != null) {
            setState(() => _destination = LatLng(lat, lon));
          }
        }
      }
    } catch (_) {
      // Geocoding is best-effort only.
    } finally {
      _geocoding = false;
    }
    if (store != null && mounted) setState(() => _store = store);
  }

  Future<void> _refreshRiderPosition() async {
    try {
      final enabled = await _location.serviceEnabled();
      if (!enabled) return;
      var permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission == loc.PermissionStatus.denied || permission == loc.PermissionStatus.deniedForever) return;
      final pos = await _location.getLocation();
      if (!mounted) return;
      final lat = pos.latitude;
      final lng = pos.longitude;
      if (lat == null || lng == null) return;
      setState(() => _rider = LatLng(lat, lng));
      _centerIfNeeded();
    } catch (_) {}
  }

  void _centerIfNeeded() {
    final rider = _rider;
    if (rider == null || _centered) return;
    _centered = true;
    try {
      _mapController.move(rider, 15);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final center = _rider ?? _destination ?? const LatLng(24.853545, 74.620191);
    return Scaffold(
      appBar: AppBar(
        title: Text(_order != null ? 'Navigate · #${_order!.orderNumber}' : 'Navigate'),
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: () async {
            _centered = false;
            await _refreshRiderPosition();
          }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
      ),
      body: _loading && _order == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.otamzo.rider',
                          ),
                          if (_rider != null && _destination != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [_rider!, _destination!],
                                  color: const Color(0xFF2563EB),
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_rider != null)
                                Marker(
                                  point: _rider!,
                                  width: 46,
                                  height: 46,
                                  child: _pin(const Color(0xFF2563EB), Icons.delivery_dining),
                                ),
                              if (_store != null)
                                Marker(
                                  point: _store!,
                                  width: 46,
                                  height: 46,
                                  child: _pin(const Color(0xFF10B981), Icons.store),
                                ),
                              if (_destination != null)
                                Marker(
                                  point: _destination!,
                                  width: 46,
                                  height: 46,
                                  child: _pin(const Color(0xFFEF4444), Icons.home),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_destination == null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _order?.address ?? 'No delivery address',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _order != null ? 'Order #${_order!.orderNumber}' : 'Order',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _row(Icons.person, 'Customer', _order?.customerName ?? '-'),
                        _row(Icons.location_on, 'Drop-off', _order?.address ?? '-'),
                        _row(Icons.my_location, 'Your GPS',
                            _rider == null ? 'waiting…' : '${_rider!.latitude.toStringAsFixed(5)}, ${_rider!.longitude.toStringAsFixed(5)}'),
                        if (_destination != null)
                          _row(Icons.flag, 'Drop-off pin',
                              '${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}'),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _destination == null
                                  ? null
                                  : () => _openDirections(_destination!),
                              icon: const Icon(Icons.directions),
                              label: const Text('Directions'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                await _refreshRiderPosition();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Location shared with the server')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.upload),
                              label: const Text('Share GPS'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pin(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  void _openDirections(LatLng target) {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}');
    // Ignore failures — the app already shows the pin on the map.
    // ignore: invalid_use_of_visible_for_testing_member
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Destination'),
        content: Text('${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}\n\n$url'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
