import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import 'address_map_screen.dart';

class AddressListScreen extends StatefulWidget {
  /// إذا كانت [selectionMode] = true، فعند الضغط على عنوان يُغلق الشاشة ويُعيده
  final bool selectionMode;
  final int? selectedAddressId;

  const AddressListScreen({
    super.key,
    this.selectionMode = false,
    this.selectedAddressId,
  });

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
    });
  }

  Future<void> _addNewAddress() async {
    final provider = context.read<AddressProvider>();
    await provider.loadMapConfig();

    if (!mounted) return;

    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(builder: (_) => const AddressMapScreen()),
    );
    if (result != null && mounted) {
      AppNotifications.showSuccess(context, 'تم إضافة العنوان بنجاح');
    }
  }

  Future<void> _editAddress(AddressModel address) async {
    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(builder: (_) => AddressMapScreen(editAddress: address)),
    );
    if (result != null && mounted) {
      AppNotifications.showSuccess(context, 'تم تحديث العنوان');
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'حذف العنوان',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'هل تريد حذف العنوان "${address.label}"؟',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<AddressProvider>().deleteAddress(
      address.id,
    );
    if (mounted) {
      if (success) {
        AppNotifications.showSuccess(context, 'تم حذف العنوان');
      } else {
        AppNotifications.showError(context, 'تعذر حذف العنوان');
      }
    }
  }

  Future<void> _setDefault(AddressModel address) async {
    if (address.isDefault) return;
    final success = await context.read<AddressProvider>().setDefault(
      address.id,
    );
    if (mounted && success) {
      AppNotifications.showSuccess(
        context,
        'تم تعيين "${address.label}" كعنوان افتراضي',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<AddressProvider>(
          builder: (context, provider, _) {
            final hasAddresses = provider.addresses.isNotEmpty;
            return Column(
              children: [
                _AddressHeader(
                  title: widget.selectionMode
                      ? 'اختر عنوان التوصيل'
                      : 'عناوين التوصيل',
                  count: hasAddresses ? provider.addresses.length : null,
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(child: _buildBody(provider)),
              ],
            );
          },
        ),
        bottomNavigationBar: _BottomAddBar(onAdd: _addNewAddress),
      ),
    );
  }

  Widget _buildBody(AddressProvider provider) {
    if (provider.isLoadingAddresses && provider.addresses.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.addressesError != null && provider.addresses.isEmpty) {
      return _buildError(provider);
    }

    if (provider.addresses.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.loadAddresses(forceRefresh: true),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        itemCount: provider.addresses.length,
        itemBuilder: (context, index) {
          final address = provider.addresses[index];
          return _AddressCard(
            address: address,
            selectionMode: widget.selectionMode,
            isSelected: widget.selectionMode
                ? (widget.selectedAddressId == address.id)
                : address.isDefault,
            onTap: () {
              if (widget.selectionMode) {
                Navigator.pop(context, address);
              } else {
                _setDefault(address);
              }
            },
            onEdit: () => _editAddress(address),
            onDelete: () => _deleteAddress(address),
            onSetDefault: () => _setDefault(address),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: const BoxDecoration(
                gradient: AppColors.blushGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                AppIcons.location_on_rounded,
                size: 52,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 26),
            const AilaEyebrow('MY ADDRESSES'),
            const SizedBox(height: 10),
            Text(
              'لا توجد عناوين محفوظة',
              style: GoogleFonts.cairo(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضيفي عنوانك الأول لتسهيل عملية التوصيل إليكِ',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 240,
              child: AilaGradientButton(
                label: 'إضافة عنوان جديد',
                icon: AppIcons.add_location_alt_rounded,
                onPressed: _addNewAddress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AddressProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.error_outline_rounded,
                size: 44,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              provider.addressesError ?? 'حدث خطأ',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => provider.loadAddresses(forceRefresh: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

/// Quiet Aura header with a compact navigation control and count chip.
class _AddressHeader extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback onBack;

  const _AddressHeader({
    required this.title,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CircleButton(
            icon: AppIcons.arrow_back_ios_new_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELIVERY',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    AppIcons.location_on_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.divider)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ─── Bottom add bar ────────────────────────────────────────────────────────────

class _BottomAddBar extends StatelessWidget {
  final VoidCallback onAdd;

  const _BottomAddBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: AilaGradientButton(
            label: 'إضافة عنوان جديد',
            icon: AppIcons.add_location_alt_rounded,
            height: 54,
            onPressed: onAdd,
          ),
        ),
      ),
    );
  }
}

// ─── Address Card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.selectionMode,
    this.isSelected = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = selectionMode ? isSelected : address.isDefault;
    final title = address.label.trim().isNotEmpty
        ? address.label.trim()
        : 'عنوان بدون اسم';
    final addressText = _addressLine();

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                _SelectionIndicator(selected: isSelected),
                const SizedBox(width: 12),
              ],
              _LabelBadge(title: title, highlighted: highlighted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          const _DefaultBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      addressText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (address.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.phone_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            address.phone.trim(),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!selectionMode) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: AppColors.secondary),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!address.isDefault)
                  _SetDefaultChip(onTap: onSetDefault)
                else
                  Row(
                    children: [
                      const Icon(
                        AppIcons.check_circle_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'العنوان الافتراضي',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                _IconAction(
                  icon: AppIcons.edit_outlined,
                  color: AppColors.accent,
                  bg: AppColors.secondary,
                  tooltip: 'تعديل',
                  onTap: onEdit,
                ),
                const SizedBox(width: 10),
                _IconAction(
                  icon: AppIcons.delete_outline_rounded,
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFCE9E9),
                  tooltip: 'حذف',
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(highlighted ? 23.5 : 22),
          gradient: highlighted ? AppColors.primaryGradient : null,
          color: highlighted ? null : AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: highlighted ? AppColors.shadowSoft : AppColors.shadowCard,
              blurRadius: highlighted ? 22 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: highlighted ? const EdgeInsets.all(1.6) : EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: card,
          ),
        ),
      ),
    );
  }

  String _addressLine() {
    final formatted = address.formattedAddress.trim();
    if (formatted.isNotEmpty) return formatted;
    final parts = [
      address.addressLine1.trim(),
      address.addressLine2?.trim() ?? '',
      address.city.trim(),
    ].where((e) => e.isNotEmpty);
    final joined = parts.join('، ');
    return joined.isNotEmpty ? joined : 'العنوان غير محدد';
  }
}

// ─── Card pieces ───────────────────────────────────────────────────────────────

class _LabelBadge extends StatelessWidget {
  final String title;
  final bool highlighted;

  const _LabelBadge({required this.title, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: highlighted ? AppColors.primaryGradient : null,
        color: highlighted ? null : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Icon(
        _labelIcon(title),
        color: highlighted ? AppColors.surface : AppColors.accent,
        size: 23,
      ),
    );
  }

  IconData _labelIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('بيت') || l.contains('منزل') || l.contains('home')) {
      return AppIcons.home_rounded;
    }
    if (l.contains('عمل') || l.contains('مكتب') || l.contains('work')) {
      return AppIcons.business_rounded;
    }
    return AppIcons.location_on_rounded;
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.star_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            'افتراضي',
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool selected;

  const _SelectionIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: selected ? AppColors.primaryGradient : null,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: AppColors.divider, width: 1.6),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(
              AppIcons.check_rounded,
              size: 15,
              color: AppColors.surface,
            )
          : null,
    );
  }
}

class _SetDefaultChip extends StatelessWidget {
  final VoidCallback onTap;

  const _SetDefaultChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.star_border_rounded,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'تعيين كافتراضي',
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
