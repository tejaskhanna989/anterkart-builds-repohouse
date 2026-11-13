import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import '../services/api_service.dart';

class LocationProvider extends ChangeNotifier {
  Timer? _timer;
  bool _isTracking = false;
  StreamSubscription<loc.LocationData>? _positionStream;
  final loc.Location _location = loc.Location();

  bool get isTracking => _isTracking;

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();

    // Request foreground location updates with high accuracy
    await _requestPermissions();
    
    // Start foreground location stream for live GPS
    _positionStream = _location.onLocationChanged.listen((loc.LocationData locationData) {
      _updateLocation();
    });

    // Also keep timer as fallback
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _updateLocation());
    await _updateLocation();
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permission = await _location.hasPermission();
    if (permission == loc.PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission == loc.PermissionStatus.denied || permission == loc.PermissionStatus.deniedForever) return;
    }
    if (permission == loc.PermissionStatus.deniedForever) return;
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) return;

      loc.PermissionStatus permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission == loc.PermissionStatus.denied || permission == loc.PermissionStatus.deniedForever) return;
      }
      if (permission == loc.PermissionStatus.deniedForever) return;

      loc.LocationData position = await _location.getLocation();
      await ApiService.post('rider/location/update.php', body: {'lat': position.latitude, 'lng': position.longitude}, auth: true);
    } catch (_) {}
  }
}