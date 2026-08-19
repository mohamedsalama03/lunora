import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/product_model.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../home/screens/product_detail_screen.dart';
import '../providers/wishlist_provider.dart';

// ─────────────────────────────────────────────────────────────
// Wishlist Screen — AILA / Lovable layout (clean horizontal cards)
// ─────────────────────────────────────────────────────────────

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Consumer<WishlistProvider>(
          builder: (context, wishlist, child) {
            final allItems = wishlist.items;
            final items = _searchQuery.isEmpty
                ? allItems
                : allItems
                      .where(
                        (item) => item.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _WishlistHeader(count: allItems.length),
                ),
                if (allItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _WishlistSearchField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: allItems.isEmpty
                      ? const _EmptyWishlistState()
                      : items.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد نتائج مطابقة لبحثك',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.taupe,
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) =>
                              _WishlistCard(product: items[index]),
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

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────

class _WishlistHeader extends StatelessWidget {
  final int count;

  const _WishlistHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المفضلة',
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.mauve,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count قطعة محفوظة',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.taupe,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      AppIcons.notifications_none_rounded,
                      color: AppColors.mauve,
                      size: 24,
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.rosePink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => context.read<AppShellController>().setIndex(
                  AppShellController.cartIndex,
                ),
                child: const Icon(
                  AppIcons.shopping_cart_outlined,
                  color: AppColors.mauve,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WishlistSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _WishlistSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.mauve,
        ),
        decoration: InputDecoration(
          hintText: 'ابحثي في المفضلة...',
          hintStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            color: AppColors.roseGold,
            size: 22,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Wishlist card — image · info · (price + trash + Add)
// ─────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final ProductModel product;

  const _WishlistCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        product.thumbnail != null && product.thumbnail!.trim().isNotEmpty;
    final eyebrow = (product.category?.name ?? product.brand?.name)?.trim();
    final subtitle = product.shortDescription?.trim();
    final inStock = product.isPurchasable;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image
            Container(
              width: 92,
              height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: AppColors.blushGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: hasImage
                  ? Image.network(
                      product.thumbnail!,
                      fit: BoxFit.cover,
                      cacheWidth: 280,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                      errorBuilder: (_, e, st) => Icon(
                        AppIcons.image_not_supported_outlined,
                        color: AppColors.roseGold.withValues(alpha: 0.5),
                      ),
                    )
                  : Icon(
                      AppIcons.inventory_2_outlined,
                      size: 34,
                      color: AppColors.roseGold.withValues(alpha: 0.5),
                    ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow != null && eyebrow.isNotEmpty) ...[
                    Text(
                      eyebrow.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mauve,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.taupe,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _formatPrice(product.pricing.effectivePrice),
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.roseGold,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      // Remove from wishlist
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<WishlistProvider>().removeFavorite(
                            product.id,
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.blush,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            AppIcons.delete_outline_rounded,
                            size: 17,
                            color: AppColors.roseGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add to cart
                      GestureDetector(
                        onTap: inStock ? () => _addToCart(context) : null,
                        child: Opacity(
                          opacity: inStock ? 1 : 0.5,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppColors.roseGradient,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'إضافة',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
  }

  void _addToCart(BuildContext context) {
    HapticFeedback.lightImpact();
    if (product.hasPendingVariantStock) {
      Navigator.push(
        context,
        MaterialPageRoute(
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
    AppNotifications.showSuccess(context, 'تمت الإضافة إلى السلة');
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────

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
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                gradient: AppColors.blushGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.favorite_border_rounded,
                size: 54,
                color: AppColors.roseGold.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'المفضلة فارغة',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.mauve,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'احفظي المنتجات التي تعجبك وارجعي إليها لاحقاً بسهولة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.taupe,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.read<AppShellController>().goHome(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              icon: const Icon(AppIcons.explore_rounded, size: 20),
              label: Text(
                'استكشفي المنتجات',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _formatPrice(double value) {
  final hasDecimals = value % 1 != 0;
  return '${value.toStringAsFixed(hasDecimals ? 2 : 0)} د.ل';
}
