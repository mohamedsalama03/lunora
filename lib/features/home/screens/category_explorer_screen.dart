import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/custom_navbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/auth_required_dialog.dart';
import '../../cart/providers/cart_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/home_provider.dart';
import 'product_detail_screen.dart';

class CategoryExplorerScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryExplorerScreen({super.key, required this.category});

  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen> {
  static const int _productsPerPage = 18;

  static final Map<String, CategoryModel> _categoryNodeCache =
      <String, CategoryModel>{};
  static Future<void>? _categoryTreeWarmupFuture;

  static final Map<String, _CategoryProductsCacheEntry> _categoryProductsCache =
      <String, _CategoryProductsCacheEntry>{};
  static final Map<String, Future<_CategoryProductsPageData>>
  _categoryProductsRequestCache = <String, Future<_CategoryProductsPageData>>{};

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _subcategorySearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();

  CategoryModel? _resolvedCategory;
  bool _isPreparingCategory = false;
  String? _categoryError;
  String _subcategoryQuery = '';
  String _productQuery = '';

  bool _isLoadingProducts = false;
  bool _isLoadingMoreProducts = false;
  String? _productsError;
  List<ProductModel> _products = const <ProductModel>[];
  int _currentPage = 0;
  int _lastPage = 1;

  CategoryModel get _category => _resolvedCategory ?? widget.category;
  bool get _showsSubcategories => _category.children.isNotEmpty;
  bool get _hasMoreProducts => _currentPage < _lastPage;
  List<CategoryModel> get _filteredSubcategories {
    final query = _subcategoryQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _category.children;
    }

    return _category.children.where((category) {
      final name = category.name.toLowerCase();
      final slug = category.slug.toLowerCase();
      return name.contains(query) || slug.contains(query);
    }).toList();
  }

  List<ProductModel> get _filteredProducts {
    final query = _productQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      final name = product.name.toLowerCase();
      final slug = product.slug.toLowerCase();
      final brand = product.brand?.name.toLowerCase() ?? '';
      return name.contains(query) ||
          slug.contains(query) ||
          brand.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareScreen();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _subcategorySearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _prepareScreen({bool forceRefresh = false}) async {
    await _ensureResolvedCategory(forceRefresh: forceRefresh);
    if (!mounted || _showsSubcategories) {
      return;
    }
    await _loadInitialProducts(forceRefresh: forceRefresh);
  }

  Future<void> _ensureResolvedCategory({bool forceRefresh = false}) async {
    final needsResolution =
        widget.category.children.isEmpty && widget.category.childrenCount > 0;
    if (!needsResolution) {
      _resolvedCategory = widget.category;
      return;
    }

    final cachedCategory = !forceRefresh
        ? _categoryNodeCache[widget.category.slug]
        : null;
    if (cachedCategory != null) {
      _resolvedCategory = cachedCategory;
      return;
    }

    if (mounted) {
      setState(() {
        _isPreparingCategory = true;
        _categoryError = null;
      });
    }

    try {
      await _warmupCategoryTree(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _resolvedCategory = _categoryNodeCache[widget.category.slug];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoryError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingCategory = false;
        });
      }
    }
  }

  Future<void> _warmupCategoryTree({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _categoryTreeWarmupFuture = null;
      _categoryNodeCache.clear();
    }

    final existingFuture = _categoryTreeWarmupFuture;
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final repository = context.read<HomeProvider>().repository;
    final future = repository.fetchCategories().then((categories) {
      _cacheCategoryTree(categories);
    });

    _categoryTreeWarmupFuture = future;

    try {
      await future;
    } catch (_) {
      if (identical(_categoryTreeWarmupFuture, future)) {
        _categoryTreeWarmupFuture = null;
      }
      rethrow;
    }
  }

  void _cacheCategoryTree(List<CategoryModel> categories) {
    void walk(CategoryModel category) {
      _categoryNodeCache[category.slug] = category;
      for (final child in category.children) {
        walk(child);
      }
    }

    for (final category in categories) {
      walk(category);
    }
  }

  Future<void> _loadInitialProducts({bool forceRefresh = false}) async {
    if (_showsSubcategories) {
      return;
    }

    final slug = _category.slug;
    if (forceRefresh) {
      _categoryProductsCache.remove(slug);
    }

    final cached = _categoryProductsCache[slug];
    if (cached != null) {
      setState(() {
        _products = cached.products;
        _currentPage = cached.currentPage;
        _lastPage = cached.lastPage;
        _productsError = null;
      });
      return;
    }

    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    try {
      final pageData = await _fetchProductsPage(page: 1);
      if (!mounted) {
        return;
      }

      setState(() {
        _products = pageData.products;
        _currentPage = pageData.currentPage;
        _lastPage = pageData.lastPage;
      });
      _cacheCurrentProducts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _productsError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_showsSubcategories ||
        _isLoadingProducts ||
        _isLoadingMoreProducts ||
        !_hasMoreProducts) {
      return;
    }

    setState(() {
      _isLoadingMoreProducts = true;
    });

    try {
      final pageData = await _fetchProductsPage(page: _currentPage + 1);
      if (!mounted) {
        return;
      }

      setState(() {
        _products = List<ProductModel>.unmodifiable(<ProductModel>[
          ..._products,
          ...pageData.products,
        ]);
        _currentPage = pageData.currentPage;
        _lastPage = pageData.lastPage;
      });
      _cacheCurrentProducts();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _productsError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreProducts = false;
        });
      }
    }
  }

  Future<_CategoryProductsPageData> _fetchProductsPage({
    required int page,
  }) async {
    final requestKey = '${_category.slug}::$page';
    final cachedFuture = _categoryProductsRequestCache[requestKey];
    if (cachedFuture != null) {
      return cachedFuture;
    }

    final repository = context.read<HomeProvider>().repository;
    final future = repository
        .fetchProducts(
          categorySlug: _category.slug,
          sort: 'recommended',
          perPage: _productsPerPage,
          page: page,
        )
        .then((response) {
          final meta = Map<String, dynamic>.from(
            response['meta'] as Map? ?? <String, dynamic>{},
          );
          final products = List<ProductModel>.from(
            response['products'] as List<ProductModel>,
          );

          return _CategoryProductsPageData(
            products: List<ProductModel>.unmodifiable(products),
            currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
            lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
          );
        });

    _categoryProductsRequestCache[requestKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_categoryProductsRequestCache[requestKey], future)) {
        _categoryProductsRequestCache.remove(requestKey);
      }
    }
  }

  void _cacheCurrentProducts() {
    _categoryProductsCache[_category.slug] = _CategoryProductsCacheEntry(
      products: List<ProductModel>.unmodifiable(_products),
      currentPage: _currentPage,
      lastPage: _lastPage,
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _showsSubcategories ||
        _productQuery.trim().isNotEmpty) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 320;
    if (_scrollController.position.pixels >= threshold) {
      _loadMoreProducts();
    }
  }

  Future<void> _refreshCurrentView() async {
    if (_showsSubcategories) {
      await _prepareScreen(forceRefresh: true);
      return;
    }

    setState(() {
      _products = const <ProductModel>[];
      _currentPage = 0;
      _lastPage = 1;
      _productsError = null;
    });
    await _prepareScreen(forceRefresh: true);
  }

  void _openCategory(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  Future<void> _handleNavigationTap(int index) async {
    final auth = context.read<AuthProvider>();
    final isProfileDestination = index == AppShellController.profileIndex;

    if (isProfileDestination && !auth.isAuthenticated) {
      final action = await showAuthRequiredDialog(
        context,
        badge: 'هذه الصفحة تحتاج حساباً',
        title: 'سجّلي دخولك للوصول إلى حسابك',
        message:
            'صفحة حسابك تحتوي على طلباتك وعناوينك وبياناتك الشخصية، لذلك نحتاج إلى تسجيل الدخول قبل فتحها.',
        primaryLabel: 'تسجيل الدخول',
        secondaryLabel: 'لاحقاً',
        icon: AppIcons.person_rounded,
      );

      if (!mounted || action != AuthPromptAction.login) {
        return;
      }

      final didAuthenticate = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnAfterAuth: true),
        ),
      );

      if (!mounted || didAuthenticate != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    context.read<AppShellController>().setIndex(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final currentShellIndex = context.watch<AppShellController>().currentIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F8),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFFFF8F8)),
        child: RefreshIndicator(
          onRefresh: _refreshCurrentView,
          color: AppColors.primary,
          displacement: 110,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (_showsSubcategories)
                _SubcategoryExplorerHeaderSliver(
                  title: _category.name,
                  searchHint: 'إبحث في الفئات الفرعية...',
                  controller: _subcategorySearchController,
                  onBack: () => Navigator.pop(context),
                  onChanged: (value) {
                    setState(() => _subcategoryQuery = value);
                  },
                  onClear: () {
                    _subcategorySearchController.clear();
                    setState(() => _subcategoryQuery = '');
                  },
                )
              else
                _SubcategoryExplorerHeaderSliver(
                  title: _category.name,
                  searchHint: 'إبحث في منتجات الفئة...',
                  controller: _productSearchController,
                  onBack: () => Navigator.pop(context),
                  onChanged: (value) {
                    setState(() => _productQuery = value);
                  },
                  onClear: () {
                    _productSearchController.clear();
                    setState(() => _productQuery = '');
                  },
                ),
              if (_isPreparingCategory)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_categoryError != null && !_showsSubcategories)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorView(
                    error: _categoryError,
                    onRetry: () => _prepareScreen(forceRefresh: true),
                  ),
                )
              else if (_showsSubcategories)
                ..._buildSubcategorySlivers()
              else
                ..._buildProductSlivers(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: CustomNavBar(
          currentIndex: currentShellIndex,
          onTap: _handleNavigationTap,
        ),
      ),
    );
  }

  List<Widget> _buildSubcategorySlivers() {
    final children = _filteredSubcategories;
    if (children.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyCategoryState(
            title: 'لا توجد فئات فرعية',
            message: 'سيتم عرض المنتجات هنا عندما تصبح هذه الفئة جاهزة.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.80,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final child = children[index];
            return _SubcategoryCard(
              category: child,
              onTap: () => _openCategory(child),
            );
          }, childCount: children.length),
        ),
      ),
    ];
  }

  List<Widget> _buildProductSlivers() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _ProductsLoadingState(),
          ),
        ),
      ];
    }

    if (_productsError != null && _products.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            error: _productsError,
            onRetry: () => _prepareScreen(forceRefresh: true),
          ),
        ),
      ];
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyCategoryState(
            title: 'لا توجد منتجات حالياً',
            message: 'جرّب الرجوع إلى الفئات السابقة أو التحقق لاحقاً.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return _CategoryProductCard(product: products[index]);
          }, childCount: products.length),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isLoadingMoreProducts
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }
}

class _SubcategoryExplorerHeaderSliver extends StatelessWidget {
  final String title;
  final String searchHint;
  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SubcategoryExplorerHeaderSliver({
    required this.title,
    required this.searchHint,
    required this.controller,
    required this.onBack,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              _SubcategoryPlainHeader(title: title, onBack: onBack),
              const SizedBox(height: 22),
              _SubcategorySearchField(
                hintText: searchHint,
                controller: controller,
                onChanged: onChanged,
                onClear: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryPlainHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _SubcategoryPlainHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.rosePink.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.roseGold.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.arrow_forward_ios_rounded,
                    color: AppColors.mauve,
                    size: 18,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategorySearchField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SubcategorySearchField({
    required this.hintText,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7E7EA), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB76E79).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        textDirection: TextDirection.rtl,
        cursorColor: AppColors.primary,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB49DA1),
          ),
          prefixIcon: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsetsDirectional.only(
              start: 7,
              end: 8,
              top: 7,
              bottom: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              AppIcons.search_rounded,
              size: 21,
              color: AppColors.primary,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 60,
            minHeight: 58,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: IconButton(
                    onPressed: onClear,
                    splashRadius: 20,
                    icon: const Icon(
                      AppIcons.close_rounded,
                      size: 18,
                      color: Color(0xFF9E868B),
                    ),
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 58,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 17,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CategoryHeroSliver extends StatelessWidget {
  final CategoryModel category;

  const _CategoryHeroSliver({required this.category});

  double _expandedProgress(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null) {
      return 1.0;
    }

    final expandRange = settings.maxExtent - settings.minExtent;
    if (expandRange <= 0) {
      return 0.0;
    }

    return ((settings.currentExtent - settings.minExtent) / expandRange)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        category.imageUrl != null && category.imageUrl!.trim().isNotEmpty;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 250.0,
      elevation: 0,
      backgroundColor: const Color(0xFF8E4A54),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 72, bottom: 20),
        title: Builder(
          builder: (context) {
            final expandedProgress = _expandedProgress(context);
            final collapsedTitleOpacity = Curves.easeIn.transform(
              ((0.32 - expandedProgress) / 0.32).clamp(0.0, 1.0).toDouble(),
            );

            return Opacity(
              opacity: collapsedTitleOpacity,
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8E4A54), Color(0xFFB76E79)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -30,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category.children.isNotEmpty
                                    ? 'استكشف الفئات الفرعية'
                                    : 'منتجات هذه الفئة',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final expandedProgress = _expandedProgress(
                                  context,
                                );
                                final heroTitleOpacity = Curves.easeOut
                                    .transform(
                                      ((expandedProgress - 0.12) / 0.88)
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                                    );

                                return Opacity(
                                  opacity: heroTitleOpacity,
                                  child: Text(
                                    category.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (category.description != null &&
                                category.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                category.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.86),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: hasImage
                            ? Image.network(
                                category.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      _resolveCategoryIcon(
                                        category.slug,
                                        category.name,
                                      ),
                                      size: 44,
                                      color: Colors.white,
                                    ),
                              )
                            : Icon(
                                _resolveCategoryIcon(
                                  category.slug,
                                  category.name,
                                ),
                                size: 44,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _SubcategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        category.imageUrl != null && category.imageUrl!.trim().isNotEmpty;
    final hasChildren =
        category.children.isNotEmpty || category.childrenCount > 0;

    final countLabel = hasChildren
        ? '${category.childrenCount} فئة فرعية'
        : '${category.productsCount} منتج';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.roseGold.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.blush.withValues(alpha: 0.7),
                        Colors.white,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: hasImage
                      ? Image.network(
                          category.imageUrl!.trim(),
                          fit: BoxFit.contain,
                          cacheWidth: 320,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) =>
                              _SubcategoryInitial(name: category.name),
                        )
                      : _SubcategoryInitial(name: category.name),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mauve,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        countLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.roseGold,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryInitial extends StatelessWidget {
  final String name;

  const _SubcategoryInitial({required this.name});

  /// الحرف الأول من اسم الفئة بعد تجاوز أداة التعريف "ال" ليكون مميّزاً.
  String get _initial {
    var value = name.trim();
    if (value.isEmpty) return 'A';
    if (value.startsWith('ال') && value.characters.length > 2) {
      value = value.substring(2).trim();
    }
    if (value.isEmpty) return 'A';
    return value.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _initial,
          style: GoogleFonts.cairo(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: AppColors.roseGold.withValues(alpha: 0.85),
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Product card for the category grid — mirrors the home screen's `_ProductCard`
/// design: a full-bleed image stage on a blush ground with a favorite button and
/// sale/featured glass tag, over an eyebrow · name · subtitle · price + add-to-bag
/// info section.
class _CategoryProductCard extends StatelessWidget {
  final ProductModel product;

  const _CategoryProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final thumbnailRaw = product.thumbnail?.trim();
    final hasThumbnail = thumbnailRaw != null && thumbnailRaw.isNotEmpty;
    final thumbnailUrl = hasThumbnail ? thumbnailRaw : null;
    final effectivePrice = product.pricing.effectivePrice;
    final isAvailable = product.isPurchasable;
    final badgeLabel = product.pricing.isOnSale
        ? '-${product.pricing.discountPercentage.toStringAsFixed(0)}%'
        : (product.isFeatured ? 'LIMITED' : null);
    final eyebrowRaw = (product.category?.name ?? product.brand?.name)?.trim();
    final eyebrowLabel = (eyebrowRaw != null && eyebrowRaw.isNotEmpty)
        ? eyebrowRaw.toUpperCase()
        : null;
    final subtitle = (product.shortDescription?.trim().isNotEmpty ?? false)
        ? product.shortDescription!.trim()
        : (product.brand?.name ?? 'Soft Glow Finish');
    final imageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) /
                2)
            .round()
            .clamp(420, 900);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.08),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image / Icon Stage
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: hasThumbnail
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                                child: Image.network(
                                  thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: imageCacheWidth,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const _CategoryImagePlaceholder(),
                                ),
                              )
                            : const _CategoryImagePlaceholder(),
                      ),
                      if (hasThumbnail)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.02),
                                  Colors.black.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (!isAvailable)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.68),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'غير متوفر',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Badges (sale/featured tag + favorite)
                      Positioned(
                        top: 14,
                        right: 14,
                        left: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (badgeLabel != null)
                              _CategoryGlassTag(label: badgeLabel)
                            else
                              const SizedBox.shrink(),
                            Consumer<WishlistProvider>(
                              builder: (context, wishlist, child) {
                                final isFav = wishlist.isFavorite(product.id);
                                return GestureDetector(
                                  onTap: () {
                                    wishlist.toggleFavorite(product);
                                    AppNotifications.showSuccess(
                                      context,
                                      isFav
                                          ? 'تمت الإزالة من المفضلة'
                                          : 'تمت الإضافة للمفضلة',
                                    );
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: AppColors.shadowCard,
                                          blurRadius: 12,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isFav
                                          ? AppIcons.favorite_rounded
                                          : AppIcons.favorite_border_rounded,
                                      size: 18,
                                      color: AppColors.roseGold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Info Section
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrowLabel != null) ...[
                      Text(
                        eyebrowLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: AppColors.taupe,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      product.name,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mauve,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: AppColors.taupe,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  '${effectivePrice.toStringAsFixed(0)} د.ل',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.mauve,
                                    height: 1,
                                  ),
                                ),
                              ),
                              if (product.pricing.isOnSale) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${product.pricing.price.toStringAsFixed(0)} د.ل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textHint,
                                    height: 1,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.roseGold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Add to Cart Button
                        GestureDetector(
                          onTap: () {
                            if (!isAvailable) {
                              AppNotifications.showError(
                                context,
                                'المنتج غير متوفر حالياً',
                              );
                              return;
                            }
                            final result = context.read<CartProvider>().addItem(
                              CartItem(
                                id: CartItem.buildId(productId: product.id),
                                productId: product.id,
                                name: product.name,
                                price: effectivePrice,
                                imageUrl: thumbnailUrl ?? '',
                                maxQuantity: product.maxPurchasableQuantity,
                                isAvailable: isAvailable,
                                quantity: 1,
                              ),
                            );
                            if (!result.didChange) {
                              AppNotifications.showError(
                                context,
                                result.isLimitReached
                                    ? 'الكمية المتاحة حالياً ${result.maxQuantity ?? product.maxPurchasableQuantity} فقط'
                                    : 'المنتج غير متوفر حالياً',
                              );
                              return;
                            }
                            AppNotifications.showSuccess(
                              context,
                              'تمت إضافة ${product.name} للسلة',
                            );
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: isAvailable
                                  ? AppColors.roseGradient
                                  : null,
                              color: isAvailable
                                  ? null
                                  : const Color(0xFFDAC7CB),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isAvailable
                                              ? AppColors.roseGold
                                              : const Color(0xFF8B6F73))
                                          .withValues(alpha: 0.32),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              AppIcons.add_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted white pill tag (sale % / featured) used on the category product card,
/// matching the home screen's glass tag.
class _CategoryGlassTag extends StatelessWidget {
  final String label;

  const _CategoryGlassTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.roseGold,
          height: 1,
        ),
      ),
    );
  }
}

class _CategoryImagePlaceholder extends StatelessWidget {
  const _CategoryImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          AppIcons.image_outlined,
          size: 44,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ProductsLoadingState extends StatelessWidget {
  const _ProductsLoadingState();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryUltraLight.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryUltraLight.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primaryUltraLight.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 16,
                        width: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryUltraLight.withValues(
                            alpha: 0.38,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyCategoryState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primaryUltraLight.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.category_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryProductsCacheEntry {
  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;

  const _CategoryProductsCacheEntry({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });
}

class _CategoryProductsPageData {
  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;

  const _CategoryProductsPageData({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });
}

IconData _resolveCategoryIcon(String slug, String label) {
  final key = '$slug $label'.toLowerCase();

  if (key.contains('restaurant') ||
      key.contains('food') ||
      key.contains('مطعم') ||
      key.contains('مأكولات')) {
    return AppIcons.fastfood_rounded;
  }
  if (key.contains('pharmacy') ||
      key.contains('medicine') ||
      key.contains('صيد')) {
    return AppIcons.medication_rounded;
  }
  if (key.contains('store') || key.contains('shop') || key.contains('متجر')) {
    return AppIcons.shopping_bag_rounded;
  }
  if (key.contains('phone') ||
      key.contains('mobile') ||
      key.contains('الكتر') ||
      key.contains('هاتف')) {
    return AppIcons.phone_iphone_rounded;
  }
  if (key.contains('pet') || key.contains('animal') || key.contains('حيوان')) {
    return AppIcons.pets_rounded;
  }
  if (key.contains('card') ||
      key.contains('gift') ||
      key.contains('بطاقة') ||
      key.contains('كرت')) {
    return AppIcons.card_giftcard_rounded;
  }

  return AppIcons.category_rounded;
}
