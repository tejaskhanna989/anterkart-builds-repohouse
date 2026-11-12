import 'package:flutter/material.dart';
import '../models/banner_model.dart';
import '../services/api_service.dart';

class BannerProvider extends ChangeNotifier {
  List<BannerModel> _banners = [];
  bool _isLoading = false;

  List<BannerModel> get banners => _banners;
  bool get isLoading => _isLoading;

  Future<void> loadBanners() async {
    _isLoading = true;
    notifyListeners();
    final res = await ApiService.get('banners/list.php');
    if (res['success'] == true) {
      _banners = (res['data']['banners'] as List? ?? []).map((j) => BannerModel.fromJson(j)).toList();
    }
    _isLoading = false;
    notifyListeners();
  }
}
