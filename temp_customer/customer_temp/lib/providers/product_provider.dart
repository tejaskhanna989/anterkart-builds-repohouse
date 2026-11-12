import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/review.dart';
import '../models/review_deletion.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _bestsellers = [];
  List<Product> _newArrivals = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';
  int? _selectedCategoryId;

  List<Product> get products => _products;
  List<Product> get bestsellers => _bestsellers;
  List<Product> get newArrivals => _newArrivals;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;

  Future<void> loadProducts({int page = 1, int? categoryId, String? search, String sort = 'default'}) async {
    if (page == 1) _isLoading = true;
    _currentPage = page;
    _selectedCategoryId = categoryId;
    _searchQuery = search ?? '';
    notifyListeners();

    final params = <String, String>{
      'page': page.toString(),
      'limit': '20',
      'sort': sort,
    };
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await ApiService.get('products/list.php', queryParams: params);
    if (res['success'] == true) {
      final items = (res['data']['products'] as List? ?? []).map((j) => Product.fromJson(j)).toList();
      if (page == 1) {
        _products = items;
      } else {
        _products = [..._products, ...items];
      }
      _totalPages = res['data']['pages'] ?? 1;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBestsellers({int limit = 10}) async {
    final res = await ApiService.get('products/bestsellers.php', queryParams: {'limit': limit.toString()});
    if (res['success'] == true) {
      _bestsellers = (res['data']['products'] as List? ?? []).map((j) => Product.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<void> loadNewArrivals({int limit = 10}) async {
    final res = await ApiService.get('products/newarrivals.php', queryParams: {'limit': limit.toString()});
    if (res['success'] == true) {
      _newArrivals = (res['data']['products'] as List? ?? []).map((j) => Product.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    final res = await ApiService.get('categories/list.php');
    if (res['success'] == true) {
      _categories = (res['data']['categories'] as List? ?? []).map((j) => Category.fromJson(j)).toList();
      notifyListeners();
    }
  }

  Future<List<Product>> search(String query) async {
    if (query.isEmpty) return [];
    final res = await ApiService.get('products/search.php', queryParams: {'q': query});
    if (res['success'] == true) {
      return (res['data']['products'] as List? ?? []).map((j) => Product.fromJson(j)).toList();
    }
    return [];
  }

  Future<Product?> getProductDetail(int id) async {
    final res = await ApiService.get('products/detail.php', queryParams: {'id': id.toString()});
    if (res['success'] == true) {
      return Product.fromJson(res['data']['product']);
    }
    return null;
  }

  Future<List<Review>> fetchReviews(int productId) async {
    final res = await ApiService.get('products/reviews.php', queryParams: {'product_id': productId.toString()});
    if (res['success'] == true) {
      return (res['data']['reviews'] as List? ?? []).map((j) => Review.fromJson(j)).toList();
    }
    return [];
  }

  Future<String?> submitReview(int productId, int rating, String comment) async {
    final res = await ApiService.post(
      'reviews/add.php',
      body: {'product_id': productId, 'rating': rating, 'comment': comment},
      auth: true,
    );
    if (res['success'] == true) return null;
    return res['message'] ?? 'Could not submit review';
  }

  Future<List<ReviewDeletion>> fetchReviewDeletions() async {
    final res = await ApiService.get('reviews/deletions.php', auth: true);
    if (res['success'] == true) {
      return (res['data']['reviews'] as List? ?? []).map((j) => ReviewDeletion.fromJson(j)).toList();
    }
    return [];
  }

  Future<String?> respondReviewDeletion(int reviewId, {required bool confirm}) async {
    final res = await ApiService.post(
      'reviews/respond.php',
      body: {'review_id': reviewId, 'action': confirm ? 'confirm' : 'keep'},
      auth: true,
    );
    if (res['success'] == true) return null;
    return res['message'] ?? 'Something went wrong';
  }
}
