import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../providers/location_provider.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _picked;
  String _addr = '';
  bool _loading = false;
  bool _checkingZone = false;
  bool _inZone = true;
  String _zoneName = '';
  final _mapController = MapController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = context.read<LocationProvider>();
      if (loc.hasLocation) {
        final existing = LatLng(loc.lat!, loc.lng!);
        setState(() {
          _picked = existing;
          _addr = loc.address;
        });
        _checkZone(existing);
      }
      loc.loadZones();
      if (!loc.hasLocation) _goToCurrent();
    });
  }

  Future<void> _goToCurrent() async {
    try {
      bool en = await Geolocator.isLocationServiceEnabled();
      if (!en) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: const Duration(seconds: 12));
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = latLng);
      _mapController.move(latLng, 16);
      _reverse(latLng);
    } catch (_) {}
  }

  Future<void> _reverse(LatLng p) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&accept-language=en&addressdetails=1');
      final res = await http.get(uri, headers: {'User-Agent': 'Otamzo/1.0'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final a = j['display_name'] ?? '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
        setState(() => _addr = a);
      } else {
        setState(() => _addr = '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
      }
    } catch (_) {
      setState(() => _addr = '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
    }
    setState(() => _loading = false);
    _checkZone(p);
  }

  Future<void> _checkZone(LatLng p) async {    setState(() => _checkingZone = true);
    try {
      final uri = Uri.parse('https://otamzo.com/api/check-zone.php?lat=${p.latitude}&lng=${p.longitude}&store=anterkart');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['zone_id'] != null) {
          setState(() { _inZone = true; _zoneName = j['name'] ?? ''; });
        } else {
          setState(() { _inZone = false; _zoneName = ''; });
        }
      } else {
        setState(() => _inZone = true);
      }
    } catch (_) {
      setState(() => _inZone = true);
    }
    setState(() => _checkingZone = false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 600), () => _runSearch(q.trim()));
  }

  /// City / place search via Nominatim forward geocoding.
  Future<void> _runSearch(String q) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(q)}&countrycodes=in&limit=5&addressdetails=1&accept-language=en');
      final res = await http.get(uri, headers: {'User-Agent': 'Otamzo/1.0'}).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).whereType<Map<String, dynamic>>().toList();
        setState(() { _searchResults = list; _searching = false; });
      } else {
        setState(() { _searchResults = []; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _searchResults = []; _searching = false; });
    }
  }

  void _pickSearchResult(Map<String, dynamic> r) {
    final lat = double.tryParse('${r['lat']}');
    final lng = double.tryParse('${r['lon']}');
    if (lat == null || lng == null) return;
    final p = LatLng(lat, lng);
    setState(() {
      _picked = p;
      _addr = '${r['display_name'] ?? ''}';
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(p, 15);
    _reverse(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _picked ?? LatLng(26.8467, 80.9462), initialZoom: _picked != null ? 15 : 5, onTap: (_, p) { setState(() => _picked = p); _reverse(p); }),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.otamzo.store'),
              if (_picked != null) MarkerLayer(markers: [Marker(point: _picked!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 40))]),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search city or place…',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                      suffixIcon: _searching
                          ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                          : (_searchController.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); setState(() { _searchResults = []; }); })
                              : null),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        final a = r['address'] as Map<String, dynamic>?;
                        final sub = a?['city'] ?? a?['town'] ?? a?['village'] ?? a?['state'] ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, color: Color(0xFF2563EB)),
                          title: Text('${r['display_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          subtitle: sub.toString().isNotEmpty ? Text(sub.toString(), style: const TextStyle(fontSize: 11)) : null,
                          onTap: () => _pickSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(right: 12, bottom: 140, child: FloatingActionButton.small(backgroundColor: Colors.white, onPressed: _goToCurrent, child: const Icon(Icons.my_location, color: Color(0xFF2563EB)))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 20), const SizedBox(width: 6), const Text('Delivery Location', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), if (_loading || _checkingZone) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))]),
                  const SizedBox(height: 8),
                  Text(_addr.isEmpty ? 'Tap on map to select location' : _addr, style: TextStyle(color: Colors.grey[700])),
                  if (_picked != null && !_inZone) ...[
                    const SizedBox(height: 8),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity( 0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: const [Icon(Icons.block, color: Colors.red, size: 16), SizedBox(width: 6), Expanded(child: Text("Sorry, we don't deliver here yet.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)))])),
                  ] else if (_picked != null && _inZone && _zoneName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Delivering to $_zoneName', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _inZone ? const Color(0xFF2563EB) : Colors.grey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _picked == null || _addr.isEmpty || !_inZone || _checkingZone
                          ? null
                          : () async {
                              await context.read<LocationProvider>().setCoordinates(_picked!.latitude, _picked!.longitude, _addr);
                              if (mounted) Navigator.pop(context);
                            },
                      child: Text(_inZone ? 'Confirm Location' : "Can't deliver here", style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
