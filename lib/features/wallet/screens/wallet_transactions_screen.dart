import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadTransactions();
    });
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<WalletProvider>().loadMoreTransactions();
    }
  }

  List<WalletTransactionModel> _filteredTransactions(
    List<WalletTransactionModel> all,
  ) {
    return all.where((tx) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          tx.typeLabel.toLowerCase().contains(_searchQuery) ||
          tx.transactionNumber.toLowerCase().contains(_searchQuery) ||
          (tx.providerLabel ?? '').toLowerCase().contains(_searchQuery) ||
          tx.amount.toString().contains(_searchQuery);

      final matchesType = _selectedType == null || tx.type == _selectedType;
      final matchesStatus =
          _selectedStatus == null || tx.status == _selectedStatus;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<WalletProvider>(
        builder: (context, wallet, _) {
          final filtered = _filteredTransactions(wallet.transactions);

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // HEADER
              SliverToBoxAdapter(child: _buildHeader(context)),

              // EMBEDDED SEARCH + FILTER ROW
              SliverToBoxAdapter(child: _buildSearchBar()),

              if (filtered.isEmpty && wallet.status == WalletStatus.loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primaryUltraLight.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.search_off_rounded,
                            size: 40,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'لا توجد نتائج'
                              : 'لا توجد حركات',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }
                        return _TransactionTile(
                          transaction: filtered[i],
                          isLast:
                              i == filtered.length - 1 &&
                              !wallet.loadingMoreTransactions,
                          isFirst: i == 0,
                        );
                      },
                      childCount:
                          filtered.length +
                          (wallet.loadingMoreTransactions &&
                                  _searchQuery.isEmpty
                              ? 1
                              : 0),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasActiveFilter = _selectedType != null || _selectedStatus != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28), // Fully circular
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'بحث ...',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: Icon(
                    AppIcons.search_rounded,
                    color: AppColors.textHint.withValues(alpha: 0.6),
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                          child: Icon(
                            AppIcons.close_rounded,
                            color: AppColors.textHint,
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter button
          GestureDetector(
            onTap: () => _showFilterSheet(context),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasActiveFilter ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(28), // Fully circular
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                AppIcons.tune_rounded,
                color: hasActiveFilter
                    ? AppColors.surface
                    : AppColors.textHint.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White overlap section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        AppIcons.arrow_back_rounded,
                        color: AppColors.surface,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'جميع الحركات',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      color: AppColors.surface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletFilterSheet(
        selectedType: _selectedType,
        selectedStatus: _selectedStatus,
        onApply: (type, status) {
          setState(() {
            _selectedType = type;
            _selectedStatus = status;
          });
          // Also load from server with filters
          context.read<WalletProvider>().loadTransactions(
            type: type,
            status: status,
          );
        },
      ),
    );
  }
}

// ==== MODERN TRANSACTION TILE ====
class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel transaction;
  final bool isLast;
  final bool isFirst;

  const _TransactionTile({
    required this.transaction,
    required this.isLast,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.isDeposit;
    final color = isDeposit ? AppColors.primary : AppColors.textPrimary;
    final iconBgColor = transaction.isWithdrawal
        ? AppColors.textPrimary
        : AppColors.secondary;
    final iconColor = transaction.isWithdrawal
        ? AppColors.surface
        : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(16) : Radius.zero,
          topRight: isFirst ? const Radius.circular(16) : Radius.zero,
          bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        boxShadow: isLast
            ? [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isDeposit
                            ? AppIcons.add_rounded
                            : AppIcons.remove_rounded,
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.typeLabel,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${transaction.providerLabel ?? transaction.provider ?? 'محفظة'} • ${_formatDate(DateTime.tryParse(transaction.createdAt) ?? DateTime.now())}',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isDeposit ? '+' : '-'} د.ل ${transaction.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (!transaction.isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              transaction.displayStatusText,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: transaction.isPending
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (transaction.isBankTransfer &&
                    transaction.bankTransferRejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      'سبب الرفض: ${transaction.bankTransferRejectionReason!}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isLast)
            Divider(
              color: AppColors.divider.withValues(alpha: 0.65),
              height: 1,
              indent: 84,
              endIndent: 24,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ==== WALLET FILTER SHEET (with callback pattern) ====
class _WalletFilterSheet extends StatefulWidget {
  final String? selectedType;
  final String? selectedStatus;
  final void Function(String? type, String? status) onApply;

  const _WalletFilterSheet({
    required this.selectedType,
    required this.selectedStatus,
    required this.onApply,
  });

  @override
  State<_WalletFilterSheet> createState() => _WalletFilterSheetState();
}

class _WalletFilterSheetState extends State<_WalletFilterSheet> {
  late String? _selectedType;
  late String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedStatus = widget.selectedStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'تصفية الحركات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'نوع الحركة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(
                'الكل',
                null,
                _selectedType,
                (v) => setState(() => _selectedType = v),
              ),
              _chip(
                'إيداع',
                'deposit',
                _selectedType,
                (v) => setState(() => _selectedType = v),
              ),
              _chip(
                'سحب',
                'withdrawal',
                _selectedType,
                (v) => setState(() => _selectedType = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'الحالة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(
                'الكل',
                null,
                _selectedStatus,
                (v) => setState(() => _selectedStatus = v),
              ),
              _chip(
                'مكتملة',
                'completed',
                _selectedStatus,
                (v) => setState(() => _selectedStatus = v),
              ),
              _chip(
                'معلقة',
                'pending',
                _selectedStatus,
                (v) => setState(() => _selectedStatus = v),
              ),
              _chip(
                'فاشلة',
                'failed',
                _selectedStatus,
                (v) => setState(() => _selectedStatus = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    widget.onApply(null, null);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Text(
                    'مسح الكل',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_selectedType, _selectedStatus);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'تطبيق الفلتر',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _chip(
    String label,
    String? value,
    String? selected,
    ValueChanged<String?> onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.surface : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
