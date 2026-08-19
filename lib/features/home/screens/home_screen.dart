import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_banner_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/product_model.dart';
import '../providers/home_provider.dart';
import 'category_explorer_screen.dart';
import 'product_detail_screen.dart';
import '../../addresses/providers/address_provider.dart';
import '../../addresses/screens/address_list_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/auth_required_dialog.dart';
import '../../cart/providers/cart_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/utils/app_notifications.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../../../shared/widgets/app_error_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // جلب البيانات عند بدء الشاشة بنظام الآمُنة عبر تأخير بسيط
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().ensureInitialDataLoaded();
    });
  }

  void _openCategoryExplorer(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  void _openAllProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _HomeSearchResultsScreen(
          initialQuery: '',
          autofocusSearch: false,
        ),
      ),
    );
  }

  CategoryModel? _findCategoryById(List<CategoryModel> categories, int id) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }

      final child = _findCategoryById(category.children, id);
      if (child != null) {
        return child;
      }
    }

    return null;
  }

  void _handleBannerTap(AppBannerItem banner, List<CategoryModel> categories) {
    if (banner.type != 'category' || banner.linkedId == null) {
      return;
    }

    final category = _findCategoryById(categories, banner.linkedId!);
    if (category != null) {
      _openCategoryExplorer(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();

    final hasAnyData =
        homeProvider.categories.isNotEmpty ||
        homeProvider.products.isNotEmpty ||
        homeProvider.ourProducts.isNotEmpty ||
        homeProvider.saleProducts.isNotEmpty ||
        homeProvider.appBanners.isNotEmpty;
    final firstError =
        homeProvider.categoriesError ??
        homeProvider.productsError ??
        homeProvider.ourProductsError ??
        homeProvider.saleProductsError ??
        homeProvider.appBannersError;
    final isAnyLoading =
        homeProvider.isLoadingCategories ||
        homeProvider.isLoadingProducts ||
        homeProvider.isLoadingOurProducts ||
        homeProvider.isLoadingSaleProducts ||
        homeProvider.isLoadingAppBanners;

    // فشل التحميل الأولي بالكامل (لا بيانات + يوجد خطأ) → صفحة خطأ كاملة.
    if (!hasAnyData && firstError != null && !isAnyLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: AppErrorView(
              error: firstError,
              onRetry: () => context
                  .read<HomeProvider>()
                  .ensureInitialDataLoaded(forceRefresh: true),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Premium Header (Replaces the basic padding header)
            const SliverToBoxAdapter(child: _PremiumHomeHeader()),

            // 2. Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16), // مسافة علوية للمحتوى
                    // Featured Banner
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bannerWidth = constraints.maxWidth + 20;
                        final bannerHeight = _ResponsiveBannerConfig.fromWidth(
                          bannerWidth,
                          MediaQuery.devicePixelRatioOf(context),
                        ).height;
                        return SizedBox(
                          height: bannerHeight,
                          child: OverflowBox(
                            minWidth: bannerWidth,
                            maxWidth: bannerWidth,
                            minHeight: bannerHeight,
                            maxHeight: bannerHeight,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: bannerWidth,
                              height: bannerHeight,
                              child: _FeaturedBanner(
                                banners: homeProvider.appBanners,
                                isLoading: homeProvider.isLoadingAppBanners,
                                onBannerTap: (banner) => _handleBannerTap(
                                  banner,
                                  homeProvider.categories,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (homeProvider.isLoadingAppBanners ||
                        homeProvider.appBanners.isNotEmpty)
                      const SizedBox(height: 32),

                    // Categories Title
                    const AilaSectionHeader(title: 'الفئات'),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Categories
            homeProvider.isLoadingCategories
                ? const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 170,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : homeProvider.categoriesError != null
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: AppErrorView(
                        error: homeProvider.categoriesError,
                        compact: true,
                        onRetry: () => context
                            .read<HomeProvider>()
                            .ensureInitialDataLoaded(forceRefresh: true),
                      ),
                    ),
                  )
                : homeProvider.categories.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Center(
                        child: Text(
                          'لا توجد فئات متاحة حالياً',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final railConfig =
                            _ResponsiveCategoryRailConfig.fromWidth(
                              constraints.crossAxisExtent,
                            );

                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: railConfig.height,
                            child: ListView.separated(
                              clipBehavior: Clip.none,
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              itemCount: homeProvider.categories.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(width: railConfig.spacing),
                              itemBuilder: (context, index) {
                                final category = homeProvider.categories[index];
                                return SizedBox(
                                  width: railConfig.itemWidth,
                                  child: _CategoryTile(
                                    label: category.name,
                                    imageUrl: category.imageUrl,
                                    fallbackIcon: _resolveCategoryIcon(
                                      category.slug,
                                      category.name,
                                    ),
                                    count: _categoryTreeCount(category),
                                    onTap: () =>
                                        _openCategoryExplorer(category),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _OffersSliderSection(
                products: homeProvider.saleProducts,
                isLoading: homeProvider.isLoadingSaleProducts,
                hasError: homeProvider.saleProductsError != null,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            // Products Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const AilaSectionHeader(
                  title: 'المنتجات المميزة',
                  subtitle: 'مختارة بعناية لكِ',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Featured products — horizontal rail (AILA / Lovable layout)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
              sliver: homeProvider.isLoadingProducts
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  : homeProvider.productsError != null
                  ? SliverToBoxAdapter(
                      child: AppErrorView(
                        error: homeProvider.productsError,
                        compact: true,
                        onRetry: () => context
                            .read<HomeProvider>()
                            .ensureInitialDataLoaded(forceRefresh: true),
                      ),
                    )
                  : homeProvider.products.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(child: Text('لا توجد منتجات مميزة حالياً')),
                    )
                  : SliverToBoxAdapter(
                      child: SizedBox(
                        height: 286,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: homeProvider.products.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (ctx, i) {
                            final product = homeProvider.products[i];
                            return SizedBox(
                              width: 172,
                              child: _ProductCard(product: product, index: i),
                            );
                          },
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AilaSectionHeader(
                  title: 'منتجاتنا',
                  actionLabel: 'عرض الكل',
                  onAction: _openAllProducts,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: homeProvider.isLoadingOurProducts
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  : homeProvider.ourProductsError != null
                  ? SliverToBoxAdapter(
                      child: AppErrorView(
                        error: homeProvider.ourProductsError,
                        compact: true,
                        onRetry: () => context
                            .read<HomeProvider>()
                            .ensureInitialDataLoaded(forceRefresh: true),
                      ),
                    )
                  : homeProvider.ourProducts.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(child: Text('لا توجد منتجات حالياً')),
                    )
                  : SliverGrid(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final product = homeProvider.ourProducts[i];
                        return _ProductCard(product: product, index: i);
                      }, childCount: homeProvider.ourProducts.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Featured Banner ---
class _FeaturedBanner extends StatefulWidget {
  final List<AppBannerItem> banners;
  final bool isLoading;
  final ValueChanged<AppBannerItem> onBannerTap;

  const _FeaturedBanner({
    required this.banners,
    required this.onBannerTap,
    this.isLoading = false,
  });

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _FeaturedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.banners.length && widget.banners.isNotEmpty) {
      _currentPage = widget.banners.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const _AdvertisementSliderSkeleton();
    }

    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final config = _ResponsiveBannerConfig.fromWidth(
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );

        return Column(
          children: [
            SizedBox(
              height: config.height,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: widget.banners.length,
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return _AnimatedBannerScale(
                    pageController: _pageController,
                    itemIndex: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () => widget.onBannerTap(banner),
                        child: _AdvertisementSlideCard(
                          banner: banner,
                          imageUrl: banner.imageUrlForWidth(
                            constraints.maxWidth,
                          ),
                          index: index,
                          total: widget.banners.length,
                          borderRadius: config.borderRadius,
                          cacheWidth: config.cacheWidth,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResponsiveBannerConfig {
  const _ResponsiveBannerConfig({
    required this.height,
    required this.borderRadius,
    required this.cacheWidth,
  });

  final double height;
  final double borderRadius;
  final int cacheWidth;

  factory _ResponsiveBannerConfig.fromWidth(
    double availableWidth,
    double devicePixelRatio,
  ) {
    final width = availableWidth.isFinite ? availableWidth : 360.0;
    // Taller, hero-style proportions (mirrors the AILA / Lovable hero).
    final aspectRatio = switch (width) {
      < 600 => 1.03,
      < 900 => 1.55,
      _ => 2.0,
    };
    final viewportWidth = width;
    final height = (viewportWidth / aspectRatio).clamp(330.0, 455.0);
    final cacheWidth = (viewportWidth * devicePixelRatio)
        .round()
        .clamp(420, 1800)
        .toInt();

    return _ResponsiveBannerConfig(
      height: height,
      borderRadius: width < 600 ? 34 : 36,
      cacheWidth: cacheWidth,
    );
  }
}

/// AILA hero slide — tall rounded image card with a dark scrim, inner hairline
/// border, slide counter, and an overlaid title + CTA (mirrors the Lovable hero).
class _AdvertisementSlideCard extends StatelessWidget {
  final AppBannerItem banner;
  final String? imageUrl;
  final int index;
  final int total;
  final double borderRadius;
  final int cacheWidth;

  const _AdvertisementSlideCard({
    required this.banner,
    required this.imageUrl,
    required this.index,
    required this.total,
    required this.borderRadius,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final title = banner.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final subtitle = banner.subtitle?.trim();
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    final badgeText = banner.badgeText?.trim();
    final hasBadge = badgeText != null && badgeText.isNotEmpty;
    final actionLabel = switch (banner.type) {
      'category' when banner.linkedId != null =>
        banner.ctaText?.trim().isNotEmpty == true
            ? banner.ctaText!.trim()
            : 'تصفّح القسم',
      _ => null,
    };
    final hasOverlayContent = hasTitle || hasSubtitle || actionLabel != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B5A2E36),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.blushGradient,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.blushGradient,
                      ),
                    ),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.blushGradient),
              ),
            if (hasOverlayContent) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x16000000),
                      Colors.transparent,
                      Color(0xB8251015),
                    ],
                    stops: [0.0, 0.48, 1.0],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x713D171E), Colors.transparent],
                    stops: [0.0, 0.72],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(13),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    (borderRadius - 13).clamp(0, borderRadius),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
            if (hasBadge)
              PositionedDirectional(
                top: 28,
                start: 28,
                child: _HeroBannerChip(
                  child: Text(
                    badgeText.toUpperCase(),
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (total > 1)
              PositionedDirectional(
                top: 28,
                end: 28,
                child: _HeroBannerChip(
                  child: Text(
                    '${(index + 1).toString().padLeft(2, '0')} / '
                    '${total.toString().padLeft(2, '0')}',
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (hasOverlayContent)
              PositionedDirectional(
                start: 28,
                end: 28,
                bottom: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTitle)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.22,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    if (hasTitle && hasSubtitle) const SizedBox(height: 7),
                    if (hasSubtitle)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.42,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    if ((hasTitle || hasSubtitle) && actionLabel != null)
                      const SizedBox(height: 18),
                    if (actionLabel != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 16,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              actionLabel,
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: AppColors.mauve,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (total > 1)
              PositionedDirectional(
                end: 26,
                bottom: 18,
                child: _AdvertisementDots(
                  itemCount: total,
                  currentIndex: index,
                  onImage: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroBannerChip extends StatelessWidget {
  final Widget child;

  const _HeroBannerChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }
}

class _AdvertisementDots extends StatelessWidget {
  final int itemCount;
  final int currentIndex;
  final bool onImage;

  const _AdvertisementDots({
    required this.itemCount,
    required this.currentIndex,
    this.onImage = false,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: currentIndex == index ? 22 : 7,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: currentIndex == index
                ? (onImage ? Colors.white : AppColors.primary)
                : (onImage
                      ? Colors.white.withValues(alpha: 0.38)
                      : AppColors.primary.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _AdvertisementSliderSkeleton extends StatelessWidget {
  const _AdvertisementSliderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 268,
      decoration: BoxDecoration(
        gradient: AppColors.blushGradient,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFEFE3E6)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.6,
        ),
      ),
    );
  }
}

class _AnimatedBannerScale extends StatelessWidget {
  final PageController pageController;
  final int itemIndex;
  final Widget child;

  const _AnimatedBannerScale({
    required this.pageController,
    required this.itemIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      child: child,
      builder: (context, child) {
        final currentPage =
            pageController.hasClients && pageController.position.haveDimensions
            ? (pageController.page ?? pageController.initialPage.toDouble())
            : pageController.initialPage.toDouble();
        final distance = (currentPage - itemIndex).abs();
        final scale = (1 - (distance * 0.04)).clamp(0.93, 1.0);

        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class _ResponsiveCategoryRailConfig {
  const _ResponsiveCategoryRailConfig({
    required this.height,
    required this.itemWidth,
    required this.spacing,
  });

  final double height;
  final double itemWidth;
  final double spacing;

  factory _ResponsiveCategoryRailConfig.fromWidth(double availableWidth) {
    final width = availableWidth.isFinite ? availableWidth : 320.0;

    if (width < 300) {
      return const _ResponsiveCategoryRailConfig(
        height: 144,
        itemWidth: 104,
        spacing: 12,
      );
    }
    if (width < 560) {
      return const _ResponsiveCategoryRailConfig(
        height: 152,
        itemWidth: 112,
        spacing: 14,
      );
    }
    if (width < 760) {
      return const _ResponsiveCategoryRailConfig(
        height: 160,
        itemWidth: 118,
        spacing: 14,
      );
    }
    if (width < 1040) {
      return const _ResponsiveCategoryRailConfig(
        height: 166,
        itemWidth: 124,
        spacing: 16,
      );
    }

    return const _ResponsiveCategoryRailConfig(
      height: 170,
      itemWidth: 130,
      spacing: 16,
    );
  }
}

// --- Category Tile ---
/// AILA category tile — a tall image card with a dark gradient scrim and the
/// category name + product count overlaid (mirrors the Lovable web design).
class _CategoryTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final IconData fallbackIcon;
  final int count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final cacheWidth = (150 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(180, 520)
        .toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppColors.blush,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _CategoryFallbackArt(icon: fallbackIcon),
                )
              else
                _CategoryFallbackArt(icon: fallbackIcon),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x26000000),
                      Color(0x8F000000),
                    ],
                    stops: [0.34, 0.62, 1.0],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 11,
                end: 11,
                bottom: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count منتج',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.1,
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

class _CategoryFallbackArt extends StatelessWidget {
  final IconData icon;

  const _CategoryFallbackArt({required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.blushGradient),
      child: Center(child: Icon(icon, size: 34, color: AppColors.roseGold)),
    );
  }
}

/// Total products in a category including its sub-categories.
int _categoryTreeCount(CategoryModel category) {
  return category.productsCount +
      category.children.fold<int>(
        0,
        (total, child) => total + _categoryTreeCount(child),
      );
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

class _ProductCardVariantPreview {
  final int variantId;
  final String? imageUrl;
  final double price;
  final int maxQuantity;
  final bool isAvailable;

  const _ProductCardVariantPreview({
    required this.variantId,
    required this.imageUrl,
    required this.price,
    required this.maxQuantity,
    required this.isAvailable,
  });
}

final Map<String, Map<String, _ProductCardVariantPreview>>
_productCardVariantPreviewCache =
    <String, Map<String, _ProductCardVariantPreview>>{};
final Map<String, Future<Map<String, _ProductCardVariantPreview>>>
_productCardVariantPreviewFutureCache =
    <String, Future<Map<String, _ProductCardVariantPreview>>>{};

String _normalizeProductCardColorKey(String value) =>
    value.trim().toLowerCase();

String? _normalizeProductCardImageUrl(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

Color? _parseProductCardColorValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  switch (lower) {
    case 'black':
    case 'أسود':
    case 'اسود':
      return Colors.black;
    case 'white':
    case 'أبيض':
    case 'ابيض':
      return Colors.white;
    case 'red':
    case 'أحمر':
    case 'احمر':
      return Colors.red;
    case 'green':
    case 'أخضر':
    case 'اخضر':
      return Colors.green;
    case 'blue':
    case 'أزرق':
    case 'ازرق':
      return Colors.blue;
    case 'yellow':
    case 'أصفر':
    case 'اصفر':
      return Colors.yellow;
    case 'orange':
    case 'برتقالي':
      return Colors.orange;
    case 'purple':
    case 'بنفسجي':
      return Colors.purple;
    case 'pink':
    case 'وردي':
      return Colors.pink;
    case 'brown':
    case 'بني':
      return Colors.brown;
    case 'grey':
    case 'gray':
    case 'رمادي':
      return Colors.grey;
    case 'silver':
    case 'فضي':
      return const Color(0xFFC0C0C0);
    case 'gold':
    case 'ذهبي':
      return const Color(0xFFFFD700);
    case 'navy':
    case 'كحلي':
      return const Color(0xFF8E4A54);
  }

  final hexPattern = RegExp(
    r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  );
  if (!hexPattern.hasMatch(normalized)) {
    return null;
  }

  var hex = normalized.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((char) => '$char$char').join();
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  return Color(int.parse(hex, radix: 16));
}

String _displayProductCardColorLabel(String value) {
  final lower = value.trim().toLowerCase();
  switch (lower) {
    case '#000000':
    case 'black':
    case 'أسود':
    case 'اسود':
      return 'أسود';
    case '#ffffff':
    case 'white':
    case 'أبيض':
    case 'ابيض':
      return 'أبيض';
    case '#ff0000':
    case 'red':
    case 'أحمر':
    case 'احمر':
      return 'أحمر';
    case '#00ff00':
    case 'green':
    case 'أخضر':
    case 'اخضر':
      return 'أخضر';
    case '#0000ff':
    case 'blue':
    case 'أزرق':
    case 'ازرق':
      return 'أزرق';
    case '#ffff00':
    case 'yellow':
    case 'أصفر':
    case 'اصفر':
      return 'أصفر';
    case 'orange':
    case 'برتقالي':
      return 'برتقالي';
    case 'purple':
    case 'بنفسجي':
      return 'بنفسجي';
    case 'pink':
    case 'وردي':
      return 'وردي';
    case 'brown':
    case 'بني':
      return 'بني';
    case 'grey':
    case 'gray':
    case 'رمادي':
      return 'رمادي';
    case 'silver':
    case 'فضي':
      return 'فضي';
    case 'gold':
    case 'ذهبي':
      return 'ذهبي';
    case 'navy':
    case 'كحلي':
      return 'كحلي';
    default:
      return value.trim();
  }
}

class _ProductCardController extends ChangeNotifier {
  final String slug;
  String? _baseImageUrl;
  double _basePrice;
  List<String> _availableColors;
  String? _selectedColorValue;
  String? _selectedImageUrl;
  double? _selectedPrice;
  bool _isLoading = false;

  _ProductCardController._({
    required this.slug,
    required String? baseImageUrl,
    required double basePrice,
    required List<String> availableColors,
  }) : _baseImageUrl = _normalizeProductCardImageUrl(baseImageUrl),
       _basePrice = basePrice,
       _availableColors = List<String>.from(availableColors) {
    _selectedColorValue = null;
    _selectedImageUrl = _baseImageUrl;
    _selectedPrice = _basePrice;
    _applyCachedPreview();
  }

  static final Map<String, _ProductCardController> _instances =
      <String, _ProductCardController>{};

  static _ProductCardController instance({
    required ProductModel product,
    required String? baseImageUrl,
    required double basePrice,
    required List<String> availableColors,
  }) {
    final controller = _instances.putIfAbsent(
      product.slug,
      () => _ProductCardController._(
        slug: product.slug,
        baseImageUrl: baseImageUrl,
        basePrice: basePrice,
        availableColors: availableColors,
      ),
    );
    controller._sync(
      baseImageUrl: baseImageUrl,
      basePrice: basePrice,
      availableColors: availableColors,
    );
    return controller;
  }

  String? get selectedColorValue => _selectedColorValue;
  String? get selectedImageUrl => _selectedImageUrl;
  double? get selectedPrice => _selectedPrice;
  bool get isLoading => _isLoading;

  _ProductCardVariantPreview? get selectedVariantPreview {
    final colorValue = _selectedColorValue;
    if (colorValue == null) {
      return null;
    }
    return _lookupCachedPreview(colorValue);
  }

  void _sync({
    required String? baseImageUrl,
    required double basePrice,
    required List<String> availableColors,
  }) {
    _baseImageUrl = _normalizeProductCardImageUrl(baseImageUrl);
    _basePrice = basePrice;
    _availableColors = List<String>.from(availableColors);

    if (_selectedColorValue != null &&
        !_availableColors.any(
          (item) =>
              _normalizeProductCardColorKey(item) ==
              _normalizeProductCardColorKey(_selectedColorValue!),
        )) {
      _selectedColorValue = null;
      _selectedImageUrl = _baseImageUrl;
      _selectedPrice = _basePrice;
    }

    _applyCachedPreview();
  }

  _ProductCardVariantPreview? _lookupCachedPreview(String colorValue) {
    final previews = _productCardVariantPreviewCache[slug];
    if (previews == null) {
      return null;
    }
    return previews[_normalizeProductCardColorKey(colorValue)];
  }

  void _applyCachedPreview() {
    final preview = _selectedColorValue == null
        ? null
        : _lookupCachedPreview(_selectedColorValue!);
    _selectedImageUrl = preview?.imageUrl ?? _baseImageUrl;
    _selectedPrice = preview?.price ?? _basePrice;
  }

  Future<void> selectColor(
    BuildContext context,
    ProductModel product,
    String colorValue,
  ) async {
    final normalizedSelection = _normalizeProductCardColorKey(colorValue);
    final currentNormalized = _selectedColorValue == null
        ? null
        : _normalizeProductCardColorKey(_selectedColorValue!);

    if (normalizedSelection != currentNormalized) {
      _selectedColorValue = colorValue;
      _applyCachedPreview();
      notifyListeners();
    }

    if (_lookupCachedPreview(colorValue) != null ||
        _availableColors.length <= 1) {
      return;
    }

    if (_isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _loadVariantPreviews(context, product);
      _applyCachedPreview();
    } catch (_) {
      _selectedImageUrl = _baseImageUrl;
      _selectedPrice = _basePrice;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVariantPreviews(
    BuildContext context,
    ProductModel product,
  ) async {
    final cachedPreviews = _productCardVariantPreviewCache[slug];
    if (cachedPreviews != null) {
      return;
    }

    final pendingFuture = _productCardVariantPreviewFutureCache[slug];
    if (pendingFuture != null) {
      await pendingFuture;
      return;
    }

    final future = _fetchVariantPreviews(context, product);
    _productCardVariantPreviewFutureCache[slug] = future;

    try {
      final previews = await future;
      _productCardVariantPreviewCache[slug] = previews;
    } finally {
      _productCardVariantPreviewFutureCache.remove(slug);
    }
  }

  Future<Map<String, _ProductCardVariantPreview>> _fetchVariantPreviews(
    BuildContext context,
    ProductModel product,
  ) async {
    final details = await context
        .read<HomeProvider>()
        .repository
        .fetchProductDetails(product.slug);
    final previews = <String, _ProductCardVariantPreview>{};

    for (final variant in details.variants ?? const <VariantModel>[]) {
      if (variant.type.trim().toLowerCase() != 'color') {
        continue;
      }

      previews[_normalizeProductCardColorKey(
        variant.value,
      )] = _ProductCardVariantPreview(
        variantId: variant.id,
        imageUrl: _normalizeProductCardImageUrl(variant.imageUrl),
        price: variant.finalPrice,
        maxQuantity: variant.maxPurchasableQuantity,
        isAvailable: variant.isAvailable,
      );
    }

    return previews;
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final int index;

  const _ProductCard({required this.product, required this.index});

  // حذف قائمة _products الثابتة التي كانت هنا

  @override
  Widget build(BuildContext context) {
    final baseThumbnailUrl = _normalizeProductCardImageUrl(product.thumbnail);
    final colorValues = _extractColorValues();
    final controller = _ProductCardController.instance(
      product: product,
      baseImageUrl: baseThumbnailUrl,
      basePrice: product.pricing.effectivePrice,
      availableColors: colorValues,
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final thumbnailUrl = controller.selectedImageUrl ?? baseThumbnailUrl;
        final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
        final effectivePrice =
            controller.selectedPrice ?? product.pricing.effectivePrice;
        final selectedVariantPreview = controller.selectedVariantPreview;
        final requiresVariantSelection = product.hasPendingVariantStock;
        final maxQuantity =
            selectedVariantPreview?.maxQuantity ??
            (requiresVariantSelection ? 0 : product.maxPurchasableQuantity);
        final isAvailable =
            product.stock.isAvailable &&
            (selectedVariantPreview?.isAvailable ??
                (!requiresVariantSelection && product.isPurchasable));
        final showUnavailableBadge =
            !product.stock.isAvailable ||
            selectedVariantPreview?.isAvailable == false ||
            (!requiresVariantSelection && !product.isPurchasable);
        final canAddToCart = isAvailable && !controller.isLoading;
        final productBadgeLabel = product.pricing.isOnSale
            ? '-${product.pricing.discountPercentage.toStringAsFixed(0)}%'
            : (product.isFeatured ? 'LIMITED' : null);
        final eyebrowRaw = (product.category?.name ?? product.brand?.name)
            ?.trim();
        final eyebrowLabel = (eyebrowRaw != null && eyebrowRaw.isNotEmpty)
            ? eyebrowRaw.toUpperCase()
            : null;
        final imageCacheWidth =
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context) /
                    2)
                .round()
                .clamp(420, 900);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
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
                    decoration: BoxDecoration(
                      color: AppColors.blush,
                      borderRadius: const BorderRadius.vertical(
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
                                    thumbnailUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: imageCacheWidth,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const _ProductImagePlaceholder(
                                              icon: AppIcons.image_outlined,
                                            ),
                                  ),
                                )
                              : const _ProductImagePlaceholder(
                                  icon: AppIcons.computer_rounded,
                                ),
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
                        if (showUnavailableBadge)
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
                        // Badges (Top right and left)
                        Positioned(
                          top: 14,
                          right: 14,
                          left: 14,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (productBadgeLabel != null)
                                    _GlassTag(label: productBadgeLabel),
                                ],
                              ),

                              // Favorite Button
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
                                        color: isFav
                                            ? AppColors.roseGold
                                            : AppColors.roseGold,
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
                        (product.shortDescription?.trim().isNotEmpty ?? false)
                            ? product.shortDescription!.trim()
                            : (product.brand?.name ?? 'Soft Glow Finish'),
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
                      const SizedBox(height: 7),
                      if (colorValues.isNotEmpty) ...[
                        _InteractiveProductColorPreviewRow(
                          colorValues: colorValues,
                          selectedColorValue: controller.selectedColorValue,
                          isLoading: controller.isLoading,
                          onColorTap: (colorValue) => controller.selectColor(
                            context,
                            product,
                            colorValue,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                            onTap: controller.isLoading
                                ? null
                                : () {
                                    if (!canAddToCart) {
                                      AppNotifications.showError(
                                        context,
                                        selectedVariantPreview == null &&
                                                requiresVariantSelection
                                            ? 'يرجى اختيار اللون المتوفر أولاً'
                                            : 'المنتج غير متوفر حالياً',
                                      );
                                      return;
                                    }
                                    final result = context
                                        .read<CartProvider>()
                                        .addItem(
                                          CartItem(
                                            id: CartItem.buildId(
                                              productId: product.id,
                                              productVariantId:
                                                  selectedVariantPreview
                                                      ?.variantId,
                                              variantKey:
                                                  controller.selectedColorValue,
                                            ),
                                            productId: product.id,
                                            productVariantId:
                                                selectedVariantPreview
                                                    ?.variantId,
                                            name: product.name,
                                            variantInfo:
                                                controller.selectedColorValue ==
                                                    null
                                                ? null
                                                : 'اللون: ${_displayProductCardColorLabel(controller.selectedColorValue!)}',
                                            price: effectivePrice,
                                            imageUrl: thumbnailUrl ?? '',
                                            maxQuantity: maxQuantity,
                                            isAvailable: isAvailable,
                                            quantity: 1,
                                          ),
                                        );
                                    if (!result.didChange) {
                                      AppNotifications.showError(
                                        context,
                                        result.isLimitReached
                                            ? 'الكمية المتاحة حالياً ${result.maxQuantity ?? maxQuantity} فقط'
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
                                gradient: canAddToCart
                                    ? AppColors.roseGradient
                                    : null,
                                color: canAddToCart
                                    ? null
                                    : const Color(0xFFDAC7CB),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (canAddToCart
                                                ? AppColors.roseGold
                                                : const Color(0xFF8B6F73))
                                            .withValues(alpha: 0.32),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: controller.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
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
        );
      },
    );
  }

  List<String> _extractColorValues() {
    final values = <String>[];
    for (final color in product.options?.colors ?? const <String>[]) {
      final normalized = color.trim();
      if (normalized.isEmpty || values.contains(normalized)) {
        continue;
      }
      values.add(normalized);
    }
    return values;
  }
}

/// Frosted white pill tag used on Lovable-style product cards.
class _GlassTag extends StatelessWidget {
  final String label;

  const _GlassTag({required this.label});

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

class _ProductImagePlaceholder extends StatelessWidget {
  final IconData icon;

  const _ProductImagePlaceholder({required this.icon});

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
        child: Icon(icon, size: 44, color: AppColors.primary),
      ),
    );
  }
}

// ignore: unused_element
class _ProductColorPreviewRow extends StatelessWidget {
  final List<String> colorValues;

  const _ProductColorPreviewRow({required this.colorValues});

  Color? _parseColorValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lower = normalized.toLowerCase();
    switch (lower) {
      case 'black':
      case 'أسود':
      case 'اسود':
        return Colors.black;
      case 'white':
      case 'أبيض':
      case 'ابيض':
        return Colors.white;
      case 'red':
      case 'أحمر':
      case 'احمر':
        return Colors.red;
      case 'green':
      case 'أخضر':
      case 'اخضر':
        return Colors.green;
      case 'blue':
      case 'أزرق':
      case 'ازرق':
        return Colors.blue;
      case 'yellow':
      case 'أصفر':
      case 'اصفر':
        return Colors.yellow;
      case 'orange':
      case 'برتقالي':
        return Colors.orange;
      case 'purple':
      case 'بنفسجي':
        return Colors.purple;
      case 'pink':
      case 'وردي':
        return Colors.pink;
      case 'brown':
      case 'بني':
        return Colors.brown;
      case 'grey':
      case 'gray':
      case 'رمادي':
        return Colors.grey;
      case 'silver':
      case 'فضي':
        return const Color(0xFFC0C0C0);
      case 'gold':
      case 'ذهبي':
        return const Color(0xFFFFD700);
      case 'navy':
      case 'كحلي':
        return const Color(0xFF8E4A54);
    }

    final hexPattern = RegExp(
      r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    );
    if (!hexPattern.hasMatch(normalized)) {
      return null;
    }

    var hex = normalized.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final visibleColors = colorValues.take(4).toList();
    final remainingCount = colorValues.length - visibleColors.length;

    return Row(
      children: [
        Text(
          'الألوان',
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        ...visibleColors.map((colorValue) {
          final color = _parseColorValue(colorValue);
          final borderColor = color == null || color.computeLuminance() > 0.88
              ? AppColors.divider
              : Colors.white;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Tooltip(
              message: colorValue,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color ?? AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: color == null
                    ? Icon(
                        AppIcons.palette_outlined,
                        size: 10,
                        color: AppColors.textHint,
                      )
                    : null,
              ),
            ),
          );
        }),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '+$remainingCount',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _InteractiveProductColorPreviewRow extends StatelessWidget {
  final List<String> colorValues;
  final String? selectedColorValue;
  final bool isLoading;
  final ValueChanged<String> onColorTap;

  const _InteractiveProductColorPreviewRow({
    required this.colorValues,
    required this.selectedColorValue,
    required this.isLoading,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleColors = colorValues.take(4).toList();
    final remainingCount = colorValues.length - visibleColors.length;

    return Row(
      children: [
        Text(
          'الألوان',
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        ...visibleColors.map((colorValue) {
          final color = _parseProductCardColorValue(colorValue);
          final borderColor = color == null || color.computeLuminance() > 0.88
              ? AppColors.divider
              : Colors.white;
          final isSelected =
              selectedColorValue != null &&
              _normalizeProductCardColorKey(selectedColorValue!) ==
                  _normalizeProductCardColorKey(colorValue);

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Tooltip(
              message: _displayProductCardColorLabel(colorValue),
              child: GestureDetector(
                onTap: () => onColorTap(colorValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 20 : 16,
                  height: isSelected ? 20 : 16,
                  decoration: BoxDecoration(
                    color: color ?? AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isSelected ? 0.12 : 0.06,
                        ),
                        blurRadius: isSelected ? 10 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: color == null
                      ? Icon(
                          AppIcons.palette_outlined,
                          size: isSelected ? 12 : 10,
                          color: AppColors.textHint,
                        )
                      : null,
                ),
              ),
            ),
          );
        }),
        if (isLoading)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '+$remainingCount',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _OffersSliderSection extends StatefulWidget {
  final List<ProductModel> products;
  final bool isLoading;
  final bool hasError;

  const _OffersSliderSection({
    required this.products,
    required this.isLoading,
    required this.hasError,
  });

  @override
  State<_OffersSliderSection> createState() => _OffersSliderSectionState();
}

class _OffersSliderSectionState extends State<_OffersSliderSection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
  }

  @override
  void didUpdateWidget(covariant _OffersSliderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.products.length && widget.products.isNotEmpty) {
      _currentPage = widget.products.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError || (!widget.isLoading && widget.products.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عروض مختارة لك',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أفضل التخفيضات المتاحة الآن',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    '${widget.products.length} عرض',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (widget.isLoading)
          const _OfferSliderSkeleton()
        else ...[
          SizedBox(
            height: 226,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                return _AnimatedOfferSlideScale(
                  pageController: _pageController,
                  itemIndex: index,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                    child: _OfferCard(product: widget.products[index]),
                  ),
                );
              },
            ),
          ),
          if (widget.products.length > 1) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.products.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: _currentPage == index ? 26 : 8,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _OfferSliderSkeleton extends StatelessWidget {
  const _OfferSliderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 214,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEFE3E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.6,
          ),
        ),
      ),
    );
  }
}

class _AnimatedOfferSlideScale extends StatelessWidget {
  final PageController pageController;
  final int itemIndex;
  final Widget child;

  const _AnimatedOfferSlideScale({
    required this.pageController,
    required this.itemIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      child: child,
      builder: (context, child) {
        final currentPage =
            pageController.hasClients && pageController.position.haveDimensions
            ? (pageController.page ?? pageController.initialPage.toDouble())
            : pageController.initialPage.toDouble();
        final distance = (currentPage - itemIndex).abs();
        final scale = (1 - (distance * 0.045)).clamp(0.92, 1.0);
        final opacity = (1 - (distance * 0.18)).clamp(0.72, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

// --- Offer Card ---
class _OfferCard extends StatelessWidget {
  final ProductModel product;
  const _OfferCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final discountPercentage = product.pricing.discountPercentage;
    final hasDiscount = product.pricing.isOnSale && discountPercentage > 0;
    final hasImage = product.thumbnail != null && product.thumbnail!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  product.thumbnail!,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (ctx, err, st) =>
                      _OfferCardFallbackImage(hasDiscount: hasDiscount),
                )
              else
                _OfferCardFallbackImage(hasDiscount: hasDiscount),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.82),
                      Colors.black.withValues(alpha: 0.44),
                      Colors.black.withValues(alpha: 0.06),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              PositionedDirectional(
                top: 16,
                start: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFD5C63),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFD5C63).withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.local_offer_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasDiscount ? 'خصم $discountPercentage%' : 'عرض خاص',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 18,
                end: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${product.pricing.effectivePrice.toStringAsFixed(2)} د.ل',
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${product.pricing.price.toStringAsFixed(2)} د.ل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHint,
                                    decoration: TextDecoration.lineThrough,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            AppIcons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
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

class _OfferCardFallbackImage extends StatelessWidget {
  final bool hasDiscount;

  const _OfferCardFallbackImage({required this.hasDiscount});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasDiscount
              ? const [Color(0xFFB76E79), Color(0xFFD98A9A)]
              : const [Color(0xFFB76E79), Color(0xFFD98A9A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          AppIcons.local_offer_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _PremiumHomeHeader extends StatefulWidget {
  const _PremiumHomeHeader();

  @override
  State<_PremiumHomeHeader> createState() => _PremiumHomeHeaderState();
}

class _PremiumHomeHeaderState extends State<_PremiumHomeHeader> {
  final TextEditingController _searchController = TextEditingController();
  bool _isOpeningSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(context.read<AddressProvider>().loadAddresses());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSearchResults({
    String? query,
    bool showEmptyError = true,
  }) async {
    if (_isOpeningSearch) {
      return;
    }

    final searchQuery = (query ?? _searchController.text).trim();
    if (searchQuery.isEmpty) {
      if (showEmptyError) {
        AppNotifications.showError(context, 'اكتب اسم المنتج أولاً');
      }
      return;
    }

    _isOpeningSearch = true;
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _HomeSearchResultsScreen(
          initialQuery: searchQuery,
          autofocusSearch: true,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _searchController.clear();
    _isOpeningSearch = false;
  }

  Future<void> _handleAvatarTap() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      context.read<AppShellController>().setIndex(
        AppShellController.profileIndex,
      );
      return;
    }

    // ضيف بلا حساب: اطلب تسجيل الدخول بدل فتح البروفايل مباشرة.
    final action = await showAuthRequiredDialog(
      context,
      badge: 'هذه الصفحة تحتاج حساباً',
      title: 'سجّل دخولك للوصول إلى حسابك',
      message:
          'صفحة حسابك تحتوي على طلباتك وعناوينك وبياناتك الشخصية، '
          'لذلك نحتاج إلى تسجيل الدخول قبل فتحها.',
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

    context.read<AppShellController>().setIndex(
      AppShellController.profileIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting + wordmark · bell · avatar (AILA / Lovable header) ──
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final name = auth.user?.name.trim();
              final hasName = name != null && name.isNotEmpty;
              final firstName = hasName
                  ? name.split(RegExp(r'\s+')).first
                  : null;
              final greeting = firstName != null
                  ? 'أهلاً، $firstName'
                  : 'أهلاً بكِ';
              final initial = hasName
                  ? name.characters.first.toUpperCase()
                  : 'A';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.taupe,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Image.asset(
                              'assets/images/splash_page.png',
                              height: 38,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerRight,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _HeaderBellButton(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeaderAvatarButton(
                        initial: initial,
                        isAuthenticated: auth.isAuthenticated,
                        onTap: _handleAvatarTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (auth.isAuthenticated)
                    _HeaderDeliveryRow(
                      walletBalance: auth.user?.walletBalance ?? 0,
                    )
                  else
                    _HeaderGuestBar(onTap: _handleAvatarTap),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Search field ──
          Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF7E7EA),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFB76E79,
                          ).withValues(alpha: 0.07),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => _openSearchResults(
                        query: value,
                        showEmptyError: false,
                      ),
                      onSubmitted: (_) => _openSearchResults(),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'ما الذي تبحث عنه اليوم؟',
                        hintStyle: GoogleFonts.cairo(
                          color: AppColors.textHint.withValues(alpha: 0.86),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        suffixIcon: Container(
                          width: 46,
                          height: 46,
                          margin: const EdgeInsetsDirectional.only(
                            start: 8,
                            end: 7,
                            top: 7,
                            bottom: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight.withValues(alpha: 0.18),
                                AppColors.primary.withValues(alpha: 0.12),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: IconButton(
                            onPressed: _openSearchResults,
                            splashRadius: 20,
                            icon: const Icon(
                              AppIcons.search_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 60,
                          minHeight: 60,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Delivery address selector + wallet balance chip merged into the AILA header.
class _HeaderDeliveryRow extends StatelessWidget {
  final double walletBalance;

  const _HeaderDeliveryRow({required this.walletBalance});

  String _resolveAddressTitle(AddressProvider provider) {
    final address = provider.defaultAddress;
    final label = address?.label.trim() ?? '';
    if (label.isNotEmpty) return label;
    final formatted = address?.formattedAddress.trim() ?? '';
    if (formatted.isNotEmpty) return formatted;
    if (provider.isLoadingAddresses) return 'جاري تحميل العنوان...';
    return 'اختر عنوانك الافتراضي';
  }

  @override
  Widget build(BuildContext context) {
    final addressProvider = context.watch<AddressProvider>();
    final title = _resolveAddressTitle(addressProvider);

    return Row(
      children: [
        // Address selector
        Expanded(
          child: _HeaderPill(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddressListScreen()),
              );
              if (!context.mounted) return;
              unawaited(
                context.read<AddressProvider>().loadAddresses(
                  forceRefresh: true,
                ),
              );
            },
            icon: AppIcons.location_on_rounded,
            label: 'التوصيل إلى',
            value: title,
            valueColor: AppColors.mauve,
          ),
        ),
        const SizedBox(width: 10),
        // Wallet chip
        _HeaderPill(
          expand: false,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
          icon: AppIcons.account_balance_wallet_outlined,
          label: 'محفظتي',
          value: '${walletBalance.toStringAsFixed(2)} د.ل',
          valueColor: AppColors.roseGold,
        ),
      ],
    );
  }
}

/// Slim pill used inside the header delivery row (icon + small label + value).
class _HeaderPill extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool expand;

  const _HeaderPill({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.blush,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: AppColors.roseGold),
              ),
              const SizedBox(width: 8),
              expand ? Expanded(child: _pillText()) : _pillText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.taupe,
            height: 1.1,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Guest affordance shown in the header when not signed in.
class _HeaderGuestBar extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderGuestBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.blush,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.person_outline_rounded,
                  size: 16,
                  color: AppColors.roseGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'سجّلي الدخول للتوصيل والمحفظة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mauve,
                  ),
                ),
              ),
              const Icon(
                AppIcons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.taupe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular white notification bell with a rose-pink unread dot (AILA header).
class _HeaderBellButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBellButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                AppIcons.notifications_none_rounded,
                color: AppColors.mauve,
                size: 22,
              ),
              PositionedDirectional(
                top: 11,
                end: 12,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.rosePink,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
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

/// Rose-gradient avatar with initial (or photo) and an online dot (AILA header).
class _HeaderAvatarButton extends StatelessWidget {
  final String initial;
  final bool isAuthenticated;
  final VoidCallback onTap;

  const _HeaderAvatarButton({
    required this.initial,
    required this.isAuthenticated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: isAuthenticated
                ? Text(
                    initial,
                    style: GoogleFonts.cairo(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    AppIcons.person_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          if (isAuthenticated)
            PositionedDirectional(
              bottom: -1,
              end: -1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeSearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  final bool autofocusSearch;

  const _HomeSearchResultsScreen({
    required this.initialQuery,
    this.autofocusSearch = false,
  });

  @override
  State<_HomeSearchResultsScreen> createState() =>
      _HomeSearchResultsScreenState();
}

class _HomeSearchResultsScreenState extends State<_HomeSearchResultsScreen> {
  static const int _productsPerPage = 20;

  late final TextEditingController _searchController;
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
    _activeQuery = widget.initialQuery.trim();
    _searchController = TextEditingController(text: _activeQuery)
      ..selection = TextSelection.collapsed(offset: _activeQuery.length);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSearch(_activeQuery, unfocus: false);
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

  void _handleSearchTextChanged(String value) {
    _searchDebounce?.cancel();
    _requestVersion++;
    final query = value.trim();

    setState(() {
      _error = null;
    });

    if (query.isEmpty) {
      _requestVersion++;
      setState(() {
        _activeQuery = '';
      });
      _searchDebounce = Timer(const Duration(milliseconds: 260), () {
        _runSearch('', unfocus: false);
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(query, unfocus: false);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).requestFocus(_searchFocusNode);
    _handleSearchTextChanged('');
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 320;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _runSearch(String rawQuery, {bool unfocus = true}) async {
    _searchDebounce?.cancel();
    final query = rawQuery.trim();
    if (unfocus) {
      FocusScope.of(context).unfocus();
    }
    final version = ++_requestVersion;

    setState(() {
      _activeQuery = query;
      _products = const <ProductModel>[];
      _currentPage = 0;
      _lastPage = 1;
      _error = null;
      _isLoading = true;
    });

    try {
      final pageData = await _fetchSearchPage(query: query, page: 1);
      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _products = pageData.products;
        _currentPage = pageData.currentPage;
        _lastPage = pageData.lastPage;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final pageData = await _fetchSearchPage(
        query: _activeQuery,
        page: _currentPage + 1,
      );
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<_SearchProductsPageData> _fetchSearchPage({
    required String query,
    required int page,
  }) async {
    final cleanQuery = query.trim();
    final response = await context
        .read<HomeProvider>()
        .repository
        .fetchProducts(
          query: cleanQuery.isEmpty ? null : cleanQuery,
          sort: 'recommended',
          perPage: _productsPerPage,
          page: page,
        );
    final meta = Map<String, dynamic>.from(
      response['meta'] as Map? ?? <String, dynamic>{},
    );
    final products = List<ProductModel>.from(
      response['products'] as List<ProductModel>,
    );

    return _SearchProductsPageData(
      products: List<ProductModel>.unmodifiable(products),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          centerTitle: true,
          title: Text(
            _activeQuery.isEmpty ? 'منتجاتنا' : 'نتائج البحث',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: _SearchResultsField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: widget.autofocusSearch,
                    isLoading: _isLoading,
                    onChanged: _handleSearchTextChanged,
                    onClear: _clearSearch,
                    onSearch: () => _runSearch(_searchController.text),
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null && _products.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchStateMessage(
                    icon: AppIcons.error_outline_rounded,
                    title: 'تعذر البحث',
                    subtitle: _error!,
                    actionLabel: 'إعادة المحاولة',
                    onAction: () => _runSearch(_activeQuery),
                  ),
                )
              else if (_products.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchStateMessage(
                    icon: _activeQuery.isEmpty
                        ? AppIcons.search_rounded
                        : AppIcons.search_off_rounded,
                    title: _activeQuery.isEmpty
                        ? 'لا توجد منتجات'
                        : 'لا توجد نتائج',
                    subtitle: _activeQuery.isEmpty
                        ? 'ستظهر المنتجات هنا عند توفرها.'
                        : 'جرّب البحث باسم منتج آخر.',
                    actionLabel: _activeQuery.isEmpty
                        ? 'كتابة بحث'
                        : 'تعديل البحث',
                    onAction: () =>
                        FocusScope.of(context).requestFocus(_searchFocusNode),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      _activeQuery.isEmpty
                          ? 'كل المنتجات'
                          : 'نتائج "$_activeQuery"',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _products[index];
                      return _ProductCard(product: product, index: index);
                    }, childCount: _products.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isLoadingMore
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  const _SearchResultsField({
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFE3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: (_) => onSearch(),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        cursorColor: AppColors.primary,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج...',
          hintStyle: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            size: 21,
            color: AppColors.textSecondary,
          ),
          suffixIcon: isLoading && hasText
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : hasText
              ? IconButton(
                  onPressed: onClear,
                  splashRadius: 20,
                  icon: const Icon(
                    AppIcons.close_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                )
              : IconButton(
                  onPressed: onSearch,
                  splashRadius: 20,
                  icon: const Icon(
                    AppIcons.arrow_forward_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}

class _SearchStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _SearchStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchProductsPageData {
  final List<ProductModel> products;
  final int currentPage;
  final int lastPage;

  const _SearchProductsPageData({
    required this.products,
    required this.currentPage,
    required this.lastPage,
  });
}
