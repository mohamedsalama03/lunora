import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/product_model.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/app_notifications.dart';
import '../../cart/providers/cart_provider.dart';
import '../../home/screens/product_detail_screen.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _WishlistColors.background,
      body: SafeArea(
        bottom: false,
        child: Consumer<WishlistProvider>(
          builder: (context, wishlist, _) {
            final allItems = wishlist.items;
            final normalizedQuery = _query.trim().toLowerCase();
            final visibleItems = normalizedQuery.isEmpty
                ? allItems
                : allItems.where((product) {
                    final brand = product.brand?.name.toLowerCase() ?? '';
                    final category = product.category?.name.toLowerCase() ?? '';
                    return product.name.toLowerCase().contains(
                          normalizedQuery,
                        ) ||
                        brand.contains(normalizedQuery) ||
                        category.contains(normalizedQuery);
                  }).toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _WishlistHeader(count: allItems.length),
                ),
                if (allItems.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _WishlistSearchField(
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ] else
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (allItems.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyWishlistState(),
                  )
                else if (visibleItems.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _WishlistMessage(
                      icon: AppIcons.search_off_rounded,
                      title: 'لا توجد نتائج',
                      message: 'جرّبي اسمًا مختلفًا للقطعة أو العلامة.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 32,
                            childAspectRatio: .54,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _WishlistProductCard(product: visibleItems[index]),
                        childCount: visibleItems.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WishlistHeader extends StatelessWidget {
  const _WishlistHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قائمتك الخاصة',
                  style: _wishlistText(
                    size: 11,
                    weight: FontWeight.w500,
                    color: _WishlistColors.mutedText,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'القطع المحفوظة',
                  style: _wishlistText(size: 30, weight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count ${count == 1 ? 'قطعة' : 'قطع'} · محفوظة لوقت لاحق',
                  style: _wishlistText(
                    size: 13,
                    color: _WishlistColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: _WishlistColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: _WishlistColors.border),
            ),
            child: InkWell(
              onTap: () => context.read<AppShellController>().setIndex(
                AppShellController.cartIndex,
              ),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  AppIcons.shopping_bag_outlined,
                  size: 19,
                  color: _WishlistColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistSearchField extends StatelessWidget {
  const _WishlistSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _WishlistColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _WishlistColors.border),
      ),
      child: TextField(
        onChanged: onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        cursorColor: _WishlistColors.primary,
        style: _wishlistText(size: 14, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'ابحثي في القطع المحفوظة…',
          hintStyle: _wishlistText(size: 13, color: _WishlistColors.mutedText),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            size: 19,
            color: _WishlistColors.mutedText,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({required this.product});

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
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
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
                    _WishlistNetworkImage(url: product.thumbnail),
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
                            color: _WishlistColors.background.withValues(
                              alpha: .9,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '−${product.pricing.discountPercentage}%',
                            style: _wishlistText(
                              size: 10,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      end: 12,
                      top: 12,
                      child: _WishlistImageButton(
                        icon: AppIcons.favorite_rounded,
                        color: _WishlistColors.accent,
                        tooltip: 'إزالة من المفضلة',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<WishlistProvider>().removeFavorite(
                            product.id,
                          );
                          AppNotifications.showSuccess(
                            context,
                            'تمت الإزالة من المفضلة',
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
              style: _wishlistText(size: 11, color: _WishlistColors.mutedText),
            ),
            const SizedBox(height: 3),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _wishlistText(
                size: 14,
                weight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPrice(product.pricing.effectivePrice),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: _wishlistText(size: 14, weight: FontWeight.w500),
                      ),
                      if (showSale)
                        Text(
                          _formatPrice(product.pricing.price),
                          maxLines: 1,
                          style: _wishlistText(
                            size: 10,
                            color: _WishlistColors.mutedText,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _WishlistImageButton(
                  icon: AppIcons.shopping_bag_outlined,
                  color: _WishlistColors.onPrimary,
                  backgroundColor: _WishlistColors.primary,
                  tooltip: 'إضافة إلى السلة',
                  enabled: product.isPurchasable,
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
    HapticFeedback.lightImpact();
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

class _WishlistImageButton extends StatelessWidget {
  const _WishlistImageButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
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
              _WishlistColors.background.withValues(alpha: .9),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistNetworkImage extends StatelessWidget {
  const _WishlistNetworkImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const _WishlistImageFallback();
    }
    return Image.network(
      normalized,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const _WishlistImageFallback(),
    );
  }
}

class _WishlistImageFallback extends StatelessWidget {
  const _WishlistImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _WishlistColors.secondary.withValues(alpha: .65),
      child: Center(
        child: Icon(
          AppIcons.inventory_2_outlined,
          size: 34,
          color: _WishlistColors.primary.withValues(alpha: .45),
        ),
      ),
    );
  }
}

class _EmptyWishlistState extends StatelessWidget {
  const _EmptyWishlistState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: _WishlistColors.secondary,
              child: Icon(
                AppIcons.favorite_border_rounded,
                size: 36,
                color: _WishlistColors.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'لا توجد قطع محفوظة',
              style: _wishlistText(size: 20, weight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'احفظي القطع التي تحبينها لتجديها هنا بسهولة.',
              textAlign: TextAlign.center,
              style: _wishlistText(
                size: 13,
                color: _WishlistColors.mutedText,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<AppShellController>().goHome(),
              style: FilledButton.styleFrom(
                backgroundColor: _WishlistColors.primary,
                foregroundColor: _WishlistColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(AppIcons.arrow_back_rounded, size: 17),
              label: Text(
                'استكشفي المنتجات',
                style: _wishlistText(
                  size: 13,
                  weight: FontWeight.w500,
                  color: _WishlistColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistMessage extends StatelessWidget {
  const _WishlistMessage({
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
              backgroundColor: _WishlistColors.secondary,
              child: Icon(icon, color: _WishlistColors.primary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: _wishlistText(size: 18, weight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _wishlistText(size: 13, color: _WishlistColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistColors {
  const _WishlistColors._();

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

TextStyle _wishlistText({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _WishlistColors.text,
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
