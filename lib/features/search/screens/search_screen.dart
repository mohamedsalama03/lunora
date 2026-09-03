import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/app_notifications.dart';
import '../../home/providers/home_provider.dart';
import '../../home/screens/category_explorer_screen.dart';
import '../../home/screens/product_detail_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/search_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeProvider>().ensureInitialDataLoaded();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    context.read<SearchProvider>().clearSearch();
    _focusNode.requestFocus();
  }

  void _applyRecent(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    context.read<SearchProvider>().onSearchQueryChanged(query);
    _focusNode.requestFocus();
  }

  void _openCategory(CategoryModel category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final hasQuery = search.searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _SearchColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اكتشفي',
                    style: _searchText(
                      size: 11,
                      weight: FontWeight.w500,
                      color: _SearchColors.mutedText,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ابحثي عن ما تحبين',
                    style: _searchText(size: 30, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  _SearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hasText: _controller.text.isNotEmpty,
                    onChanged: context
                        .read<SearchProvider>()
                        .onSearchQueryChanged,
                    onClear: _clearSearch,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: hasQuery
                  ? _SearchResults(
                      provider: search,
                      onRetry: () =>
                          search.onSearchQueryChanged(search.searchQuery),
                    )
                  : _DiscoveryView(
                      recentSearches: search.recentSearches,
                      onRecentTap: _applyRecent,
                      onClearRecent: () {
                        search.clearRecentSearches();
                      },
                      onCategoryTap: _openCategory,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _SearchColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _SearchColors.border),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        cursorColor: _SearchColors.primary,
        style: _searchText(size: 14, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'ابحثي عن منتج أو علامة…',
          hintStyle: _searchText(size: 13, color: _SearchColors.mutedText),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            size: 19,
            color: _SearchColors.mutedText,
          ),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: onClear,
                  icon: const Icon(
                    AppIcons.close_rounded,
                    size: 18,
                    color: _SearchColors.text,
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

class _DiscoveryView extends StatelessWidget {
  const _DiscoveryView({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onClearRecent,
    required this.onCategoryTap,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;
  final ValueChanged<CategoryModel> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (recentSearches.isNotEmpty) ...[
          _SectionHeader(
            eyebrow: 'آخر ما بحثتِ عنه',
            title: 'عمليات البحث الأخيرة',
            actionLabel: 'مسح',
            onAction: onClearRecent,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches
                  .map(
                    (query) => _RecentChip(
                      label: query,
                      onTap: () => onRecentTap(query),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 40),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _SearchColors.secondary.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.search_rounded,
                    size: 24,
                    color: _SearchColors.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'ابدئي باسم القطعة أو العلامة، أو تصفّحي الفئات أدناه.',
                      style: _searchText(
                        size: 13,
                        color: _SearchColors.mutedText,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
        const _SectionHeader(eyebrow: 'الكتالوج', title: 'تصفّحي حسب الفئة'),
        const SizedBox(height: 16),
        if (home.isLoadingCategories && home.categories.isEmpty)
          const _CategoryRailSkeleton()
        else if (home.categoriesError != null && home.categories.isEmpty)
          SizedBox(
            height: 230,
            child: _SearchErrorState(
              message: 'تعذّر تحميل الفئات.',
              onRetry: () => context
                  .read<HomeProvider>()
                  .ensureInitialDataLoaded(forceRefresh: true),
            ),
          )
        else if (home.categories.isEmpty)
          const _SearchEmptyState(
            icon: AppIcons.category_outlined,
            title: 'لا توجد فئات حاليًا',
            message: 'ستظهر مجموعاتنا هنا فور توفرها.',
          )
        else
          SizedBox(
            height: 246,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: home.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = home.categories[index];
                return SizedBox(
                  width: 184,
                  child: _CategoryCard(
                    category: category,
                    onTap: () => onCategoryTap(category),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.provider, required this.onRetry});

  final SearchProvider provider;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoadingSearch && provider.searchResults.isEmpty) {
      return const _ProductGridSkeleton();
    }
    if (provider.error != null && provider.searchResults.isEmpty) {
      return _SearchErrorState(message: 'تعذّر تنفيذ البحث.', onRetry: onRetry);
    }
    if (provider.searchResults.isEmpty) {
      return _SearchEmptyState(
        icon: AppIcons.search_off_rounded,
        title: 'لا توجد نتائج',
        message: 'لم نعثر على نتائج لـ «${provider.searchQuery.trim()}».',
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: [
                    Text(
                      '${provider.searchResults.length} نتيجة',
                      style: _searchText(
                        size: 12,
                        color: _SearchColors.mutedText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'الأكثر صلة',
                      style: _searchText(size: 12, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 32,
                  childAspectRatio: .56,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SearchProductCard(
                    product: provider.searchResults[index],
                  ),
                  childCount: provider.searchResults.length,
                ),
              ),
            ),
          ],
        ),
        if (provider.isLoadingSearch)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              minHeight: 1.5,
              color: _SearchColors.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

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
              _SearchNetworkImage(
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
                      stops: [.4, 1],
                    ),
                  ),
                ),
              PositionedDirectional(
                start: 14,
                end: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_categoryCount(category)} قطعة',
                      style: _searchText(
                        size: 10,
                        color: hasImage
                            ? _SearchColors.onPrimary.withValues(alpha: .8)
                            : _SearchColors.mutedText,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _searchText(
                        size: 17,
                        weight: FontWeight.w500,
                        color: hasImage
                            ? _SearchColors.onPrimary
                            : _SearchColors.text,
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

class _SearchProductCard extends StatelessWidget {
  const _SearchProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final label = (product.category?.name ?? product.brand?.name ?? 'لونورا')
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
                    _SearchNetworkImage(
                      url: product.thumbnail,
                      fallbackIcon: AppIcons.inventory_2_outlined,
                    ),
                    if (showSale)
                      PositionedDirectional(
                        start: 12,
                        top: 12,
                        child: _SaleBadge(
                          discount: product.pricing.discountPercentage,
                        ),
                      ),
                    PositionedDirectional(
                      end: 12,
                      top: 12,
                      child: Consumer<WishlistProvider>(
                        builder: (context, wishlist, _) {
                          final saved = wishlist.isFavorite(product.id);
                          return _FavoriteButton(
                            saved: saved,
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
              style: _searchText(size: 11, color: _SearchColors.mutedText),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _searchText(
                size: 14,
                weight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  _price(product.pricing.effectivePrice),
                  style: _searchText(size: 14, weight: FontWeight.w500),
                ),
                if (showSale) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _price(product.pricing.price),
                      maxLines: 1,
                      style: _searchText(
                        size: 11,
                        color: _SearchColors.mutedText,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
                  style: _searchText(
                    size: 11,
                    weight: FontWeight.w500,
                    color: _SearchColors.mutedText,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: _searchText(size: 24, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: _SearchColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                actionLabel!,
                style: _searchText(size: 12, weight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _SearchColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: _SearchColors.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.history_rounded,
                size: 15,
                color: _SearchColors.mutedText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _searchText(size: 12, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _SearchColors.background.withValues(alpha: .88),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            saved
                ? AppIcons.favorite_rounded
                : AppIcons.favorite_border_rounded,
            size: 18,
            color: saved ? _SearchColors.accent : _SearchColors.text,
          ),
        ),
      ),
    );
  }
}

class _SaleBadge extends StatelessWidget {
  const _SaleBadge({required this.discount});

  final int discount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _SearchColors.background.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '−$discount%',
        style: _searchText(size: 10, weight: FontWeight.w500),
      ),
    );
  }
}

class _SearchNetworkImage extends StatelessWidget {
  const _SearchNetworkImage({required this.url, required this.fallbackIcon});

  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _SearchImageFallback(icon: fallbackIcon);
    }
    return Image.network(
      normalized,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _SearchImageFallback(icon: fallbackIcon),
    );
  }
}

class _SearchImageFallback extends StatelessWidget {
  const _SearchImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _SearchColors.secondary.withValues(alpha: .65),
      child: Center(
        child: Icon(
          icon,
          size: 32,
          color: _SearchColors.primary.withValues(alpha: .44),
        ),
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      itemCount: 6,
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
          _SkeletonLine(width: 70),
          SizedBox(height: 8),
          _SkeletonLine(width: 120),
          SizedBox(height: 8),
          _SkeletonLine(width: 80),
        ],
      ),
    );
  }
}

class _CategoryRailSkeleton extends StatelessWidget {
  const _CategoryRailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 246,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          SizedBox(width: 184, child: _SkeletonBox(radius: 16)),
          SizedBox(width: 12),
          SizedBox(width: 184, child: _SkeletonBox(radius: 16)),
        ],
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
        color: _SearchColors.secondary.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
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
        color: _SearchColors.secondary.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
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
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _SearchColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: _SearchColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _searchText(size: 18, weight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _searchText(
                size: 13,
                color: _SearchColors.mutedText,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({required this.message, required this.onRetry});

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
              backgroundColor: _SearchColors.secondary,
              child: Icon(
                AppIcons.wifi_off_rounded,
                color: _SearchColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _searchText(size: 15, weight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _SearchColors.primary,
                foregroundColor: _SearchColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'إعادة المحاولة',
                style: _searchText(
                  size: 12,
                  weight: FontWeight.w500,
                  color: _SearchColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchColors {
  const _SearchColors._();

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

TextStyle _searchText({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _SearchColors.text,
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

String _price(double value) {
  final decimals = value % 1 == 0 ? 0 : 2;
  return '${value.toStringAsFixed(decimals)} د.ل';
}

int _categoryCount(CategoryModel category) {
  return category.productsCount +
      category.children.fold<int>(
        0,
        (total, child) => total + _categoryCount(child),
      );
}
