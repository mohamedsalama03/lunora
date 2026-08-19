import 'dart:async';

import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  final OrderModel? initialOrder;
  final bool showSuccessBanner;

  const OrderDetailScreen({
    super.key,
    required this.orderNumber,
    this.initialOrder,
    this.showSuccessBanner = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh());
      });
    } else {
      _fetchOrder();
    }
  }

  Future<void> _fetchOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final provider = context.read<OrdersProvider>();
    final order = await provider.refreshOrder(widget.orderNumber);
    if (!mounted) return;
    setState(() {
      _order = order;
      _isLoading = false;
      _error = order == null ? 'تعذر تحميل تفاصيل الطلب' : null;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final provider = context.read<OrdersProvider>();
    final order = await provider.refreshOrder(widget.orderNumber);
    if (!mounted) return;
    setState(() {
      if (order != null) _order = order;
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(isRefreshing: _isRefreshing, onRefresh: _refresh),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _error != null
                    ? _ErrorState(message: _error!, onRetry: _fetchOrder)
                    : _order == null
                    ? const SizedBox()
                    : _OrderDetailBody(
                        order: _order!,
                        showSuccessBanner: widget.showSuccessBanner,
                        onRefresh: _refresh,
                        isRefreshing: _isRefreshing,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _TopBar({required this.isRefreshing, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          _CircleActionButton(
            icon: AppIcons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل الطلب',
                  style: GoogleFonts.cairo(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'كل ما يخص طلبك في مكان واحد',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CircleActionButton(
            icon: AppIcons.refresh_rounded,
            onTap: isRefreshing ? null : onRefresh,
            isLoading: isRefreshing,
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _CircleActionButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.divider),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  final OrderModel order;
  final bool showSuccessBanner;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const _OrderDetailBody({
    required this.order,
    required this.showSuccessBanner,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.select<OrdersProvider, String>(
      (provider) => provider.lookups?.currency ?? 'LYD',
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          _OrderHero(order: order, currency: currency),
          if (showSuccessBanner) ...[
            const SizedBox(height: 16),
            const _SuccessBanner(),
          ],
          if (order.payment.awaitingGatewayNotification) ...[
            const SizedBox(height: 16),
            _AwaitingGatewayBanner(
              onRefresh: onRefresh,
              isRefreshing: isRefreshing,
            ),
          ],
          const SizedBox(height: 16),
          _OrderProgressTimeline(order: order),
          const SizedBox(height: 16),
          _ProductsCard(
            items: order.items,
            itemsQty: order.itemsQty,
            currency: currency,
          ),
          if (order.shipping != null) ...[
            const SizedBox(height: 16),
            _ShippingCard(shipping: order.shipping!),
          ],
          const SizedBox(height: 16),
          _PaymentSummaryCard(order: order, currency: currency),
          if (order.timestamps != null) ...[
            const SizedBox(height: 16),
            _DatesCard(timestamps: order.timestamps!),
          ],
        ],
      ),
    );
  }
}

class _OrderHero extends StatelessWidget {
  final OrderModel order;
  final String currency;

  const _OrderHero({required this.order, required this.currency});

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(order.timestamps?.createdAt);
    final total = order.totals?.total ?? order.payment.amount;
    final statusLabel = order.statusLabel.isNotEmpty
        ? order.statusLabel
        : _fallbackStatusLabel(order.status);
    final statusColor = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  AppIcons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                'ملخص الطلب',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _HeroStatusPill(label: statusLabel, dotColor: statusColor),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'رقم الطلب',
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '#${order.orderNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي',
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _MoneyText(
                        amount: total,
                        currency: currency,
                        style: GoogleFonts.cairo(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (createdAt.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'تاريخ الطلب',
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusPill extends StatelessWidget {
  final String label;
  final Color dotColor;

  const _HeroStatusPill({required this.label, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProgressTimeline extends StatelessWidget {
  final OrderModel order;

  const _OrderProgressTimeline({required this.order});

  int get _activeIndex {
    switch (order.status) {
      case 'processing':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      case 'cancelled':
      case 'refunded':
      case 'pending':
      default:
        return 0;
    }
  }

  bool get _isCancelled =>
      order.status == 'cancelled' || order.status == 'refunded';

  @override
  Widget build(BuildContext context) {
    const steps = [
      _TimelineStepData('تم التأكيد', AppIcons.check_rounded),
      _TimelineStepData('قيد التجهيز', AppIcons.inventory_2_outlined),
      _TimelineStepData('تم الشحن', AppIcons.local_shipping_rounded),
      _TimelineStepData('تم التوصيل', AppIcons.check_circle_outline_rounded),
    ];

    return _SoftSection(
      title: 'رحلة الطلب',
      icon: AppIcons.local_shipping_rounded,
      child: SizedBox(
        height: 84,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 18,
              left: 40,
              right: 40,
              child: Row(
                textDirection: TextDirection.rtl,
                children: List.generate(steps.length - 1, (index) {
                  final isDone = _activeIndex > index && !_isCancelled;
                  return Expanded(
                    child: Container(
                      height: 2.2,
                      color: isDone
                          ? AppColors.primary.withValues(alpha: 0.75)
                          : const Color(0xFFE6D7DA),
                    ),
                  );
                }),
              ),
            ),
            Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (index) {
                return Expanded(
                  child: _TimelineStep(
                    data: steps[index],
                    index: index,
                    activeIndex: _activeIndex,
                    isCancelled: _isCancelled,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStepData {
  final String label;
  final IconData icon;

  const _TimelineStepData(this.label, this.icon);
}

class _TimelineStep extends StatelessWidget {
  final _TimelineStepData data;
  final int index;
  final int activeIndex;
  final bool isCancelled;

  const _TimelineStep({
    required this.data,
    required this.index,
    required this.activeIndex,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeIndex;
    final isDone = index < activeIndex;
    final isEnabled = (isActive || isDone) && !isCancelled;
    final activeColor = isCancelled && isActive
        ? const Color(0xFFDC2626)
        : AppColors.primary;
    final circleColor = isEnabled || (isCancelled && isActive)
        ? activeColor
        : Colors.white;
    final borderColor = isEnabled || (isCancelled && isActive)
        ? activeColor
        : const Color(0xFFE6D7DA);
    final iconColor = isEnabled || (isCancelled && isActive)
        ? Colors.white
        : const Color(0xFFC9B3B7);

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCancelled && isActive ? AppIcons.close_rounded : data.icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            height: 1.25,
            fontWeight: isEnabled ? FontWeight.w900 : FontWeight.w700,
            color: isEnabled ? AppColors.textPrimary : const Color(0xFF9E868B),
          ),
        ),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: AppIcons.check_circle_rounded,
      iconColor: const Color(0xFF16A34A),
      background: const Color(0xFFEAF8EF),
      text: 'تم تأكيد الدفع بنجاح، وطلبك الآن قيد المعالجة.',
    );
  }
}

class _AwaitingGatewayBanner extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  const _AwaitingGatewayBanner({
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: AppIcons.hourglass_bottom_rounded,
      iconColor: const Color(0xFFF59E0B),
      background: const Color(0xFFFFF7E6),
      text: 'بانتظار التأكيد النهائي من بوابة الدفع.',
      trailing: TextButton(
        onPressed: isRefreshing ? null : onRefresh,
        child: Text(
          'تحديث',
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String text;
  final Widget? trailing;

  const _NoticeCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  final OrderShipping shipping;

  const _ShippingCard({required this.shipping});

  @override
  Widget build(BuildContext context) {
    final addressLines =
        [
              shipping.addressLine1,
              shipping.addressLine2,
              shipping.city,
              shipping.state,
              shipping.country,
            ]
            .whereType<String>()
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    return _SoftSection(
      title: 'عنوان الشحن',
      icon: AppIcons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailLine(
            text: shipping.fullName.isNotEmpty ? shipping.fullName : 'غير محدد',
            weight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          if (shipping.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shipping.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (addressLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailLine(text: addressLines.join('، ')),
          ],
        ],
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  final List<OrderItem> items;
  final int itemsQty;
  final String currency;

  const _ProductsCard({
    required this.items,
    required this.itemsQty,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftSection(
      title: 'المنتجات${itemsQty > 0 ? ' ($itemsQty)' : ''}',
      icon: AppIcons.shopping_bag_outlined,
      child: items.isEmpty
          ? _DetailLine(text: 'لا توجد منتجات في هذا الطلب')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ProductRow(item: items[i], currency: currency),
                  if (i != items.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: const Color(0xFFEFE3E6).withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final OrderItem item;
  final String currency;

  const _ProductRow({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProductImage(item: item),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.productName,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (item.variantInfo != null &&
                  item.variantInfo!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.variantInfo!,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 38,
          child: Text(
            '×${item.quantity}',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _MoneyText(
              amount: item.totalPrice,
              currency: currency,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final OrderItem item;

  const _ProductImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 58,
        height: 58,
        color: const Color(0xFFF7ECEE),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ProductFallbackIcon(),
              )
            : const _ProductFallbackIcon(),
      ),
    );
  }
}

class _ProductFallbackIcon extends StatelessWidget {
  const _ProductFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      AppIcons.inventory_2_rounded,
      color: AppColors.primary,
      size: 28,
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final OrderModel order;
  final String currency;

  const _PaymentSummaryCard({required this.order, required this.currency});

  @override
  Widget build(BuildContext context) {
    final totals = order.totals;
    final totalAmount = totals?.total ?? order.payment.amount;

    return _SoftSection(
      title: 'ملخص الدفع',
      icon: AppIcons.credit_card_rounded,
      child: Column(
        children: [
          _SummaryRow(
            label: 'طريقة الدفع',
            value: order.payment.methodLabel.isNotEmpty
                ? order.payment.methodLabel
                : order.payment.method,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'حالة الدفع',
            value: order.payment.statusLabel.isNotEmpty
                ? order.payment.statusLabel
                : order.payment.status,
            valueColor: _paymentStatusColor(order.payment.status),
          ),
          if (totals != null) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'الشحن',
              value: '',
              moneyAmount: totals.shippingCost,
              currency: currency,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: const Color(0xFFEFE3E6)),
          ),
          _SummaryRow(
            label: 'الإجمالي',
            value: '',
            moneyAmount: totalAmount,
            currency: currency,
            isTotal: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  final OrderTimestamps timestamps;

  const _DatesCard({required this.timestamps});

  @override
  Widget build(BuildContext context) {
    return _SoftSection(
      title: 'تواريخ الطلب',
      icon: AppIcons.schedule_rounded,
      child: Column(
        children: [
          _SummaryRow(
            label: 'تاريخ الطلب',
            value: _formatDate(timestamps.createdAt),
          ),
          if (timestamps.shippedAt != null &&
              timestamps.shippedAt!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'تاريخ الشحن',
              value: _formatDate(timestamps.shippedAt),
            ),
          ],
          if (timestamps.deliveredAt != null &&
              timestamps.deliveredAt!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'تاريخ التسليم',
              value: _formatDate(timestamps.deliveredAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoftSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SoftSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider.withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String text;
  final FontWeight weight;
  final Color color;

  const _DetailLine({
    required this.text,
    this.weight = FontWeight.w700,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.start,
      style: GoogleFonts.cairo(
        fontSize: 14,
        height: 1.55,
        fontWeight: weight,
        color: color,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;
  final double? moneyAmount;
  final String? currency;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
    this.moneyAmount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: moneyAmount != null
                ? _MoneyText(
                    amount: moneyAmount!,
                    currency: currency ?? 'LYD',
                    style: GoogleFonts.cairo(
                      fontSize: isTotal ? 17 : 13,
                      fontWeight: isTotal ? FontWeight.w900 : FontWeight.w800,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.left,
                    maxLines: isTotal ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: isTotal ? 17 : 13,
                      fontWeight: isTotal ? FontWeight.w900 : FontWeight.w800,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.error_outline_rounded,
              color: AppColors.textHint,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'delivered':
      return const Color(0xFF16A34A);
    case 'pending':
    case 'processing':
      return const Color(0xFFF59E0B);
    case 'shipped':
      return AppColors.primary;
    case 'cancelled':
    case 'refunded':
      return const Color(0xFFDC2626);
    default:
      return AppColors.textHint;
  }
}

Color _paymentStatusColor(String status) {
  switch (status) {
    case 'paid':
      return const Color(0xFF16A34A);
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'failed':
    case 'refunded':
      return const Color(0xFFDC2626);
    default:
      return AppColors.textHint;
  }
}

String _fallbackStatusLabel(String status) {
  switch (status) {
    case 'delivered':
      return 'تم التوصيل';
    case 'processing':
      return 'قيد التجهيز';
    case 'shipped':
      return 'تم الشحن';
    case 'cancelled':
      return 'ملغي';
    case 'refunded':
      return 'مسترجع';
    case 'pending':
    default:
      return 'قيد التأكيد';
  }
}

String _formatDate(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return iso;
  }
}

class _MoneyText extends StatelessWidget {
  const _MoneyText({
    required this.amount,
    required this.currency,
    required this.style,
  });

  final double amount;
  final String currency;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final amountLabel = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final currencyLabel = currency.trim().toUpperCase() == 'LYD'
        ? 'د.ل'
        : currency.trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Text(currencyLabel, style: style),
        const SizedBox(width: 4),
        Text(amountLabel, style: style),
      ],
    );
  }
}
