import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../home/repositories/products_repository.dart';

class SearchProvider extends ChangeNotifier {
  final ProductsRepository repository;

  static const String _recentSearchesKey = 'recent_searches';

  SearchProvider({required this.repository}) {
    _loadRecentSearches();
  }

  List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => List.unmodifiable(_categories);

  List<ProductModel> _searchResults = [];
  List<ProductModel> get searchResults => List.unmodifiable(_searchResults);

  bool _isLoadingCategories = false;
  bool get isLoadingCategories => _isLoadingCategories;

  bool _isLoadingSearch = false;
  bool get isLoadingSearch => _isLoadingSearch;

  String? _error;
  String? get error => _error;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Timer? _debounce;
  int _searchGeneration = 0;
  bool _disposed = false;

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _addSearchToHistory(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // Remove if exists to bring it to the top
    _recentSearches.remove(cleanQuery);
    _recentSearches.insert(0, cleanQuery);

    // Keep only top 10 recent searches
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return; // Prevent refetching unnecessarily

    _isLoadingCategories = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await repository.fetchCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    final generation = ++_searchGeneration;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      _searchResults.clear();
      _isLoadingSearch = false;
      notifyListeners();
      return;
    }

    // أظهر حالة التحميل فوراً حتى لا تومض رسالة "لا توجد نتائج"
    // أثناء فترة الانتظار (debounce) قبل تنفيذ البحث الفعلي.
    _isLoadingSearch = true;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query, generation);
    });
  }

  Future<void> _performSearch(String query, int generation) async {
    _isLoadingSearch = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.fetchProducts(query: query);
      if (generation != _searchGeneration) return;
      _searchResults = result['products'] as List<ProductModel>;

      // Save query only if we didn't crash and actually performed a search
      if (query.trim().isNotEmpty) {
        _addSearchToHistory(query.trim());
      }
    } catch (e) {
      if (generation != _searchGeneration) return;
      _error = e.toString();
      _searchResults = [];
    } finally {
      if (generation == _searchGeneration) {
        _isLoadingSearch = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _searchGeneration++;
    _searchQuery = '';
    _searchResults.clear();
    _isLoadingSearch = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _searchGeneration++;
    super.dispose();
  }
}
