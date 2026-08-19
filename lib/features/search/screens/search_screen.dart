import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../home/providers/home_provider.dart';
import '../../home/screens/category_explorer_screen.dart';
import '../../home/screens/product_detail_screen.dart';
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
      if (!mounted) return;
      // تحميل الفئات لقسم "تصفّح حسب الفئة" في الحالة الفارغة.
      context.read<HomeProvider>().ensureInitialDataLoaded();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    context.read<SearchProvider>().onSearchQueryChanged(value);
  }

  void _clearQuery() {
    _controller.clear();
    context.read<SearchProvider>().clearSearch();
  }

  void _applyRecentSearch(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    context.read<SearchProvider>().onSearchQueryChanged(query);
    _focusNode.requestFocus();
  }

  void _openCategory(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryExplorerScreen(category: category),
      ),
    );
  }

  void _openProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final hasQuery = search.searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AILA BEAUTY',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: AppColors.roseGold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'ابحثي عن منتجك',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.mauve,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hasText: _controller.text.isNotEmpty,
                    onChanged: _onChanged,
                    onClear: _clearQuery,
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasQuery
                  ? _SearchResultsView(
                      search: search,
                      onRetry: () => _onChanged(search.searchQuery),
                      onProductTap: _openProduct,
                    )
                  : _SearchEmptyView(
                      recentSearches: search.recentSearches,
                      onRecentTap: _applyRecentSearch,
                      onClearRecent: () =>
                          context.read<SearchProvider>().clearRecentSearches(),
                      onCategoryTap: _openCategory,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// حقل البحث (نمط مطابق لحقل البحث في مستكشف الفئات)
// ----------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hasText,
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
            color: AppColors.roseGold.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primary,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'ابحثي عن منتج أو ماركة...',
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
          suffixIcon: !hasText
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

// ----------------------------------------------------------------------------
// الحالة الفارغة: عمليات بحث حديثة + تصفّح حسب الفئة
// ----------------------------------------------------------------------------
class _SearchEmptyView extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;
  final ValueChanged<CategoryModel> onCategoryTap;

  const _SearchEmptyView({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onClearRecent,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final categories = homeProvider.categories;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
      children: [
        if (recentSearches.isNotEmpty) ...[
          _SectionHeader(
            title: 'عمليات بحث حديثة',
            trailing: GestureDetector(
              onTap: onClearRecent,
              child: Text(
                'مسح',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.roseGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: recentSearches
                .map(
                  (query) => _RecentChip(
                    label: query,
                    onTap: () => onRecentTap(query),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 30),
        ] else
          const _SearchWelcome(),
        _SectionHeader(
          title: 'تصفّح حسب الفئة',
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        if (homeProvider.isLoadingCategories && categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'ستظهر الفئات هنا قريباً.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(
                category: category,
                onTap: () => onCategoryTap(category),
              );
            },
          ),
      ],
    );
  }
}

class _SearchWelcome extends StatelessWidget {
  const _SearchWelcome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.roseGold.withValues(alpha: 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              AppIcons.search_rounded,
              size: 38,
              color: AppColors.roseGold.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'ابحثي عن منتجاتك المفضلة لدى AILA',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'اكتبي اسم المنتج أو الماركة، أو تصفّحي الفئات أدناه.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        trailing,
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.blush.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.history_rounded,
                size: 15,
                color: AppColors.roseGold.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mauve,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  int _treeProductsCount(CategoryModel category) {
    return category.productsCount +
        category.children.fold<int>(
          0,
          (total, child) => total + _treeProductsCount(child),
        );
  }

  @override
  Widget build(BuildContext context) {
    final initial = category.name.trim().isEmpty
        ? 'A'
        : category.name.trim().characters.first.toUpperCase();
    final hasChildren =
        category.children.isNotEmpty || category.childrenCount > 0;
    final subtitle = hasChildren
        ? '${category.childrenCount} فئة'
        : '${_treeProductsCount(category)} منتج';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAFA),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.roseGold.withValues(alpha: 0.025),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 16,
                  top: 12,
                  child: Text(
                    initial,
                    style: GoogleFonts.cairo(
                      fontSize: 50,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rosePink.withValues(alpha: 0.16),
                      height: 1,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.65, 0.85),
                        radius: 1.05,
                        colors: [
                          AppColors.blush.withValues(alpha: 0.42),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 22, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.mauve,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.roseGold,
                          height: 1,
                        ),
                      ),
                    ],
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

// ----------------------------------------------------------------------------
// حالة النتائج: تحميل / خطأ / لا نتائج / قائمة
// ----------------------------------------------------------------------------
class _SearchResultsView extends StatelessWidget {
  final SearchProvider search;
  final VoidCallback onRetry;
  final ValueChanged<ProductModel> onProductTap;

  const _SearchResultsView({
    required this.search,
    required this.onRetry,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (search.isLoadingSearch && search.searchResults.isEmpty) {
      return const _ResultsLoading();
    }

    if (search.error != null && search.searchResults.isEmpty) {
      return AppErrorView(error: search.error, onRetry: onRetry);
    }

    if (search.searchResults.isEmpty) {
      return _ResultsMessage(
        icon: AppIcons.search_off_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.blush.withValues(alpha: 0.6),
        title: 'لا توجد نتائج',
        message:
            'لم نعثر على نتائج لـ «${search.searchQuery.trim()}».\n'
            'جرّبي كلمات أخرى.',
      );
    }

    final results = search.searchResults;
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _ProductResultCard(
          product: results[index],
          onTap: () => onProductTap(results[index]),
        );
      },
    );
  }
}

class _ResultsLoading extends StatelessWidget {
  const _ResultsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return Container(
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF4E8EA)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: 110,
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 13,
                      width: 70,
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultsMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String message;

  const _ResultsMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// بطاقة نتيجة المنتج (نمط مطابق لبطاقة قائمة المنتج في مستكشف الفئات)
// ----------------------------------------------------------------------------
class _ProductResultCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductResultCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.thumbnail?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 104,
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF4E8EA)),
            boxShadow: [
              BoxShadow(
                color: AppColors.mauve.withValues(alpha: 0.055),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              _ProductThumb(imageUrl: imageUrl, inStock: product.isPurchasable),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.name,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    if (product.brand?.name != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.brand!.name,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9E868B),
                          height: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.pricing.isOnSale) ...[
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
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${product.pricing.effectivePrice.toStringAsFixed(2)} د.ل',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                AppIcons.arrow_forward_ios_rounded,
                size: 17,
                color: Color(0xFFCDBABE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final bool inStock;

  const _ProductThumb({required this.imageUrl, required this.inStock});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFCEEF0),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  cacheWidth: 220,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ProductImageFallback(),
                )
              : const _ProductImageFallback(),
        ),
        PositionedDirectional(
          top: -4,
          end: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: inStock
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              inStock ? 'متوفر' : 'غير متوفر',
              style: GoogleFonts.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: inStock ? AppColors.success : const Color(0xFFD32F2F),
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      AppIcons.inventory_2_rounded,
      size: 34,
      color: AppColors.primary,
    );
  }
}
