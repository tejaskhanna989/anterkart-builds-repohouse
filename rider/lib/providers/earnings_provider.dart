import 'package:flutter/material.dart';
import '../models/earnings.dart';
import '../services/api_service.dart';

class EarningsProvider extends ChangeNotifier {
  Earnings? _earnings;
  bool _isLoading = false;

  Earnings? get earnings => _earnings;
  bool get isLoading => _isLoading;

  Future<void> loadEarnings() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('rider/earnings.php', auth: true);
    if (res['success'] == true) {
      _earnings = Earnings.fromJson(res['data']);
    }
    _isLoading = false;
    notifyListeners();
  }
}
