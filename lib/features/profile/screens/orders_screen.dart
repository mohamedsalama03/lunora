import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/screens/order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'all';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 220) {
          final provider = context.read<OrdersProvider>();
          provider.loadMoreActiveOrders();
          provider.loadMorePastOrders();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrdersProvider>();
      provider.loadActiveOrders();
      provider.loadPastOrders();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();
    final allOrders =
        <int, OrderModel>{
          for (final order in provider.activeOrders) order.id: order,
          for (final order in provider.pastOrders) order.id: order,
        }.values.toList()..sort((a, b) {
          final aDate = DateTime.tryParse(a.timestamps?.createdAt ?? '');
          final bDate = DateTime.tryParse(b.timestamps?.createdAt ?? '');
          return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
        });
    final visibleOrders = _selectedFilter == 'all'
        ? allOrders
        : allOrders.where((order) => order.status == _selectedFilter).toList();
    final isLoading =
        provider.activeStatus == OrdersStatus.loading ||
        provider.pastStatus == OrdersStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            _OrdersHeader(
              selectedFilter: _selectedFilter,
              orders: allOrders,
              onFilterChanged: (value) =>
                  setState(() => _selectedFilter = value),
            ),
            Expanded(
              child: isLoading && allOrders.isEmpty
                  ? const _OrdersLoadingState()
                  : visibleOrders.isEmpty
                  ? const _EmptyState(
                      message: 'لا توجد طلبات في هذه الحالة',
                      subtitle: 'يمكنك اختيار حالة أخرى من شريط الفلاتر.',
                      icon: AppIcons.inbox_rounded,
                    )
                  : _OrdersList(
                      controller: _scrollController,
                      orders: visibleOrders,
                      isLoadingMore:
                          provider.loadingMoreActive ||
                          provider.loadingMorePast,
                      onRefresh: () async {
                        await Future.wait([
                          provider.loadActiveOrders(),
                          provider.loadPastOrders(),
                        ]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({
    required this.selectedFilter,
    required this.orders,
    required this.onFilterChanged,
  });

  final String selectedFilter;
  final List<OrderModel> orders;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    const filters = <(String, String)>[
      ('all', 'الكل'),
      ('pending', 'قيد المراجعة'),
      ('processing', 'جاري التجهيز'),
      ('shipped', 'تم الشحن'),
      ('delivered', 'مكتمل'),
      ('cancelled', 'ملغي'),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(24, topPad + 12, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.75)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: AppIcons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'طلباتي',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CircleButton(
                icon: AppIcons.search_rounded,
                onTap: () => showSearch<void>(
                  context: context,
                  delegate: _OrdersSearchDelegate(orders),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final filter = filters[index];
                final count = filter.$1 == 'all'
                    ? orders.length
                    : orders.where((order) => order.status == filter.$1).length;
                final selected = selectedFilter == filter.$1;
                return _FilterPill(
                  label: filter.$2,
                  count: count,
                  selected: selected,
                  onTap: () => onFilterChanged(filter.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            '$label  ($count)',
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.surface : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersSearchDelegate extends SearchDelegate<void> {
  _OrdersSearchDelegate(this.orders);

  final List<OrderModel> orders;

  @override
  String get searchFieldLabel => 'ابحثي برقم الطلب أو اسم المنتج';

  @override
  TextStyle? get searchFieldStyle => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(AppIcons.close_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(AppIcons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final normalizedQuery = query.trim().toLowerCase();
    final matches = orders.where((order) {
      if (normalizedQuery.isEmpty) return true;
      return order.orderNumber.toLowerCase().contains(normalizedQuery) ||
          order.items.any(
            (item) => item.productName.toLowerCase().contains(normalizedQuery),
          );
    }).toList();

    if (matches.isEmpty) {
      return const _EmptyState(
        message: 'لا توجد نتائج',
        subtitle: 'جرّبي البحث برقم طلب أو اسم منتج آخر.',
        icon: AppIcons.search_off_rounded,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        itemCount: matches.length,
        itemBuilder: (_, index) => _OrderCard(order: matches[index]),
      ),
    );
  }
}

// Kept for compatibility with the previous compact header variant.
// ignore: unused_element
class _OrdersStat extends StatelessWidget {
  const _OrdersStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SupportButton extends StatelessWidget {
  const _SupportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: const Icon(
            AppIcons.headset_mic_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ActiveOrdersTab extends StatefulWidget {
  const _ActiveOrdersTab();

  @override
  State<_ActiveOrdersTab> createState() => _ActiveOrdersTabState();
}

class _ActiveOrdersTabState extends State<_ActiveOrdersTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          context.read<OrdersProvider>().loadMoreActiveOrders();
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    if (provider.activeStatus == OrdersStatus.loading) {
      return const _OrdersLoadingState();
    }

    if (provider.activeStatus == OrdersStatus.error) {
      return _ErrorState(
        message: provider.errorMessage ?? 'تعذر تحميل الطلبات',
        onRetry: provider.loadActiveOrders,
      );
    }

    if (provider.activeOrders.isEmpty) {
      return const _EmptyState(
        message: 'لا توجد طلبات حالية',
        subtitle: 'ستظهر هنا الطلبات التي تنتظر التجهيز أو الشحن.',
        icon: AppIcons.inbox_rounded,
      );
    }

    return _OrdersList(
      controller: _scrollController,
      orders: provider.activeOrders,
      isLoadingMore: provider.loadingMoreActive,
      onRefresh: provider.loadActiveOrders,
      title: 'طلبات قيد المتابعة',
      subtitle: 'تابعي رحلة الطلب حتى يصل إليك',
      icon: AppIcons.local_shipping_rounded,
    );
  }
}

class _PastOrdersTab extends StatefulWidget {
  const _PastOrdersTab();

  @override
  State<_PastOrdersTab> createState() => _PastOrdersTabState();
}

class _PastOrdersTabState extends State<_PastOrdersTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          context.read<OrdersProvider>().loadMorePastOrders();
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();

    if (provider.pastStatus == OrdersStatus.loading) {
      return const _OrdersLoadingState();
    }

    if (provider.pastStatus == OrdersStatus.error) {
      return _ErrorState(
        message: provider.errorMessage ?? 'تعذر تحميل الطلبات',
        onRetry: provider.loadPastOrders,
      );
    }

    if (provider.pastOrders.isEmpty) {
      return const _EmptyState(
        message: 'لا يوجد سجل سابق',
        subtitle: 'ستظهر هنا الطلبات المكتملة أو الملغاة.',
        icon: AppIcons.history_rounded,
      );
    }

    return _OrdersList(
      controller: _scrollController,
      orders: provider.pastOrders,
      isLoadingMore: provider.loadingMorePast,
      onRefresh: provider.loadPastOrders,
      title: 'سجل طلباتك',
      subtitle: 'طلباتك المكتملة والملغاة في مكان واحد',
      icon: AppIcons.history_rounded,
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.controller,
    required this.orders,
    required this.isLoadingMore,
    required this.onRefresh,
    this.title,
    this.subtitle,
    this.icon,
  });

  final ScrollController controller;
  final List<OrderModel> orders;
  final bool isLoadingMore;
  final Future<void> Function() onRefresh;
  final String? title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: orders.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == orders.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.4,
                ),
              ),
            );
          }

          return _OrderCard(order: orders[index]);
        },
      ),
    );
  }
}

// ignore: unused_element
class _OrdersListIntro extends StatelessWidget {
  const _OrdersListIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  Color get _statusColor {
    switch (order.status) {
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFF3B82C4);
      case 'processing':
        return const Color(0xFFF59E0B);
      case 'shipped':
        return const Color(0xFF3B82C4);
      case 'cancelled':
      case 'refunded':
        return const Color(0xFFDC2626);
      default:
        return AppColors.textHint;
    }
  }

  String get _formattedDate {
    final rawDate = order.timestamps?.createdAt;
    if (rawDate == null || rawDate.isEmpty) return '';

    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return '';

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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderNumber: order.orderNumber,
          initialOrder: order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = order.statusLabel.isNotEmpty
        ? order.statusLabel
        : order.status;
    final total = order.totals?.total ?? order.payment.amount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(context),
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.85),
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'طلب ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '#${order.orderNumber}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_formattedDate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formattedDate,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusChip(label: statusLabel, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _OrderProductsPreview(order: order)),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 82,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'الإجمالي',
                              textAlign: TextAlign.left,
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                '${total.toStringAsFixed(0)} د.ل',
                                maxLines: 1,
                                style: GoogleFonts.cairo(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (order.shipping != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          AppIcons.location_on_outlined,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [
                              order.shipping!.city,
                              order.shipping!.addressLine1,
                            ].where((value) => value.isNotEmpty).join('، '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 43,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                AppIcons.visibility_outlined,
                                size: 17,
                                color: AppColors.surface,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'عرض التفاصيل',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 43,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                AppIcons.local_shipping_rounded,
                                size: 17,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'تتبع الطلب',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.payment.awaitingGatewayNotification) ...[
                    const SizedBox(height: 12),
                    _AwaitingPaymentNote(color: _statusColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _OrderJourney extends StatelessWidget {
  const _OrderJourney({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final step = progress < 0.4
        ? 1
        : progress < 0.75
        ? 2
        : 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.local_shipping_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'الخطوة $step من 3',
                style: GoogleFonts.cairo(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProductsPreview extends StatelessWidget {
  const _OrderProductsPreview({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final previewItems = order.items.take(3).toList();
    final extraCount = order.items.length - previewItems.length;
    final avatarCount = previewItems.length + (extraCount > 0 ? 1 : 0);
    final firstProductName = order.items.isNotEmpty
        ? order.items.first.productName
        : 'منتجات الطلب';

    return Row(
      children: [
        if (previewItems.isNotEmpty)
          SizedBox(
            width: 48 + ((avatarCount - 1) * 26),
            height: 48,
            child: Stack(
              children: [
                for (var index = 0; index < previewItems.length; index++)
                  Positioned(
                    right: index * 26,
                    child: _OrderProductThumb(item: previewItems[index]),
                  ),
                if (extraCount > 0)
                  Positioned(
                    right: previewItems.length * 26,
                    child: _ThumbCountBubble(count: extraCount),
                  ),
              ],
            ),
          )
        else
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.shopping_bag_outlined,
              size: 21,
              color: AppColors.accent,
            ),
          ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstProductName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _itemsLabel(order.itemsQty),
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _itemsLabel(int count) {
    if (count == 1) return 'منتج واحد';
    if (count == 2) return 'منتجان';
    if (count >= 3 && count <= 10) return '$count منتجات';
    return '$count منتجاً';
  }
}

class _ThumbCountBubble extends StatelessWidget {
  const _ThumbCountBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text(
        '+$count',
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DetailsPill extends StatelessWidget {
  const _DetailsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'التفاصيل',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.surface,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            AppIcons.arrow_forward_rounded,
            size: 15,
            color: AppColors.surface,
          ),
        ],
      ),
    );
  }
}

class _OrderProductThumb extends StatelessWidget {
  const _OrderProductThumb({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim() ?? '';

    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _OrderThumbFallback(),
              )
            : const _OrderThumbFallback(),
      ),
    );
  }
}

class _OrderThumbFallback extends StatelessWidget {
  const _OrderThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.secondary,
      child: Icon(
        AppIcons.shopping_bag_outlined,
        size: 18,
        color: AppColors.accent,
      ),
    );
  }
}

class _AwaitingPaymentNote extends StatelessWidget {
  const _AwaitingPaymentNote({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(AppIcons.hourglass_bottom_rounded, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'بانتظار تأكيد بوابة الدفع',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.6,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.subtitle,
    required this.icon,
  });

  final String message;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w600,
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
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.wifi_off_rounded,
                color: AppColors.textHint,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(AppIcons.refresh_rounded, size: 18),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(
                  fontSize: 14,
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
