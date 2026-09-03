import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/utils/app_notifications.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class _AuraColors {
  _AuraColors._();

  static const primary = Color(0xFF4A3428);
  static const roseGold = primary;
  static const rosePink = Color(0xFFC8B59E);
  static const blush = Color(0xFFEADCC8);
  static const background = Color(0xFFF8F5F0);
  static const surface = Color(0xFFFCFAF6);
  static const divider = Color(0xFFE4DBCE);
  static const mauve = Color(0xFF2E211B);
  static const taupe = Color(0xFF6D5A4D);
  static const shadowCard = Color(0x142E211B);
  static const shadowSoft = Color(0x242E211B);
  static const blushGradient = LinearGradient(
    colors: [Color(0xFFEADCC8), Color(0xFFEADCC8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final checkoutBottom = 104.0 + (bottomInset > 14 ? bottomInset - 14 : 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _AuraColors.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _PremiumCartHeader(itemCount: cart.itemCount),
                  Expanded(
                    child: cart.items.isEmpty
                        ? const _EmptyCartState()
                        : ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              8,
                              24,
                              checkoutBottom + 92,
                            ),
                            children: [
                              _ShippingBanner(totalPrice: cart.totalPrice),
                              const SizedBox(height: 16),
                              for (final item in cart.items) ...[
                                _CartItemCard(item: item, cartProvider: cart),
                                const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 8),
                              _OrderSummaryCard(totalPrice: cart.totalPrice),
                            ],
                          ),
                  ),
                ],
              ),
              if (cart.items.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  // Keep the checkout capsule visibly separated from the
                  // shell's floating navigation capsule.
                  bottom: checkoutBottom,
                  child: _CheckoutButton(
                    totalPrice: cart.totalPrice,
                    canCheckout: cart.canCheckout,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _bagCountLabel(int itemCount) {
    if (itemCount == 1) return 'منتج واحد في سلتك';
    if (itemCount == 2) return 'منتجان في سلتك';
    if (itemCount >= 3 && itemCount <= 10) {
      return '$itemCount منتجات في سلتك';
    }
    return '$itemCount منتجاً في سلتك';
  }
}

class _ShippingBanner extends StatelessWidget {
  final double totalPrice;

  const _ShippingBanner({required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AuraColors.blush.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.local_shipping_rounded,
            size: 18,
            color: _AuraColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              totalPrice > 0
                  ? 'سيتم احتساب التوصيل بدقة بعد اختيار العنوان.'
                  : 'أضيفي منتجاتك المفضلة لبدء الطلب.',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _AuraColors.mauve,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cartProvider;

  const _CartItemCard({required this.item, required this.cartProvider});

  @override
  Widget build(BuildContext context) {
    final subtitle = item.variantInfo?.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AuraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AuraColors.divider.withValues(alpha: 0.78)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CartProductImage(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _AuraColors.mauve,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => cartProvider.removeItem(item.id),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(10, 4, 2, 8),
                          child: Icon(
                            AppIcons.close_rounded,
                            size: 17,
                            color: _AuraColors.taupe,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: _AuraColors.taupe,
                        height: 1.15,
                      ),
                    )
                  else
                    Text(
                      'لمسة ناعمة ومشرقة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: _AuraColors.taupe,
                        height: 1.15,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatCompactMoney(item.price),
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _AuraColors.mauve,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      _QuantityPill(item: item, cartProvider: cartProvider),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartProductImage extends StatelessWidget {
  final CartItem item;

  const _CartProductImage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 112,
      decoration: BoxDecoration(
        color: _AuraColors.blush,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: item.imageUrl.trim().isNotEmpty
            ? Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _CartImageFallback(name: item.name),
              )
            : _CartImageFallback(name: item.name),
      ),
    );
  }
}

class _CartImageFallback extends StatelessWidget {
  final String name;

  const _CartImageFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _AuraColors.blushGradient),
      child: Center(
        child: Icon(
          _getIconForName(name),
          color: _AuraColors.roseGold.withValues(alpha: 0.52),
          size: 34,
        ),
      ),
    );
  }

  IconData _getIconForName(String name) {
    final value = name.toLowerCase();
    if (value.contains('serum')) return AppIcons.medication_rounded;
    if (value.contains('lipstick')) return AppIcons.edit;
    if (value.contains('cream') || value.contains('moisturizer')) {
      return AppIcons.inventory_2_outlined;
    }
    return AppIcons.shopping_bag_outlined;
  }
}

class _QuantityPill extends StatelessWidget {
  final CartItem item;
  final CartProvider cartProvider;

  const _QuantityPill({required this.item, required this.cartProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: _AuraColors.blush.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => cartProvider.decreaseQuantity(item.id),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              child: Icon(
                AppIcons.remove_rounded,
                size: 14,
                color: _AuraColors.roseGold,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '${item.quantity}',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _AuraColors.mauve,
                  height: 1,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final result = cartProvider.increaseQuantity(item.id);
              if (result.isUnavailable) {
                AppNotifications.showError(
                  context,
                  'هذا المنتج غير متوفر حالياً',
                );
                return;
              }
              if (result.isLimitReached) {
                AppNotifications.showError(
                  context,
                  'المتاح فقط ${result.maxQuantity ?? item.maxPurchasableQuantity} قطع',
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: item.canIncrease
                    ? _AuraColors.primary
                    : _AuraColors.rosePink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.add_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final double totalPrice;

  const _OrderSummaryCard({required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    final totalLabel = _formatTotalMoney(totalPrice);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AuraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AuraColors.divider.withValues(alpha: 0.62)),
        boxShadow: const [
          BoxShadow(
            color: _AuraColors.shadowCard,
            blurRadius: 24,
            spreadRadius: -12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryLine(label: 'المجموع الفرعي', value: totalLabel),
          const SizedBox(height: 13),
          const _SummaryLine(label: 'التوصيل', value: 'يُحسب حسب العنوان'),
          const SizedBox(height: 17),
          Divider(
            color: _AuraColors.divider.withValues(alpha: 0.85),
            height: 1,
          ),
          const SizedBox(height: 20),
          _SummaryLine(label: 'الإجمالي', value: totalLabel, isTotal: true),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryLine({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = isTotal
        ? GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _AuraColors.mauve,
          )
        : GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _AuraColors.taupe,
          );

    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(
          value,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: _AuraColors.mauve,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final double totalPrice;
  final bool canCheckout;

  const _CheckoutButton({required this.totalPrice, required this.canCheckout});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: canCheckout ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !canCheckout
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CheckoutScreen(),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              color: _AuraColors.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: _AuraColors.shadowSoft,
                  blurRadius: 28,
                  spreadRadius: -10,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إتمام الطلب',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _AuraColors.surface,
                    ),
                  ),
                  Text(
                    _formatTotalMoney(totalPrice),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _AuraColors.surface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: _AuraColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _AuraColors.roseGold.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                AppIcons.shopping_bag_outlined,
                size: 54,
                color: _AuraColors.roseGold.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'سلتك فارغة',
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _AuraColors.mauve,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضيفي مستلزماتك المفضلة وستظهر هنا.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _AuraColors.taupe,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => context.read<AppShellController>().goHome(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _AuraColors.roseGold,
                side: BorderSide(
                  color: _AuraColors.roseGold.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'ابدئي التسوق',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCartHeader extends StatelessWidget {
  final int itemCount;

  const _PremiumCartHeader({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.read<AppShellController>().goHome(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _AuraColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _AuraColors.divider.withValues(alpha: 0.75),
                    ),
                  ),
                  child: const Icon(
                    AppIcons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: _AuraColors.mauve,
                  ),
                ),
              ),
            ),
            Text(
              'سلة التسوق',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _AuraColors.mauve,
              ),
            ),
            Positioned(
              bottom: -2,
              child: Text(
                CartScreen._bagCountLabel(itemCount),
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _AuraColors.taupe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCompactMoney(double value) {
  return _formatCartMoney(value);
}

String _formatTotalMoney(double value) {
  return _formatCartMoney(value);
}

String _formatCartMoney(double value) {
  final decimals = value % 1 == 0 ? 0 : 2;
  return '${value.toStringAsFixed(decimals)} د.ل';
}
