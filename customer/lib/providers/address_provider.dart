import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/api_service.dart';

class AddressProvider extends ChangeNotifier {
  List<AddressModel> _addresses = [];
  bool _isLoading = false;

  List<AddressModel> get addresses => _addresses;
  bool get isLoading => _isLoading;
  AddressModel? get defaultAddress => _addresses.isNotEmpty ? _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first) : null;

  Future<void> loadAddresses() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('addresses/list.php', auth: true);
    if (res['success'] == true) {
      _addresses = (res['data']['addresses'] as List? ?? []).map((j) => AddressModel.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addAddress({required String label, required String address, double lat = 0, double lng = 0, bool isDefault = false}) async {
    final res = await ApiService.post('addresses/add.php', body: {'label': label, 'address': address, 'lat': lat, 'lng': lng, 'is_default': isDefault ? 1 : 0}, auth: true);
    if (res['success'] == true) {
      await loadAddresses();
      return true;
    }
    return false;
  }

  Future<bool> deleteAddress(int id) async {
    final res = await ApiService.post('addresses/delete.php', body: {'id': id}, auth: true);
    if (res['success'] == true) {
      await loadAddresses();
      return true;
    }
    return false;
  }
}
