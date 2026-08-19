import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../../core/models/app_banner_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../repositories/app_banners_repository.dart';
import '../repositories/products_repository.dart';

class HomeProvider extends ChangeNotifier {
  final ProductsRepository repository;
  final AppBannersRepository appBannersRepository;
  bool _suspendNotifications = false;
  bool _pendingNotification = false;
  bool _hasCompletedInitialLoad = false;
  Future<void>? _initialLoadFuture;

  HomeProvider({required this.repository, required this.appBannersRepository});

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  List<ProductModel> _ourProducts = [];
  List<ProductModel> _saleProducts = []; // منتجات العروض
  List<AppBannerItem> _appBanners = [];

  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;
  bool _isLoadingOurProducts = false;
  bool _isLoadingSaleProducts = false; // حالة تحميل العروض
  bool _isLoadingAppBanners = false;

  String? _categoriesError;
  String? _productsError;
  String? _ourProductsError;
  String? _saleProductsError; // خطأ جلب العروض
  String? _appBannersError;

  // الملحقات
  CategoryModel? _selectedCategory; // الفئة المختارة للفلترة

  // Getters
  List<CategoryModel> get categories => _categories;
  List<ProductModel> get products => _products;
  List<ProductModel> get ourProducts => _ourProducts;
  List<ProductModel> get saleProducts => _saleProducts;
  List<AppBannerItem> get appBanners => _appBanners;
  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingOurProducts => _isLoadingOurProducts;
  bool get isLoadingSaleProducts => _isLoadingSaleProducts;
  bool get isLoadingAppBanners => _isLoadingAppBanners;
  String? get categoriesError => _categoriesError;
  String? get productsError => _productsError;
  String? get ourProductsError => _ourProductsError;
  String? get saleProductsError => _saleProductsError;
  String? get appBannersError => _appBannersError;
  CategoryModel? get selectedCategory => _selectedCategory;
  bool get hasCompletedInitialLoad => _hasCompletedInitialLoad;
  bool get isInitialLoadInProgress => _initialLoadFuture != null;

  void _notifyChanged() {
    if (_suspendNotifications) {
      _pendingNotification = true;
      return;
    }

    notifyListeners();
  }

  Future<void> _runBatched(Future<void> Function() action) async {
    final wasSuspended = _suspendNotifications;
    _suspendNotifications = true;

    try {
      await action();
    } finally {
      _suspendNotifications = wasSuspended;

      if (!wasSuspended && _pendingNotification) {
        _pendingNotification = false;
        notifyListeners();
      }
    }
  }

  /// جلب الفئات من الـ API
  Future<void> fetchCategories() async {
    _isLoadingCategories = true;
    _categoriesError = null;
    _notifyChanged();

    try {
      _categories = await repository.fetchCategories();
    } catch (e) {
      _categoriesError = e.toString();
    } finally {
      _isLoadingCategories = false;
      _notifyChanged();
    }
  }

  /// جلب المنتجات (تلقائياً تعتمد على _selectedCategory)
  Future<void> fetchProducts({bool refresh = false}) async {
    if (_isLoadingProducts && !refresh) return;

    _isLoadingProducts = true;
    _productsError = null;
    if (refresh) _products.clear();
    _notifyChanged();

    try {
      final response = await repository.fetchProducts(
        categorySlug: _selectedCategory?.slug,
        availability: 'featured',
        sort: 'recommended',
      );
      _products = response['products'] as List<ProductModel>;
    } catch (e) {
      _productsError = e.toString();
    } finally {
      _isLoadingProducts = false;
      _notifyChanged();
    }
  }

  /// جلب منتجات العروض (availability=on_sale) مع تحديد أقصى عدد للعرض
  Future<void> fetchOurProducts() async {
    _isLoadingOurProducts = true;
    _ourProductsError = null;
    _notifyChanged();

    try {
      final response = await repository.fetchProducts(
        availability: 'all',
        sort: 'recommended',
        perPage: 60,
      );
      final products = List<ProductModel>.from(
        response['products'] as List<ProductModel>,
      ).where((product) => !product.isFeatured).toList();

      products.shuffle(Random());
      _ourProducts = List<ProductModel>.unmodifiable(products.take(6));
    } catch (e) {
      _ourProductsError = e.toString();
    } finally {
      _isLoadingOurProducts = false;
      _notifyChanged();
    }
  }

  Future<void> fetchSaleProducts() async {
    _isLoadingSaleProducts = true;
    _saleProductsError = null;
    _notifyChanged();

    try {
      final response = await repository.fetchProducts(
        availability: 'on_sale',
        sort: 'recommended',
        perPage: 10,
      );
      _saleProducts = response['products'] as List<ProductModel>;
    } catch (e) {
      _saleProductsError = e.toString();
    } finally {
      _isLoadingSaleProducts = false;
      _notifyChanged();
    }
  }

  /// جلب العروض من الـ API
  Future<void> fetchAppBanners() async {
    _isLoadingAppBanners = true;
    _appBannersError = null;
    _notifyChanged();

    try {
      _appBanners = await appBannersRepository.fetchBanners();
    } catch (e) {
      _appBannersError = e.toString();
    } finally {
      _isLoadingAppBanners = false;
      _notifyChanged();
    }
  }

  /// تغيير الفئة المحددة وتحديث المنتجات
  void selectCategory(CategoryModel? category) {
    _selectedCategory = category;
    _notifyChanged();
    fetchProducts(refresh: true);
  }

  /// تهيئة الشاشة الرئيسية (جلب الفئات والمنتجات والعروض بالتوازي)
  Future<void> initHomeData() async {
    _isLoadingCategories = true;
    _isLoadingProducts = true;
    _isLoadingOurProducts = true;
    _isLoadingSaleProducts = true;
    _isLoadingAppBanners = true;
    _categoriesError = null;
    _productsError = null;
    _ourProductsError = null;
    _saleProductsError = null;
    _appBannersError = null;
    _products.clear();
    _ourProducts.clear();
    _notifyChanged();

    await _runBatched(() async {
      await Future.wait([
        fetchCategories(),
        fetchProducts(refresh: true),
        fetchOurProducts(),
        fetchSaleProducts(),
        fetchAppBanners(),
      ]);
    });
  }

  Future<void> ensureInitialDataLoaded({bool forceRefresh = false}) {
    if (!forceRefresh) {
      if (_hasCompletedInitialLoad) {
        return SynchronousFuture<void>(null);
      }

      final existingFuture = _initialLoadFuture;
      if (existingFuture != null) {
        return existingFuture;
      }
    }

    final future = _performInitialLoad();
    _initialLoadFuture = future;
    return future;
  }

  Future<void> _performInitialLoad() async {
    try {
      await initHomeData();
    } finally {
      _hasCompletedInitialLoad = true;
      _initialLoadFuture = null;
    }
  }
}
