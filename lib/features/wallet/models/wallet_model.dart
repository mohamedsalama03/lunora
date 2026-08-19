String? extractBankTransferRejectionReason(String? notes) {
  if (notes == null || notes.trim().isEmpty) {
    return null;
  }

  const marker = '[BANK_TRANSFER_REJECTION_REASON]:';
  final lines = notes.split(RegExp(r'\r\n|\r|\n'));

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.startsWith(marker)) {
      continue;
    }

    final reason = line.substring(marker.length).trim();
    return reason.isEmpty ? null : reason;
  }

  return null;
}

class TopUpProviderModel {
  final String key;
  final String label;
  final String mode;

  const TopUpProviderModel({
    required this.key,
    required this.label,
    required this.mode,
  });

  factory TopUpProviderModel.fromJson(Map<String, dynamic> json) {
    return TopUpProviderModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'direct',
    );
  }

  bool get isDirect => mode == 'direct' && !isBankTransfer;
  bool get isMoamalat => mode == 'moamalat_lightbox' || key == 'moamalat';
  bool get isBankTransfer =>
      key == 'bank_transfer' || mode == 'bank_transfer_receipt';

  String get flowLabel {
    if (isBankTransfer) {
      return 'تحويل بنكي مع إيصال';
    }
    if (isMoamalat) {
      return 'بوابة دفع إلكترونية';
    }
    return 'شحن فوري';
  }
}

class WalletTransactionModel {
  final int id;
  final String transactionNumber;
  final String type;
  final String typeLabel;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final String statusLabel;
  final String? provider;
  final String? providerLabel;
  final String? reference;
  final String? notes;
  final bool receiptUploaded;
  final String? receiptUrl;
  final String createdAt;
  final String updatedAt;

  const WalletTransactionModel({
    required this.id,
    required this.transactionNumber,
    required this.type,
    required this.typeLabel,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.statusLabel,
    this.provider,
    this.providerLabel,
    this.reference,
    this.notes,
    required this.receiptUploaded,
    this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as int? ?? 0,
      transactionNumber: json['transaction_number']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
      provider: json['provider']?.toString(),
      providerLabel: json['provider_label']?.toString(),
      reference: json['reference']?.toString(),
      notes: json['notes']?.toString(),
      receiptUploaded: json['receipt_uploaded'] as bool? ?? false,
      receiptUrl: json['receipt_url']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  bool get isDeposit => type == 'deposit';
  bool get isWithdrawal => type == 'withdrawal';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isBankTransfer => provider == 'bank_transfer';

  String? get bankTransferRejectionReason =>
      isBankTransfer ? extractBankTransferRejectionReason(notes) : null;

  String get displayStatusText {
    if (!isBankTransfer) {
      return statusLabel;
    }

    switch (status) {
      case 'pending':
        return 'طلب التحويل قيد المراجعة';
      case 'completed':
        return 'تم اعتماد الحوالة وإضافة الرصيد';
      case 'failed':
        return 'تم رفض طلب التحويل';
      default:
        return statusLabel;
    }
  }
}

class WalletTransactionsMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  const WalletTransactionsMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  factory WalletTransactionsMeta.fromJson(Map<String, dynamic> json) {
    return WalletTransactionsMeta(
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 15,
      total: json['total'] as int? ?? 0,
      hasMorePages: json['has_more_pages'] as bool? ?? false,
    );
  }
}

class WalletSummaryModel {
  final double balance;
  final String currency;
  final bool walletPaymentEnabled;
  final List<TopUpProviderModel> topUpProviders;
  final List<WalletTransactionModel> recentTransactions;

  const WalletSummaryModel({
    required this.balance,
    required this.currency,
    required this.walletPaymentEnabled,
    required this.topUpProviders,
    required this.recentTransactions,
  });

  factory WalletSummaryModel.fromJson(Map<String, dynamic> json) {
    return WalletSummaryModel(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'LYD',
      walletPaymentEnabled: json['wallet_payment_enabled'] as bool? ?? false,
      topUpProviders:
          (json['top_up_providers'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) =>
                    TopUpProviderModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      recentTransactions:
          (json['recent_transactions'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) => WalletTransactionModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }

  WalletSummaryModel copyWith({
    double? balance,
    String? currency,
    bool? walletPaymentEnabled,
    List<TopUpProviderModel>? topUpProviders,
    List<WalletTransactionModel>? recentTransactions,
  }) {
    return WalletSummaryModel(
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      walletPaymentEnabled: walletPaymentEnabled ?? this.walletPaymentEnabled,
      topUpProviders: topUpProviders ?? this.topUpProviders,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }
}

class MoamalatPrepareResult {
  final String merchantReference;
  final Map<String, dynamic> checkout;
  final WalletTransactionModel transaction;

  const MoamalatPrepareResult({
    required this.merchantReference,
    required this.checkout,
    required this.transaction,
  });

  factory MoamalatPrepareResult.fromJson(Map<String, dynamic> json) {
    return MoamalatPrepareResult(
      merchantReference: json['merchant_reference']?.toString() ?? '',
      checkout: Map<String, dynamic>.from(
        json['checkout'] as Map? ?? const <String, dynamic>{},
      ),
      transaction: WalletTransactionModel.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
    );
  }

  String? get scriptUrl => checkout['scriptUrl']?.toString();
}
