import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/bank_transfer_details.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import 'wallet_moamalat_screen.dart';

class WalletTopUpSheet extends StatefulWidget {
  final TopUpProviderModel provider;

  const WalletTopUpSheet({super.key, required this.provider});

  @override
  State<WalletTopUpSheet> createState() => _WalletTopUpSheetState();
}

class _WalletTopUpSheetState extends State<WalletTopUpSheet> {
  static const List<double> _quickAmounts = <double>[50, 100, 250, 500];
  static const int _maxReceiptSizeBytes = 5 * 1024 * 1024;

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _receiptPath;
  String? _receiptName;
  int? _receiptSizeBytes;
  double? _selectedQuickAmount;

  bool get _isBankTransfer => widget.provider.isBankTransfer;
  bool get _isMoamalat => widget.provider.isMoamalat;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.path == null || file.path!.trim().isEmpty) {
      _showErrorSnack(context, 'تعذر الوصول إلى الملف المحدد');
      return;
    }

    if (file.size > _maxReceiptSizeBytes) {
      _showErrorSnack(context, 'حجم الإيصال يجب ألا يتجاوز 5 ميجابايت');
      return;
    }

    setState(() {
      _receiptPath = file.path!;
      _receiptName = file.name;
      _receiptSizeBytes = file.size;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_isBankTransfer && _receiptPath == null) {
      _showErrorSnack(context, 'يرجى إرفاق إيصال التحويل قبل الإرسال');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      return;
    }

    setState(() => _isLoading = true);

    final wallet = context.read<WalletProvider>();
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final notes = _cleanValue(_notesController.text);

    if (_isBankTransfer) {
      final success = await wallet.submitBankTransferTopUp(
        amount: amount,
        receiptPath: _receiptPath!,
        receiptFileName: _receiptName,
        notes: notes,
      );

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
        _showSuccessSnack(
          rootNavigator.context,
          'تم إرسال طلب التحويل البنكي وهو الآن بانتظار المراجعة',
        );
      } else {
        _showErrorSnack(
          context,
          wallet.errorMessage ?? 'تعذر إرسال طلب التحويل البنكي',
        );
      }
      return;
    }

    if (!_isMoamalat) {
      final success = await wallet.topUpDirect(
        amount: amount,
        provider: widget.provider.key,
        notes: notes,
      );

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (success) {
        _syncWalletBalanceAcrossApp(wallet.summary?.balance);
        Navigator.pop(context);
        _showSuccessSnack(rootNavigator.context, 'تم شحن المحفظة بنجاح');
      } else {
        _showErrorSnack(context, wallet.errorMessage ?? 'فشلت عملية الشحن');
      }
      return;
    }

    final result = await wallet.prepareMoamalat(amount: amount);
    if (!mounted) {
      return;
    }

    if (result == null) {
      setState(() => _isLoading = false);
      _showErrorSnack(context, wallet.errorMessage ?? 'فشل تجهيز بوابة الدفع');
      return;
    }

    Navigator.pop(context);
    await rootNavigator.push(
      MaterialPageRoute(
        builder: (_) => WalletMoamalatScreen(prepareResult: result),
      ),
    );
  }

  void _showSuccessSnack(BuildContext context, String message) {
    AppNotifications.showSuccess(context, message);
  }

  void _showErrorSnack(BuildContext context, String message) {
    AppNotifications.showError(context, message);
  }

  void _showCopiedSnack(String label) {
    AppNotifications.showSuccess(context, 'تم نسخ $label');
  }

  void _syncWalletBalanceAcrossApp(double? balance) {
    if (balance == null) {
      return;
    }

    context.read<OrdersProvider>().updateLookupsWalletBalance(balance);
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      authProvider.updateUser(user.copyWith(walletBalance: balance));
    }
  }

  String? _cleanValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: true,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SheetHeader(
                  provider: widget.provider,
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 22),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'كم تريدين أن تشحني؟',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'اختاري مبلغًا سريعًا أو أدخلي مبلغًا آخر',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onFieldSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        textAlign: TextAlign.start,
                        onChanged: (String value) {
                          final amount = double.tryParse(value.trim());
                          final isQuick = _quickAmounts.contains(amount);
                          final nextSelection = isQuick ? amount : null;
                          if (nextSelection != _selectedQuickAmount) {
                            setState(
                              () => _selectedQuickAmount = nextSelection,
                            );
                          }
                        },
                        style: GoogleFonts.cairo(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: GoogleFonts.cairo(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHint.withValues(alpha: 0.35),
                          ),
                          suffixIcon: Container(
                            width: 62,
                            alignment: Alignment.center,
                            child: Text(
                              'د.ل',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال المبلغ';
                          }

                          final number = double.tryParse(value.trim());
                          if (number == null || number < 1) {
                            return 'المبلغ يجب أن يكون 1 على الأقل';
                          }
                          if (number > 50000) {
                            return 'المبلغ لا يجب أن يتجاوز 50,000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _QuickAmounts(
                        values: _quickAmounts,
                        selectedValue: _selectedQuickAmount,
                        onSelect: (double value) {
                          setState(() => _selectedQuickAmount = value);
                          _amountController.text = value.toStringAsFixed(0);
                        },
                      ),
                    ],
                  ),
                ),
                if (_isMoamalat) ...<Widget>[
                  const SizedBox(height: 14),
                  _buildMoamalatGuidance(),
                ],
                if (_isBankTransfer) ...<Widget>[
                  const SizedBox(height: 14),
                  _buildBankTransferGuidance(),
                  const SizedBox(height: 14),
                  _buildReceiptPicker(),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: _LabeledField(
                      title: 'ملاحظات',
                      hint: 'اختياري',
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: _inputDecoration(
                          hintText: 'مثال: تم التحويل من تطبيق المصرف',
                          icon: AppIcons.notes_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.55,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                _isBankTransfer
                                    ? AppIcons.upload_file_rounded
                                    : _isMoamalat
                                    ? AppIcons.payment_rounded
                                    : AppIcons.bolt_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _isBankTransfer
                                      ? 'إرسال طلب التحويل'
                                      : _isMoamalat
                                      ? 'المتابعة للدفع'
                                      : 'شحن المحفظة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _isBankTransfer
                        ? 'يضاف الرصيد بعد مراجعة الإيصال واعتماد التحويل'
                        : 'الدفع محمي عبر بوابة معاملات',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
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

  Widget _buildBankTransferGuidance() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle(
            icon: AppIcons.account_balance_rounded,
            title: 'بيانات التحويل البنكي',
            subtitle: 'حوّلي المبلغ إلى الحساب التالي',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: <Widget>[
                _BankDetailRow(
                  label: 'اسم المصرف',
                  value: kDefaultBankTransferDetails.bankName,
                  onCopy: _showCopiedSnack,
                ),
                _BankDetailRow(
                  label: 'صاحب الحساب',
                  value: kDefaultBankTransferDetails.accountHolder,
                  onCopy: _showCopiedSnack,
                ),
                _BankDetailRow(
                  label: 'رقم الحساب',
                  value: kDefaultBankTransferDetails.accountNumber,
                  onCopy: _showCopiedSnack,
                ),
                _BankDetailRow(
                  label: 'IBAN',
                  value: kDefaultBankTransferDetails.iban,
                  onCopy: _showCopiedSnack,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.blush.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  AppIcons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'بعد إتمام التحويل، أرفقي صورة الإيصال ليتم اعتماد الرصيد.',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoamalatGuidance() {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(
            icon: AppIcons.credit_card_rounded,
            title: 'الدفع عبر معاملات',
            subtitle: 'بوابة دفع إلكترونية آمنة',
          ),
          SizedBox(height: 18),
          _PaymentFeature(
            icon: AppIcons.arrow_outward_rounded,
            title: 'الانتقال إلى بوابة الدفع',
            description: 'سنفتح صفحة معاملات لإكمال بيانات البطاقة',
          ),
          SizedBox(height: 12),
          _PaymentFeature(
            icon: AppIcons.verified_user_rounded,
            title: 'تأكيد فوري وآمن',
            description: 'يضاف الرصيد بعد نجاح العملية مباشرة',
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPicker() {
    final hasReceipt = _receiptPath != null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle(
            icon: AppIcons.upload_file_rounded,
            title: 'إيصال التحويل',
            subtitle: 'صورة واضحة أو ملف PDF بحد أقصى 5 MB',
            isRequired: true,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickReceipt,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: hasReceipt
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasReceipt
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.divider,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: hasReceipt
                          ? AppColors.success.withValues(alpha: 0.14)
                          : AppColors.blush,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasReceipt
                          ? AppIcons.verified_rounded
                          : AppIcons.cloud_upload_rounded,
                      color: hasReceipt ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          hasReceipt
                              ? (_receiptName ?? 'إيصال مرفق')
                              : 'اختيار ملف الإيصال',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasReceipt
                              ? 'الحجم: ${_formatBytes(_receiptSizeBytes)}'
                              : 'JPG، PNG، WEBP أو PDF',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasReceipt)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _receiptPath = null;
                          _receiptName = null;
                          _receiptSizeBytes = null;
                        });
                      },
                      icon: const Icon(
                        AppIcons.close_rounded,
                        color: AppColors.textHint,
                      ),
                    )
                  else
                    const Icon(
                      AppIcons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.cairo(fontSize: 14, color: AppColors.textHint),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceVariant.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final TopUpProviderModel provider;
  final VoidCallback onBack;

  const _SheetHeader({required this.provider, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final bool isBankTransfer = provider.isBankTransfer;
    final bool isMoamalat = provider.isMoamalat;

    return Column(
      children: <Widget>[
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(
                    AppIcons.close_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.blush,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isBankTransfer
                    ? AppIcons.account_balance_rounded
                    : isMoamalat
                    ? AppIcons.credit_card_rounded
                    : AppIcons.bolt_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isBankTransfer
                        ? 'تحويل بنكي'
                        : 'الشحن عبر ${provider.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBankTransfer
                        ? 'أرسلي التحويل وأرفقي الإيصال'
                        : provider.flowLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  final List<double> values;
  final ValueChanged<double> onSelect;
  final double? selectedValue;

  const _QuickAmounts({
    required this.values,
    required this.onSelect,
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.asMap().entries.map((entry) {
        final value = entry.value;
        final selected = selectedValue == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: entry.key == values.length - 1 ? 0 : 7,
            ),
            child: InkWell(
              onTap: () => onSelect(value),
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(0)} د.ل',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;

  const _LabeledField({required this.title, required this.child, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            if (hint != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                hint!,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isRequired;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isRequired) ...<Widget>[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.badge.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'مطلوب',
                        style: GoogleFonts.cairo(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.badge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PaymentFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onCopy;
  final bool isLast;

  const _BankDetailRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                onCopy(label);
              },
              icon: const Icon(
                AppIcons.copy_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              tooltip: 'نسخ',
            ),
          ],
        ),
        if (!isLast)
          Divider(height: 18, color: Colors.black.withValues(alpha: 0.06)),
      ],
    );
  }
}
