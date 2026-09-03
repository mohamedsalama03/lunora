import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/app_notifications.dart';
import '../../../shared/widgets/custom_navbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/auth_required_dialog.dart';
import '../../cart/providers/cart_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/home_provider.dart';
import 'product_detail_screen.dart';

class CategoryExplorerScreen extends StatefulWidget {
  const CategoryExplorerScreen({super.key, required this.category});

  final CategoryModel category;

  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen> {
  static const int _productsPerPage = 18;
  static final Map<String, CategoryModel> _categoryNodeCache = {};
  static Future<void>? _categoryTreeWarmupFuture;
  static final Map<String, _CategoryProductsCacheEntry> _productsCache = {};
  static final Map<String, Future<_CategoryProductsPageData>> _requestCache =
      {};

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  CategoryModel? _resolvedCategory;
  bool _isPreparingCategory = false;
  String? _categoryError;
  String _query = '';

  bool _isLoadingProducts = false;
  bool _isLoadingMoreProducts = false;
  String? _productsError;
  List<ProductModel> _products = const [];
  int _currentPage = 0;
  int _lastPage = 1;

  CategoryModel get _category => _resolvedCategory ?? widget.category;
  bool get _showsSubcategories => _category.children.isNotEmpty;
  bool get _hasMoreProducts => _currentPage < _lastPage;

  List<CategoryModel> get _filteredSubcategories {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _category.children;
    return _category.children.where((category) {
      return category.name.toLowerCase().contains(query) ||
          category.slug.toLowerCase().contains(query);
    }).toList();
  }

  List<ProductModel> get _filteredProducts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.slug.toLowerCase().contains(query) ||
          (product.brand?.name.toLowerCase() ?? '').contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareScreen());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepareScreen({bool forceRefresh = false}) async {
    await _ensureResolvedCategory(forceRefresh: forceRefresh);
    if (!mounted || _showsSubcategories) return;
    await _loadInitialProducts(forceRefresh: forceRefresh);
  }

  Future<void> _ensureResolvedCategory({bool forceRefresh = false}) async {
    final needsResolution =
        widget.category.children.isEmpty && widget.category.childrenCount > 0;
    if (!needsResolution) {
      _resolvedCategory = widget.category;
      return;
    }

    final cached = !forceRefresh
        ? _categoryNodeCache[widget.category.slug]
        : null;
    if (cached != null) {
      _resolvedCategory = cached;
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
      if (mounted) {
        setState(() {
          _resolvedCategory = _categoryNodeCache[widget.category.slug];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _categoryError = error.toString());
    } finally {
      if (mounted) setState(() => _isPreparingCategory = false);
    }
  }

  Future<void> _warmupCategoryTree({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _categoryTreeWarmupFuture = null;
      _categoryNodeCache.clear();
    }
    final pending = _categoryTreeWarmupFuture;
    if (pending != null) {
      await pending;
      return;
    }

    final future = context
        .read<HomeProvider>()
        .repository
        .fetchCategories()
        .then(_cacheCategoryTree);
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
    if (_showsSubcategories) return;
    final slug = _category.slug;
    if (forceRefresh) _productsCache.remove(slug);
    final cached = _productsCache[slug];
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
      if (!mounted) return;
      setState(() {
        _products = pageData.products;
        _currentPage = pageData.currentPage;
        _lastPage = pageData.lastPage;
      });
      _cacheCurrentProducts();
    } catch (error) {
      if (mounted) setState(() => _productsError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_showsSubcategories ||
        _isLoadingProducts ||
        _isLoadingMoreProducts ||
        !_hasMoreProducts) {
      return;
    }
    setState(() => _isLoadingMoreProducts = true);
    try {
      final pageData = await _fetchProductsPage(page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...pageData.products];
        _currentPage = pageData.currentPage;
        _lastPage = pageData.lastPage;
      });
      _cacheCurrentProducts();
    } catch (error) {
      if (mounted) setState(() => _productsError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingMoreProducts = false);
    }
  }

  Future<_CategoryProductsPageData> _fetchProductsPage({
    required int page,
  }) async {
    final key = '${_category.slug}::$page';
    final pending = _requestCache[key];
    if (pending != null) return pending;

    final future = context
        .read<HomeProvider>()
        .repository
        .fetchProducts(
          categorySlug: _category.slug,
          sort: 'recommended',
          perPage: _productsPerPage,
          page: page,
        )
        .then((response) {
          final meta = Map<String, dynamic>.from(
            response['meta'] as Map? ?? const <String, dynamic>{},
          );
          return _CategoryProductsPageData(
            products: List<ProductModel>.unmodifiable(
              List<ProductModel>.from(
                response['products'] as List<ProductModel>,
              ),
            ),
            currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
            lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
          );
        });
    _requestCache[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_requestCache[key], future)) _requestCache.remove(key);
    }
  }

  void _cacheCurrentProducts() {
    _productsCache[_category.slug] = _CategoryProductsCacheEntry(
      products: List<ProductModel>.unmodifiable(_products),
      currentPage: _currentPage,
      lastPage: _lastPage,
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _showsSubcategories ||
        _query.trim().isNotEmpty) {
      return;
    }
    if (_scrollController.position.extentAfter < 360) _loadMoreProducts();
  }

  Future<void> _refresh() async {
    setState(() {
      _products = const [];
      _currentPage = 0;
      _lastPage = 1;
      _productsError = null;
    });
    await _prepareScreen(forceRefresh: true);
  }

  void _openCategory(CategoryModel category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  Future<void> _handleNavigationTap(int index) async {
    final auth = context.read<AuthProvider>();
    if (index == AppShellController.profileIndex && !auth.isAuthenticated) {
      final action = await showAuthRequiredDialog(
        context,
        badge: 'هذه الصفحة تحتاج حسابًا',
        title: 'سجّلي دخولك للوصول إلى حسابك',
        message:
            'صفحة حسابك تحتوي على طلباتك وعناوينك، لذلك نحتاج إلى تسجيل الدخول أولًا.',
        primaryLabel: 'تسجيل الدخول',
        secondaryLabel: 'لاحقًا',
        icon: AppIcons.person_outline_rounded,
      );
      if (!mounted || action != AuthPromptAction.login) return;
      final authenticated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const LoginScreen(returnAfterAuth: true),
        ),
      );
      if (!mounted || authenticated != true) return;
    }
    if (!mounted) return;
    context.read<AppShellController>().setIndex(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final shellIndex = context.watch<AppShellController>().currentIndex;
    return Scaffold(
      backgroundColor: _CategoryColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _CategoryColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _CategoryHero(category: _category),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _CategorySearchField(
                    controller: _searchController,
                    hint: _showsSubcategories
                        ? 'ابحثي في الفئات الفرعية…'
                        : 'ابحثي في منتجات الفئة…',
                    hasText: _query.isNotEmpty,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              if (_isPreparingCategory)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _CategoryColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_categoryError != null && !_showsSubcategories)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CategoryErrorState(
                    message: 'تعذّر تحميل هذه الفئة.',
                    onRetry: () => _prepareScreen(forceRefresh: true),
                  ),
                )
              else if (_showsSubcategories)
                ..._subcategorySlivers()
              else
                ..._productSlivers(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomNavBar(
        currentIndex: shellIndex,
        onTap: _handleNavigationTap,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Material(
            color: _CategoryColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: _CategoryColors.border),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  AppIcons.arrow_forward_rounded,
                  size: 19,
                  color: _CategoryColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showsSubcategories ? 'المجموعات' : 'الكتالوج',
                  style: _categoryText(
                    size: 11,
                    weight: FontWeight.w500,
                    color: _CategoryColors.mutedText,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _categoryText(size: 24, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _subcategorySlivers() {
    final categories = _filteredSubcategories;
    if (categories.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CategoryEmptyState(
            icon: AppIcons.category_outlined,
            title: 'لا توجد فئات مطابقة',
            message: 'جرّبي كلمة بحث أخرى.',
          ),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(
        child: _CategorySectionHeader(
          eyebrow: 'اختاري وجهتك',
          title: 'الفئات الفرعية',
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              return SizedBox(
                width: 200,
                child: _SubcategoryCard(
                  category: category,
                  onTap: () => _openCategory(category),
                ),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ];
  }

  List<Widget> _productSlivers() {
    if (_isLoadingProducts && _products.isEmpty) {
      return const [SliverToBoxAdapter(child: _CategoryProductGridSkeleton())];
    }
    if (_productsError != null && _products.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CategoryErrorState(
            message: 'تعذّر تحميل المنتجات.',
            onRetry: () => _prepareScreen(forceRefresh: true),
          ),
        ),
      ];
    }
    final products = _filteredProducts;
    if (products.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CategoryEmptyState(
            icon: AppIcons.inventory_2_outlined,
            title: 'لا توجد منتجات حاليًا',
            message: 'جرّبي الرجوع إلى الفئات السابقة أو التحقق لاحقًا.',
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: _CategorySectionHeader(
          eyebrow: '${products.length} قطعة',
          title: 'منتجات ${_category.name}',
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 32,
            childAspectRatio: .54,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _CategoryProductCard(product: products[index]),
            childCount: products.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoadingMoreProducts
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _CategoryColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const SizedBox(height: 80),
        ),
      ),
    ];
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final hasImage = (category.imageUrl ?? '').trim().isNotEmpty;
    final count = _categoryProductsCount(category);
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CategoryNetworkImage(
              url: category.imageUrl,
              fallbackIcon: AppIcons.checkroom_outlined,
            ),
            if (hasImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x994A3428)],
                    stops: [.38, 1],
                  ),
                ),
              ),
            PositionedDirectional(
              start: 24,
              end: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.children.isNotEmpty
                        ? '${category.children.length} مجموعات'
                        : '$count قطعة',
                    style: _categoryText(
                      size: 11,
                      weight: FontWeight.w500,
                      color: hasImage
                          ? _CategoryColors.onPrimary.withValues(alpha: .82)
                          : _CategoryColors.mutedText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _categoryText(
                      size: 30,
                      weight: FontWeight.w500,
                      color: hasImage
                          ? _CategoryColors.onPrimary
                          : _CategoryColors.text,
                      height: 1.2,
                    ),
                  ),
                  if ((category.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      category.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _categoryText(
                        size: 13,
                        color: hasImage
                            ? _CategoryColors.onPrimary.withValues(alpha: .85)
                            : _CategoryColors.mutedText,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySearchField extends StatelessWidget {
  const _CategorySearchField({
    required this.controller,
    required this.hint,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _CategoryColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CategoryColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        cursorColor: _CategoryColors.primary,
        style: _categoryText(size: 14, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _categoryText(size: 13, color: _CategoryColors.mutedText),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            size: 19,
            color: _CategoryColors.mutedText,
          ),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: onClear,
                  icon: const Icon(
                    AppIcons.close_rounded,
                    size: 18,
                    color: _CategoryColors.text,
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = (category.imageUrl ?? '').trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CategoryNetworkImage(
                url: category.imageUrl,
                fallbackIcon: AppIcons.category_outlined,
              ),
              if (hasImage)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x994A3428)],
                      stops: [.4, 1],
                    ),
                  ),
                ),
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_categoryProductsCount(category)} قطعة',
                      style: _categoryText(
                        size: 10,
                        color: hasImage
                            ? _CategoryColors.onPrimary.withValues(alpha: .8)
                            : _CategoryColors.mutedText,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _categoryText(
                        size: 18,
                        weight: FontWeight.w500,
                        color: hasImage
                            ? _CategoryColors.onPrimary
                            : _CategoryColors.text,
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

class _CategoryProductCard extends StatelessWidget {
  const _CategoryProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final label = (product.brand?.name ?? product.category?.name ?? 'لونورا')
        .trim();
    final showSale =
        product.pricing.isOnSale &&
        product.pricing.price > product.pricing.effectivePrice;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CategoryNetworkImage(
                      url: product.thumbnail,
                      fallbackIcon: AppIcons.inventory_2_outlined,
                    ),
                    if (showSale)
                      PositionedDirectional(
                        start: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _CategoryColors.background.withValues(
                              alpha: .9,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '−${product.pricing.discountPercentage}%',
                            style: _categoryText(
                              size: 10,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      end: 12,
                      top: 12,
                      child: Consumer<WishlistProvider>(
                        builder: (context, wishlist, _) {
                          final saved = wishlist.isFavorite(product.id);
                          return _CategoryIconButton(
                            icon: saved
                                ? AppIcons.favorite_rounded
                                : AppIcons.favorite_border_rounded,
                            iconColor: saved
                                ? _CategoryColors.accent
                                : _CategoryColors.text,
                            tooltip: saved
                                ? 'إزالة من المفضلة'
                                : 'إضافة إلى المفضلة',
                            onTap: () {
                              wishlist.toggleFavorite(product);
                              AppNotifications.showSuccess(
                                context,
                                saved
                                    ? 'تمت الإزالة من المفضلة'
                                    : 'تم الحفظ في المفضلة',
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _categoryText(size: 11, color: _CategoryColors.mutedText),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _categoryText(
                size: 14,
                weight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _categoryPrice(product.pricing.effectivePrice),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: _categoryText(size: 14, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryIconButton(
                  icon: AppIcons.shopping_bag_outlined,
                  iconColor: _CategoryColors.onPrimary,
                  backgroundColor: _CategoryColors.primary,
                  enabled: product.isPurchasable,
                  tooltip: 'إضافة إلى السلة',
                  onTap: () => _addToCart(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    if (product.hasPendingVariantStock) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
      return;
    }
    final result = context.read<CartProvider>().addItem(
      CartItem(
        id: CartItem.buildId(productId: product.id),
        productId: product.id,
        name: product.name,
        price: product.pricing.effectivePrice,
        imageUrl: product.thumbnail ?? '',
        maxQuantity: product.maxPurchasableQuantity,
        isAvailable: product.isPurchasable,
      ),
    );
    if (!result.didChange) {
      AppNotifications.showError(
        context,
        result.isLimitReached
            ? 'الكمية المتاحة ${result.maxQuantity ?? product.maxPurchasableQuantity} فقط'
            : 'المنتج غير متوفر حاليًا',
      );
      return;
    }
    AppNotifications.showSuccess(context, 'تمت الإضافة إلى السلة');
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: _categoryText(
              size: 11,
              weight: FontWeight.w500,
              color: _CategoryColors.mutedText,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _categoryText(size: 24, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CategoryIconButton extends StatelessWidget {
  const _CategoryIconButton({
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .42,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color:
              backgroundColor ??
              _CategoryColors.background.withValues(alpha: .9),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryNetworkImage extends StatelessWidget {
  const _CategoryNetworkImage({required this.url, required this.fallbackIcon});

  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _CategoryImageFallback(icon: fallbackIcon);
    }
    return Image.network(
      normalized,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _CategoryImageFallback(icon: fallbackIcon),
    );
  }
}

class _CategoryImageFallback extends StatelessWidget {
  const _CategoryImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _CategoryColors.secondary.withValues(alpha: .65),
      child: Center(
        child: Icon(
          icon,
          size: 34,
          color: _CategoryColors.primary.withValues(alpha: .45),
        ),
      ),
    );
  }
}

class _CategoryProductGridSkeleton extends StatelessWidget {
  const _CategoryProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 32,
          childAspectRatio: .54,
        ),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: _CategorySkeletonBox(radius: 16),
            ),
            SizedBox(height: 12),
            _CategorySkeletonLine(width: 70),
            SizedBox(height: 8),
            _CategorySkeletonLine(width: 120),
            SizedBox(height: 8),
            _CategorySkeletonLine(width: 80),
          ],
        ),
      ),
    );
  }
}

class _CategorySkeletonBox extends StatelessWidget {
  const _CategorySkeletonBox({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _CategoryColors.secondary.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CategorySkeletonLine extends StatelessWidget {
  const _CategorySkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: _CategoryColors.secondary.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: _CategoryColors.secondary,
              child: Icon(icon, size: 28, color: _CategoryColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _categoryText(size: 18, weight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _categoryText(
                size: 13,
                color: _CategoryColors.mutedText,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryErrorState extends StatelessWidget {
  const _CategoryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: _CategoryColors.secondary,
              child: Icon(
                AppIcons.wifi_off_rounded,
                color: _CategoryColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _categoryText(size: 15, weight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _CategoryColors.primary,
                foregroundColor: _CategoryColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'إعادة المحاولة',
                style: _categoryText(
                  size: 12,
                  weight: FontWeight.w500,
                  color: _CategoryColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryProductsCacheEntry {
  const _CategoryProductsCacheEntry({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;
}

class _CategoryProductsPageData {
  const _CategoryProductsPageData({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;
}

class _CategoryColors {
  const _CategoryColors._();

  static const background = Color(0xFFF8F5F0);
  static const surface = Color(0xFFFCFAF6);
  static const primary = Color(0xFF4A3428);
  static const onPrimary = Color(0xFFFFFBF5);
  static const secondary = Color(0xFFEADCC8);
  static const text = Color(0xFF2E211B);
  static const mutedText = Color(0xFF6D5A4D);
  static const border = Color(0xFFE4DBCE);
  static const accent = Color(0xFFB88746);
}

TextStyle _categoryText({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _CategoryColors.text,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.cairo(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

String _categoryPrice(double value) {
  final decimals = value % 1 == 0 ? 0 : 2;
  return '${value.toStringAsFixed(decimals)} د.ل';
}

int _categoryProductsCount(CategoryModel category) {
  return category.productsCount +
      category.children.fold<int>(
        0,
        (total, child) => total + _categoryProductsCount(child),
      );
}
