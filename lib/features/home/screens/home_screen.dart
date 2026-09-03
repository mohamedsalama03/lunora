import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_banner_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/home_provider.dart';
import 'category_explorer_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _bannerController = PageController();
  int _activeBanner = 0;
  int _knownBannerCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeProvider>().ensureInitialDataLoaded();
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  CategoryModel? _findCategory(List<CategoryModel> categories, int id) {
    for (final category in categories) {
      if (category.id == id) return category;
      final nested = _findCategory(category.children, id);
      if (nested != null) return nested;
    }
    return null;
  }

  void _openCategory(CategoryModel category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  void _openCatalog({bool autofocusSearch = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HomeCatalogScreen(autofocusSearch: autofocusSearch),
      ),
    );
  }

  void _handleBanner(AppBannerItem banner, List<CategoryModel> categories) {
    if (banner.type != 'category' || banner.linkedId == null) return;
    final category = _findCategory(categories, banner.linkedId!);
    if (category != null) _openCategory(category);
  }

  void _synchronizeBannerCount(int count) {
    if (_knownBannerCount == count) return;
    _knownBannerCount = count;
    final target = count == 0
        ? 0
        : _activeBanner >= count
        ? count - 1
        : _activeBanner;
    if (target == _activeBanner) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        _bannerController.jumpToPage(target);
      }
      if (_activeBanner != target) setState(() => _activeBanner = target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    _synchronizeBannerCount(home.appBanners.length);
    final hasData =
        home.categories.isNotEmpty ||
        home.products.isNotEmpty ||
        home.ourProducts.isNotEmpty ||
        home.saleProducts.isNotEmpty ||
        home.appBanners.isNotEmpty;
    final firstError =
        home.categoriesError ??
        home.productsError ??
        home.ourProductsError ??
        home.saleProductsError ??
        home.appBannersError;
    final isLoading =
        home.isLoadingCategories ||
        home.isLoadingProducts ||
        home.isLoadingOurProducts ||
        home.isLoadingSaleProducts ||
        home.isLoadingAppBanners;

    if (!hasData && firstError != null && !isLoading) {
      return Scaffold(
        backgroundColor: _AuraColors.background,
        body: SafeArea(
          child: _AuraErrorState(
            message: 'تعذّر تحميل المتجر الآن.',
            onRetry: () => context.read<HomeProvider>().ensureInitialDataLoaded(
              forceRefresh: true,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _AuraColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _AuraColors.primary,
          onRefresh: () => context.read<HomeProvider>().ensureInitialDataLoaded(
            forceRefresh: true,
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _HeroCarousel(
                    controller: _bannerController,
                    banners: home.appBanners,
                    activeIndex: _activeBanner,
                    isLoading: home.isLoadingAppBanners,
                    error: home.appBannersError,
                    onPageChanged: (index) =>
                        setState(() => _activeBanner = index),
                    onTap: (banner) => _handleBanner(banner, home.categories),
                    onRetry: () => context
                        .read<HomeProvider>()
                        .ensureInitialDataLoaded(forceRefresh: true),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: _CategoryChips(
                  categories: home.categories,
                  isLoading: home.isLoadingCategories,
                  onAllTap: () => _openCatalog(),
                  onCategoryTap: _openCategory,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  eyebrow: 'مختارات هادئة',
                  title: 'تسوّقي حسب الفئة',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _CollectionsRail(
                  categories: home.categories,
                  isLoading: home.isLoadingCategories,
                  error: home.categoriesError,
                  onTap: _openCategory,
                  onRetry: () => context
                      .read<HomeProvider>()
                      .ensureInitialDataLoaded(forceRefresh: true),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: _ProductSection(
                  eyebrow: 'وصل حديثًا',
                  title: 'مختارات هذا الأسبوع',
                  products: home.products,
                  isLoading: home.isLoadingProducts,
                  error: home.productsError,
                  onViewAll: () => _openCatalog(),
                  onRetry: () => context
                      .read<HomeProvider>()
                      .ensureInitialDataLoaded(forceRefresh: true),
                ),
              ),
              if (home.saleProducts.isNotEmpty ||
                  home.isLoadingSaleProducts ||
                  home.saleProductsError != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                SliverToBoxAdapter(
                  child: _ProductSection(
                    eyebrow: 'لفترة محدودة',
                    title: 'عروض مختارة',
                    products: home.saleProducts,
                    isLoading: home.isLoadingSaleProducts,
                    error: home.saleProductsError,
                    onViewAll: () => _openCatalog(),
                    onRetry: () => context
                        .read<HomeProvider>()
                        .ensureInitialDataLoaded(forceRefresh: true),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: _ProductSection(
                  eyebrow: 'اختيار لونورا',
                  title: 'قد يعجبك أيضًا',
                  products: home.ourProducts,
                  isLoading: home.isLoadingOurProducts,
                  error: home.ourProductsError,
                  onViewAll: () => _openCatalog(),
                  onRetry: () => context
                      .read<HomeProvider>()
                      .ensureInitialDataLoaded(forceRefresh: true),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final userName = context.select<AuthProvider, String?>(
      (provider) => provider.user?.name.trim(),
    );
    final firstName = userName == null || userName.isEmpty
        ? null
        : userName.split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUNORA — 2026',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _AuraColors.mutedText,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName == null
                      ? 'مرحبًا بك في لونورا'
                      : 'صباح الأناقة، $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _auraText(size: 18, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _RoundIconButton(
            icon: AppIcons.search_rounded,
            tooltip: 'البحث',
            onTap: () => _openCatalog(autofocusSearch: true),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            icon: AppIcons.notifications_none_rounded,
            tooltip: 'الإشعارات',
            showDot: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.banners,
    required this.activeIndex,
    required this.isLoading,
    required this.error,
    required this.onPageChanged,
    required this.onTap,
    required this.onRetry,
  });

  final PageController controller;
  final List<AppBannerItem> banners;
  final int activeIndex;
  final bool isLoading;
  final String? error;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AppBannerItem> onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && banners.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 5,
        child: _SkeletonBox(radius: 28),
      );
    }
    if (error != null && banners.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: _AuraErrorState(
          compact: true,
          message: 'تعذّر تحميل واجهة الموسم.',
          onRetry: onRetry,
        ),
      );
    }
    if (banners.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _AuraColors.secondary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'المختارات الجديدة',
                style: _auraText(
                  size: 11,
                  weight: FontWeight.w500,
                  color: _AuraColors.mutedText,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تفاصيل هادئة،\nأناقة تدوم.',
                style: _auraText(size: 30, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: banners.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final banner = banners[index];
                final imageUrl = banner.imageUrlForWidth(
                  MediaQuery.sizeOf(context).width,
                );
                return GestureDetector(
                  onTap: () => onTap(banner),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: AppIcons.checkroom_outlined,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x174A3428),
                              Color(0x804A3428),
                            ],
                            stops: [0.35, 0.58, 1],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 24,
                        end: 24,
                        bottom: 24,
                        child: _HeroCopy(banner: banner),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (banners.length > 1)
              PositionedDirectional(
                end: 20,
                top: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _AuraColors.background.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${activeIndex + 1}/${banners.length}',
                    style: _auraText(size: 10, weight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.banner});

  final AppBannerItem banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((banner.badgeText ?? '').trim().isNotEmpty)
          Text(
            banner.badgeText!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _auraText(
              size: 11,
              weight: FontWeight.w500,
              color: _AuraColors.onPrimary.withValues(alpha: .82),
              letterSpacing: 1.6,
            ),
          ),
        if ((banner.title ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            banner.title!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _auraText(
              size: 30,
              weight: FontWeight.w500,
              color: _AuraColors.onPrimary,
              height: 1.2,
            ),
          ),
        ],
        if ((banner.subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            banner.subtitle!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _auraText(
              size: 13,
              color: _AuraColors.onPrimary.withValues(alpha: .86),
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _AuraColors.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (banner.ctaText ?? '').trim().isEmpty
                    ? 'اكتشفي المجموعة'
                    : banner.ctaText!.trim(),
                style: _auraText(size: 12, weight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              const Icon(
                AppIcons.arrow_back_rounded,
                size: 16,
                color: _AuraColors.text,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.isLoading,
    required this.onAllTap,
    required this.onCategoryTap,
  });

  final List<CategoryModel> categories;
  final bool isLoading;
  final VoidCallback onAllTap;
  final ValueChanged<CategoryModel> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: const [
            _SkeletonPill(width: 72),
            SizedBox(width: 8),
            _SkeletonPill(width: 96),
            SizedBox(width: 8),
            _SkeletonPill(width: 84),
          ],
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          return _FilterChip(
            label: isAll ? 'الكل' : categories[index - 1].name,
            selected: isAll,
            onTap: isAll
                ? onAllTap
                : () => onCategoryTap(categories[index - 1]),
          );
        },
      ),
    );
  }
}

class _CollectionsRail extends StatelessWidget {
  const _CollectionsRail({
    required this.categories,
    required this.isLoading,
    required this.error,
    required this.onTap,
    required this.onRetry,
  });

  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;
  final ValueChanged<CategoryModel> onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return SizedBox(
        height: 326,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: const [
            SizedBox(width: 260, child: _SkeletonBox(radius: 16)),
            SizedBox(width: 12),
            SizedBox(width: 260, child: _SkeletonBox(radius: 16)),
          ],
        ),
      );
    }
    if (error != null && categories.isEmpty) {
      return SizedBox(
        height: 220,
        child: _AuraErrorState(
          compact: true,
          message: 'تعذّر تحميل الفئات.',
          onRetry: onRetry,
        ),
      );
    }
    if (categories.isEmpty) {
      return const _InlineEmpty(message: 'لا توجد فئات متاحة حاليًا.');
    }

    return SizedBox(
      height: 326,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return SizedBox(
            width: 260,
            child: _CollectionCard(
              category: category,
              onTap: () => onTap(category),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.category, required this.onTap});

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
              _NetworkImage(
                url: category.imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: AppIcons.checkroom_outlined,
              ),
              if (hasImage)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x994A3428)],
                      stops: [.42, 1],
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
                      '${_categoryProductCount(category)} قطعة',
                      style: _auraText(
                        size: 10,
                        weight: FontWeight.w500,
                        color: hasImage
                            ? _AuraColors.onPrimary.withValues(alpha: .82)
                            : _AuraColors.mutedText,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _auraText(
                        size: 18,
                        weight: FontWeight.w500,
                        color: hasImage
                            ? _AuraColors.onPrimary
                            : _AuraColors.text,
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

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.eyebrow,
    required this.title,
    required this.products,
    required this.isLoading,
    required this.error,
    required this.onViewAll,
    required this.onRetry,
  });

  final String eyebrow;
  final String title;
  final List<ProductModel> products;
  final bool isLoading;
  final String? error;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          eyebrow: eyebrow,
          title: title,
          actionLabel: 'عرض الكل',
          onAction: onViewAll,
        ),
        const SizedBox(height: 20),
        if (isLoading && products.isEmpty)
          const _ProductGridSkeleton()
        else if (error != null && products.isEmpty)
          SizedBox(
            height: 210,
            child: _AuraErrorState(
              compact: true,
              message: 'تعذّر تحميل المنتجات.',
              onRetry: onRetry,
            ),
          )
        else if (products.isEmpty)
          const _InlineEmpty(message: 'لا توجد منتجات في هذا القسم حاليًا.')
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.take(6).length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 32,
                childAspectRatio: .56,
              ),
              itemBuilder: (context, index) =>
                  _AuraProductCard(product: products[index]),
            ),
          ),
      ],
    );
  }
}

class _AuraProductCard extends StatelessWidget {
  const _AuraProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final category =
        (product.category?.name ?? product.brand?.name ?? 'مختارات لونورا')
            .trim();
    final originalPrice = product.pricing.price;
    final effectivePrice = product.pricing.effectivePrice;
    final showSale = product.pricing.isOnSale && originalPrice > effectivePrice;

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
                    _NetworkImage(
                      url: product.thumbnail,
                      fit: BoxFit.cover,
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
                            color: _AuraColors.background.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '−${product.pricing.discountPercentage}%',
                            style: _auraText(size: 10, weight: FontWeight.w500),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      end: 12,
                      top: 12,
                      child: Consumer<WishlistProvider>(
                        builder: (context, wishlist, _) {
                          final saved = wishlist.isFavorite(product.id);
                          return _ImageIconButton(
                            icon: saved
                                ? AppIcons.favorite_rounded
                                : AppIcons.favorite_border_rounded,
                            color: saved
                                ? _AuraColors.accent
                                : _AuraColors.text,
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
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _auraText(size: 11, color: _AuraColors.mutedText),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _auraText(size: 14, weight: FontWeight.w500, height: 1.35),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  _formatPrice(effectivePrice),
                  style: _auraText(size: 14, weight: FontWeight.w500),
                ),
                if (showSale) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatPrice(originalPrice),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: _auraText(
                        size: 11,
                        color: _AuraColors.mutedText,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if ((product.options?.colors ?? const <String>[]).isNotEmpty) ...[
              const SizedBox(height: 8),
              _ColorDots(colors: product.options!.colors),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: _auraText(
                    size: 11,
                    weight: FontWeight.w500,
                    color: _AuraColors.mutedText,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: _auraText(size: 24, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                foregroundColor: _AuraColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: _auraText(size: 12, weight: FontWeight.w500),
              ),
              label: Text(actionLabel!),
              icon: const Icon(AppIcons.north_west_rounded, size: 15),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _AuraColors.primary : _AuraColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? _AuraColors.primary : _AuraColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            style: _auraText(
              size: 12,
              weight: FontWeight.w500,
              color: selected ? _AuraColors.onPrimary : _AuraColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _AuraColors.surface,
        shape: const CircleBorder(side: BorderSide(color: _AuraColors.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: _AuraColors.text),
                if (showDot)
                  const PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _AuraColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 6, height: 6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageIconButton extends StatelessWidget {
  const _ImageIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AuraColors.background.withValues(alpha: .88),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({required this.colors});

  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    final visibleColors = colors.take(3).toList();
    return Row(
      children: visibleColors.asMap().entries.map((entry) {
        return Container(
          width: 12,
          height: 12,
          margin: EdgeInsetsDirectional.only(
            end: entry.key == visibleColors.length - 1 ? 0 : 5,
          ),
          decoration: BoxDecoration(
            color:
                _tryParseColor(entry.value) ??
                _fallbackSwatches[entry.key % _fallbackSwatches.length],
            shape: BoxShape.circle,
            border: Border.all(color: _AuraColors.border),
          ),
        );
      }).toList(),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.url,
    required this.fit,
    required this.fallbackIcon,
  });

  final String? url;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _ImageFallback(icon: fallbackIcon);
    }
    return Image.network(
      normalized,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _ImageFallback(icon: fallbackIcon),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _AuraColors.secondary.withValues(alpha: .65),
      child: Center(
        child: Icon(
          icon,
          size: 34,
          color: _AuraColors.primary.withValues(alpha: .45),
        ),
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 32,
          childAspectRatio: .56,
        ),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 4 / 5, child: _SkeletonBox(radius: 16)),
            SizedBox(height: 12),
            _SkeletonLine(width: 72),
            SizedBox(height: 8),
            _SkeletonLine(width: 124),
            SizedBox(height: 8),
            _SkeletonLine(width: 82),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _AuraColors.secondary.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: const _SkeletonBox(radius: 999));
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: _AuraColors.secondary.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _auraText(size: 13, color: _AuraColors.mutedText),
        ),
      ),
    );
  }
}

class _AuraErrorState extends StatelessWidget {
  const _AuraErrorState({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 52 : 68,
              height: compact ? 52 : 68,
              decoration: const BoxDecoration(
                color: _AuraColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.wifi_off_rounded,
                size: compact ? 22 : 28,
                color: _AuraColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _auraText(
                size: compact ? 13 : 16,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _AuraColors.primary,
                foregroundColor: _AuraColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                shape: const StadiumBorder(),
              ),
              child: Text(
                'إعادة المحاولة',
                style: _auraText(
                  size: 12,
                  weight: FontWeight.w500,
                  color: _AuraColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCatalogScreen extends StatefulWidget {
  const _HomeCatalogScreen({this.autofocusSearch = false});

  final bool autofocusSearch;

  @override
  State<_HomeCatalogScreen> createState() => _HomeCatalogScreenState();
}

class _HomeCatalogScreenState extends State<_HomeCatalogScreen> {
  static const int _productsPerPage = 20;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<ProductModel> _products = const <ProductModel>[];
  String _activeQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  int _lastPage = 1;
  int _requestVersion = 0;

  bool get _hasMore => _currentPage < _lastPage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFirstPage();
      if (widget.autofocusSearch) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter < 320) _loadMore();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _requestVersion++;
    setState(() {
      _error = null;
      _isLoading = true;
      _isLoadingMore = false;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 380), _loadFirstPage);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.requestFocus();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    final version = ++_requestVersion;
    setState(() {
      _activeQuery = query;
      _products = const <ProductModel>[];
      _currentPage = 0;
      _lastPage = 1;
      _error = null;
      _isLoading = true;
      _isLoadingMore = false;
    });

    try {
      final page = await _fetchPage(query: query, page: 1);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _products = page.products;
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final version = _requestVersion;
    final query = _activeQuery;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchPage(query: query, page: _currentPage + 1);
      if (!mounted || version != _requestVersion || query != _activeQuery) {
        return;
      }
      final knownIds = _products.map((product) => product.id).toSet();
      setState(() {
        _products = List<ProductModel>.unmodifiable(<ProductModel>[
          ..._products,
          ...page.products.where((product) => knownIds.add(product.id)),
        ]);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<_CatalogPage> _fetchPage({
    required String query,
    required int page,
  }) async {
    final response = await context
        .read<HomeProvider>()
        .repository
        .fetchProducts(
          query: query.isEmpty ? null : query,
          sort: 'recommended',
          perPage: _productsPerPage,
          page: page,
        );
    final products = List<ProductModel>.from(
      response['products'] as List<ProductModel>,
    );
    final meta = Map<String, dynamic>.from(
      response['meta'] as Map? ?? const <String, dynamic>{},
    );
    return _CatalogPage(
      products: List<ProductModel>.unmodifiable(products),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AuraColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _AuraColors.primary,
          onRefresh: _loadFirstPage,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _CatalogSearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: widget.autofocusSearch,
                    isLoading: _isLoading,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                    onSubmitted: _loadFirstPage,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              if (_isLoading)
                const SliverToBoxAdapter(child: _ProductGridSkeleton())
              else if (_error != null && _products.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _AuraErrorState(
                    message: 'تعذّر تحميل المنتجات الآن.',
                    onRetry: _loadFirstPage,
                  ),
                )
              else if (_products.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CatalogEmptyState(
                    hasQuery: _activeQuery.isNotEmpty,
                    onEditSearch: _searchFocusNode.requestFocus,
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Row(
                      children: [
                        Text(
                          '${_products.length} قطعة',
                          style: _auraText(
                            size: 12,
                            color: _AuraColors.mutedText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'الترتيب · مقترح لك',
                          style: _auraText(size: 12, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 32,
                          childAspectRatio: .56,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _AuraProductCard(product: _products[index]),
                      childCount: _products.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 32),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _AuraColors.primary,
                              ),
                            ),
                          )
                        : const SizedBox(height: 32),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Material(
            color: _AuraColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: _AuraColors.border),
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
                  color: _AuraColors.text,
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
                  'LUNORA — CATALOG',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _AuraColors.mutedText,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _activeQuery.isEmpty ? 'تسوّقي الكل' : 'نتائج البحث',
                  style: _auraText(size: 24, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _AuraColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _AuraColors.border),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        cursorColor: _AuraColors.primary,
        style: _auraText(size: 14, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'ابحثي عن منتج أو علامة…',
          hintStyle: _auraText(size: 13, color: _AuraColors.mutedText),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            size: 19,
            color: _AuraColors.mutedText,
          ),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _AuraColors.primary,
                    ),
                  ),
                )
              : hasText
              ? IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: onClear,
                  icon: const Icon(AppIcons.close_rounded, size: 18),
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

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState({
    required this.hasQuery,
    required this.onEditSearch,
  });

  final bool hasQuery;
  final VoidCallback onEditSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.search_off_rounded,
              size: 42,
              color: _AuraColors.mutedText,
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'لا توجد نتائج' : 'لا توجد منتجات حاليًا',
              textAlign: TextAlign.center,
              style: _auraText(size: 18, weight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'جرّبي اسمًا أو وصفًا مختلفًا للقطعة.'
                  : 'ستظهر مجموعتنا هنا فور توفرها.',
              textAlign: TextAlign.center,
              style: _auraText(
                size: 13,
                color: _AuraColors.mutedText,
                height: 1.55,
              ),
            ),
            if (hasQuery) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onEditSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _AuraColors.primary,
                  side: const BorderSide(color: _AuraColors.primary),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'تعديل البحث',
                  style: _auraText(size: 12, weight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogPage {
  const _CatalogPage({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;
}

class _AuraColors {
  const _AuraColors._();

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

const _fallbackSwatches = <Color>[
  Color(0xFFEADCC8),
  Color(0xFF4A3428),
  Color(0xFFB88746),
];

TextStyle _auraText({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _AuraColors.text,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
}) {
  return GoogleFonts.cairo(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
    decorationColor: color,
  );
}

String _formatPrice(double value) {
  final decimals = value % 1 == 0 ? 0 : 2;
  return '${value.toStringAsFixed(decimals)} د.ل';
}

int _categoryProductCount(CategoryModel category) {
  return category.productsCount +
      category.children.fold<int>(
        0,
        (total, child) => total + _categoryProductCount(child),
      );
}

Color? _tryParseColor(String value) {
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((character) => '$character$character').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
