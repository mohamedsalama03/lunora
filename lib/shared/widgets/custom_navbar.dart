import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../features/cart/providers/cart_provider.dart';

class _NavItem {
  final int destinationIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.destinationIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      destinationIndex: 0,
      icon: AppIcons.home_outlined,
      activeIcon: AppIcons.home_rounded,
      label: 'الرئيسية',
    ),
    _NavItem(
      destinationIndex: 1,
      icon: AppIcons.search_rounded,
      activeIcon: AppIcons.search_rounded,
      label: 'البحث',
    ),
    _NavItem(
      destinationIndex: 2,
      icon: AppIcons.favorite_border_rounded,
      activeIcon: AppIcons.favorite_rounded,
      label: 'المفضلة',
    ),
    _NavItem(
      destinationIndex: 4,
      icon: AppIcons.shopping_bag_outlined,
      activeIcon: AppIcons.shopping_bag_rounded,
      label: 'الحقيبة',
    ),
    _NavItem(
      destinationIndex: 3,
      icon: AppIcons.person_outline_rounded,
      activeIcon: AppIcons.person_rounded,
      label: 'حسابي',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // إعادة البناء فقط عند تغيّر عدد عناصر السلة (وليس عند أي تحديث للمزوّد).
    final cartCount = context.select<CartProvider, int>(
      (cart) => cart.itemCount,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.42)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mauve.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(10, 8, 10, bottomInset > 0 ? 6 : 10),
        child: SizedBox(
          height: 58,
          child: Row(
            children: _items.map((item) {
              return Expanded(
                child: RepaintBoundary(
                  child: _NavBarItem(
                    item: item,
                    isSelected: item.destinationIndex == currentIndex,
                    badgeCount: item.destinationIndex == 4 ? cartCount : 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(item.destinationIndex);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  static const Color _activeColor = Color(0xFFC77F91);
  static const Color _idleColor = Color(0xFF7F686D);

  // نمط ثابت يُحسب مرة واحدة بدل استدعاء GoogleFonts في كل إطار أنيميشن.
  static final TextStyle _labelStyle = GoogleFonts.cairo(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  final _NavItem item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: isSelected ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            final labelColor = Color.lerp(_idleColor, _activeColor, t)!;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.84 + (0.16 * t),
                      child: Opacity(
                        opacity: t,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _activeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _activeColor.withValues(alpha: 0.24),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      height: 36,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 1 - t,
                              child: Icon(
                                item.icon,
                                size: 21,
                                color: _idleColor,
                              ),
                            ),
                            Opacity(
                              opacity: t,
                              child: Icon(
                                item.activeIcon,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -3,
                        right: -8,
                        child: _CountBadge(
                          text: badgeCount > 99 ? '99+' : '$badgeCount',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _labelStyle.copyWith(color: labelColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String text;

  const _CountBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.badge,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
