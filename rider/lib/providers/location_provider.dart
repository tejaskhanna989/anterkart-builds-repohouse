import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class LocationProvider extends ChangeNotifier {
  Timer? _timer;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  bool get isTracking => _isTracking;

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();

    // Request foreground location updates with high accuracy
    await _requestPermissions();
    
    // Start foreground location stream for live GPS
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }
    if (permission == LocationPermission.deniedForever) return;
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await ApiService.post('rider/location/update.php', body: {'lat': position.latitude, 'lng': position.longitude}, auth: true);
    } catch (_) {}
  }
}