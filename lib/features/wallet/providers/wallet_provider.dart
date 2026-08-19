import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/wallet_model.dart';
import '../repositories/wallet_repository.dart';

enum WalletStatus { initial, loading, loaded, error }

class WalletProvider with ChangeNotifier {
  final WalletRepository repository;

  WalletStatus _status = WalletStatus.initial;
  String? _errorMessage;
  WalletSummaryModel? _summary;

  List<WalletTransactionModel> _transactions = <WalletTransactionModel>[];
  WalletTransactionsMeta? _transactionsMeta;
  bool _loadingMoreTransactions = false;
  String? _filterType;
  String? _filterStatus;
  String? _filterProvider;

  MoamalatPrepareResult? _moamalatPrepare;
  bool _moamalatLoading = false;

  WalletProvider({required this.repository});

  WalletStatus get status => _status;
  String? get errorMessage => _errorMessage;
  WalletSummaryModel? get summary => _summary;
  List<WalletTransactionModel> get transactions => _transactions;
  WalletTransactionsMeta? get transactionsMeta => _transactionsMeta;
  bool get loadingMoreTransactions => _loadingMoreTransactions;
  MoamalatPrepareResult? get moamalatPrepare => _moamalatPrepare;
  bool get moamalatLoading => _moamalatLoading;
  bool get hasMorePages => _transactionsMeta?.hasMorePages ?? false;
  String? get filterType => _filterType;
  String? get filterStatus => _filterStatus;
  String? get filterProvider => _filterProvider;

  Future<void> loadSummary({bool silent = false}) async {
    if (!silent) {
      _status = WalletStatus.loading;
      notifyListeners();
    }

    try {
      _summary = await repository.fetchSummary();
      _status = WalletStatus.loaded;
      _errorMessage = null;
    } on DioException catch (error) {
      _status = WalletStatus.error;
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'فشل تحميل بيانات المحفظة',
      );
    } catch (_) {
      _status = WalletStatus.error;
      _errorMessage = 'حدث خطأ غير متوقع';
    }

    notifyListeners();
  }

  Future<void> loadTransactions({
    String? type,
    String? status,
    String? provider,
  }) async {
    _filterType = type;
    _filterStatus = status;
    _filterProvider = provider;
    _transactions = <WalletTransactionModel>[];
    _transactionsMeta = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.fetchTransactions(
        page: 1,
        type: _filterType,
        status: _filterStatus,
        provider: _filterProvider,
      );
      _transactions = result.transactions;
      _transactionsMeta = result.meta;
    } on DioException catch (error) {
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'فشل تحميل الحركات',
      );
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع';
    }

    notifyListeners();
  }

  Future<void> loadMoreTransactions() async {
    if (_loadingMoreTransactions || !hasMorePages) {
      return;
    }

    _loadingMoreTransactions = true;
    notifyListeners();

    try {
      final nextPage = (_transactionsMeta?.currentPage ?? 1) + 1;
      final result = await repository.fetchTransactions(
        page: nextPage,
        type: _filterType,
        status: _filterStatus,
        provider: _filterProvider,
      );
      _transactions = <WalletTransactionModel>[
        ..._transactions,
        ...result.transactions,
      ];
      _transactionsMeta = result.meta;
    } catch (_) {
      // Keep existing data and stop pagination silently.
    }

    _loadingMoreTransactions = false;
    notifyListeners();
  }

  Future<bool> topUpDirect({
    required double amount,
    required String provider,
    String? reference,
    String? notes,
  }) async {
    _errorMessage = null;

    try {
      final result = await repository.topUpDirect(
        amount: amount,
        provider: provider,
        reference: reference,
        notes: notes,
      );
      _applyTopUpResult(result.balance, result.transaction);
      return true;
    } on DioException catch (error) {
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'فشلت عملية الشحن',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitBankTransferTopUp({
    required double amount,
    required String receiptPath,
    String? receiptFileName,
    String? reference,
    String? notes,
  }) async {
    _errorMessage = null;

    try {
      final result = await repository.submitBankTransferTopUp(
        amount: amount,
        receiptPath: receiptPath,
        receiptFileName: receiptFileName,
        reference: reference,
        notes: notes,
      );
      _applyTopUpResult(
        _summary?.balance ?? result.balance,
        result.transaction,
        keepExistingBalance: true,
      );
      return true;
    } on DioException catch (error) {
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'تعذر إرسال طلب التحويل البنكي',
      );
      notifyListeners();
      return false;
    }
  }

  Future<MoamalatPrepareResult?> prepareMoamalat({
    required double amount,
  }) async {
    _moamalatLoading = true;
    _errorMessage = null;
    _moamalatPrepare = null;
    notifyListeners();

    try {
      _moamalatPrepare = await repository.prepareMoamalat(amount: amount);
      return _moamalatPrepare;
    } on DioException catch (error) {
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'فشل تجهيز بيانات الدفع',
      );
      return null;
    } finally {
      _moamalatLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmMoamalat(Map<String, dynamic> callbackPayload) async {
    _errorMessage = null;

    try {
      final result = await repository.confirmMoamalat(callbackPayload);
      _moamalatPrepare = null;
      _applyTopUpResult(result.balance, result.transaction);
      return true;
    } on DioException catch (error) {
      _errorMessage = _resolveDioMessage(
        error,
        fallbackMessage: 'فشل تأكيد الدفع',
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> failMoamalat({
    String? merchantReference,
    String reason = 'user_cancelled',
    Map<String, dynamic>? callbackPayload,
  }) async {
    final reference = merchantReference ?? _moamalatPrepare?.merchantReference;
    if (reference == null || reference.isEmpty) {
      return;
    }

    try {
      await repository.failMoamalat(
        merchantReference: reference,
        reason: reason,
        callbackPayload: callbackPayload,
      );
    } catch (_) {
      // Best effort only.
    }

    _moamalatPrepare = null;
  }

  void updateLocalBalance(double balance) {
    if (_summary == null) {
      return;
    }

    _summary = _summary!.copyWith(balance: balance);
    notifyListeners();
  }

  void clearUserScopedData() {
    _status = WalletStatus.initial;
    _errorMessage = null;
    _summary = null;
    _transactions = <WalletTransactionModel>[];
    _transactionsMeta = null;
    _loadingMoreTransactions = false;
    _filterType = null;
    _filterStatus = null;
    _filterProvider = null;
    _moamalatPrepare = null;
    _moamalatLoading = false;
    notifyListeners();
  }

  void _applyTopUpResult(
    double balance,
    WalletTransactionModel transaction, {
    bool keepExistingBalance = false,
  }) {
    if (_summary != null) {
      _summary = _summary!.copyWith(
        balance: keepExistingBalance ? _summary!.balance : balance,
        recentTransactions: <WalletTransactionModel>[
          transaction,
          ..._summary!.recentTransactions.where(
            (WalletTransactionModel item) => item.id != transaction.id,
          ),
        ],
      );
    }

    final matchesType = _filterType == null || transaction.type == _filterType;
    final matchesStatus =
        _filterStatus == null || transaction.status == _filterStatus;
    final matchesProvider =
        _filterProvider == null || transaction.provider == _filterProvider;

    if (matchesType && matchesStatus && matchesProvider) {
      _transactions = <WalletTransactionModel>[
        transaction,
        ..._transactions.where(
          (WalletTransactionModel item) => item.id != transaction.id,
        ),
      ];
    }

    notifyListeners();
  }

  String _resolveDioMessage(
    DioException error, {
    required String fallbackMessage,
  }) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }
      }

      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return fallbackMessage;
  }
}
