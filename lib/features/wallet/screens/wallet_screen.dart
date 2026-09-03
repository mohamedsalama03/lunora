import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import 'wallet_topup_sheet.dart';
import 'wallet_transactions_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<WalletProvider>(
        builder: (context, wallet, _) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => wallet.loadSummary(silent: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildPageHeader(context)),
                if (wallet.status == WalletStatus.loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (wallet.status == WalletStatus.error)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildError(wallet),
                  )
                else if (wallet.summary != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: _WalletBalanceCard(summary: wallet.summary!),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: _buildQuickActions(context, wallet.summary!),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
                      child: _buildTransactionsHeader(context),
                    ),
                  ),
                  if (wallet.summary!.recentTransactions.isEmpty)
                    const SliverToBoxAdapter(child: _EmptyTransactions())
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _TransactionsCard(
                          transactions: wallet.summary!.recentTransactions,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ] else
                  const SliverFillRemaining(hasScrollBody: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Row(
          children: [
            _RoundIconButton(
              icon: AppIcons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'محفظتي',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'رصيدك وحركاتك في مكان واحد',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                AppIcons.account_balance_wallet_rounded,
                size: 21,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WalletSummaryModel summary) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: AppIcons.add_rounded,
            label: 'شحن المحفظة',
            isPrimary: true,
            enabled: summary.topUpProviders.isNotEmpty,
            onTap: () => _openTopUp(context, summary.topUpProviders),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: AppIcons.receipt_long_outlined,
            label: 'كشف الحساب',
            onTap: () => _openTransactions(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'آخر الحركات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _openTransactions(context),
          child: const Text('عرض الكل'),
        ),
      ],
    );
  }

  Widget _buildError(WalletProvider wallet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.wifi_off_rounded,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              wallet.errorMessage ?? 'تعذر تحميل المحفظة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => wallet.loadSummary(),
              icon: const Icon(AppIcons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTransactions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletTransactionsScreen()),
    );
  }

  Future<void> _openTopUp(
    BuildContext context,
    List<TopUpProviderModel> providers,
  ) async {
    if (providers.isEmpty) return;

    if (providers.length == 1) {
      _showTopUpSheet(context, providers.first);
      return;
    }

    final provider = await showModalBottomSheet<TopUpProviderModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProviderPicker(providers: providers),
    );

    if (provider != null && context.mounted) {
      _showTopUpSheet(context, provider);
    }
  }

  void _showTopUpSheet(BuildContext context, TopUpProviderModel provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletTopUpSheet(provider: provider),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final WalletSummaryModel summary;

  const _WalletBalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowFloat,
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -52,
              top: -78,
              child: _DecorativeCircle(
                size: 190,
                color: AppColors.surface.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              right: -38,
              bottom: -76,
              child: _DecorativeCircle(
                size: 180,
                color: AppColors.neutral.withValues(alpha: 0.18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.surface.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Icon(
                          AppIcons.account_balance_wallet_outlined,
                          color: AppColors.surface,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'LUNORA WALLET',
                        style: GoogleFonts.cairo(
                          color: AppColors.surface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      _WalletStatus(enabled: summary.walletPaymentEnabled),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'الرصيد المتاح',
                    style: GoogleFonts.cairo(
                      color: AppColors.surface.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          summary.balance.toStringAsFixed(2),
                          style: GoogleFonts.cairo(
                            color: AppColors.surface,
                            fontSize: 38,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _currencyLabel(summary.currency),
                            style: GoogleFonts.cairo(
                              color: AppColors.surface.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        AppIcons.verified_user_rounded,
                        size: 15,
                        color: AppColors.surface.withValues(alpha: 0.76),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'دفع آمن وسريع مع LUNORA',
                        style: GoogleFonts.cairo(
                          color: AppColors.surface.withValues(alpha: 0.72),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
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

  String _currencyLabel(String currency) {
    final normalized = currency.trim().toUpperCase();
    return normalized == 'LYD' ? 'د.ل' : currency;
  }
}

class _WalletStatus extends StatelessWidget {
  final bool enabled;

  const _WalletStatus({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFBFE4D0)
                  : const Color(0xFFFFD7A0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            enabled ? 'مفعّلة' : 'غير مفعّلة',
            style: GoogleFonts.cairo(
              color: AppColors.surface,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool enabled;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? AppColors.surface : AppColors.textPrimary;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: isPrimary ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isPrimary
                  ? null
                  : Border.all(color: AppColors.divider.withValues(alpha: 0.9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
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

class _TransactionsCard extends StatelessWidget {
  final List<WalletTransactionModel> transactions;

  const _TransactionsCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionTile(transaction: transactions[index]),
            if (index != transactions.length - 1)
              Divider(
                height: 1,
                indent: 76,
                endIndent: 18,
                color: AppColors.divider.withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.isDeposit;
    final date = DateTime.tryParse(transaction.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDeposit ? AppColors.secondary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isDeposit
                  ? AppIcons.arrow_downward_rounded
                  : AppIcons.arrow_upward_rounded,
              size: 20,
              color: isDeposit ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _transactionDetails(transaction, date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} د.ل',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDeposit ? AppColors.success : AppColors.textPrimary,
                ),
              ),
              if (!transaction.isCompleted) ...[
                const SizedBox(height: 3),
                Text(
                  transaction.displayStatusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: transaction.isPending
                        ? AppColors.warning
                        : AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _transactionDetails(
    WalletTransactionModel transaction,
    DateTime? date,
  ) {
    final provider =
        transaction.providerLabel ?? transaction.provider ?? 'المحفظة';
    if (date == null) return provider;
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return '$provider  •  $formatted';
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.receipt_long_outlined,
                size: 27,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد حركات بعد',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ستظهر عمليات الشحن والدفع هنا',
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  final List<TopUpProviderModel> providers;

  const _ProviderPicker({required this.providers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'اختاري طريقة الشحن',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            for (final provider in providers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    onTap: () => Navigator.pop(context, provider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        provider.isBankTransfer
                            ? AppIcons.account_balance_rounded
                            : AppIcons.credit_card_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      provider.label,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(
                      AppIcons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
