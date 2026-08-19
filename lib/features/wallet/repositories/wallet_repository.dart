import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../models/wallet_model.dart';

class WalletRepository {
  final Dio dio;

  WalletRepository({required this.dio});

  Future<WalletSummaryModel> fetchSummary() async {
    final response = await dio.get(ApiConstants.walletSummary);
    final data = response.data['data'] as Map<String, dynamic>;
    return WalletSummaryModel.fromJson(data);
  }

  Future<
    ({List<WalletTransactionModel> transactions, WalletTransactionsMeta meta})
  >
  fetchTransactions({
    int page = 1,
    int perPage = 15,
    String? type,
    String? status,
    String? provider,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    };

    final response = await dio.get(
      ApiConstants.walletTransactions,
      queryParameters: queryParams,
    );

    final raw = response.data as Map<String, dynamic>;
    final transactions = (raw['data'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              WalletTransactionModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final meta = WalletTransactionsMeta.fromJson(
      raw['meta'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

    return (transactions: transactions, meta: meta);
  }

  Future<({double balance, WalletTransactionModel transaction})> topUpDirect({
    required double amount,
    required String provider,
    String? reference,
    String? notes,
  }) async {
    final response = await dio.post(
      ApiConstants.walletTopUp,
      data: <String, dynamic>{
        'amount': amount,
        'provider': provider,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );

    return _parseTopUpResponse(response.data as Map<String, dynamic>);
  }

  Future<({double balance, WalletTransactionModel transaction})>
  submitBankTransferTopUp({
    required double amount,
    required String receiptPath,
    String? receiptFileName,
    String? reference,
    String? notes,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'amount': amount,
      'provider': 'bank_transfer',
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'receipt': await MultipartFile.fromFile(
        receiptPath,
        filename: receiptFileName,
      ),
    });

    final response = await dio.post(
      ApiConstants.walletTopUp,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );

    return _parseTopUpResponse(response.data as Map<String, dynamic>);
  }

  Future<MoamalatPrepareResult> prepareMoamalat({
    required double amount,
  }) async {
    final response = await dio.post(
      ApiConstants.walletMoamalatPrepare,
      data: <String, dynamic>{'amount': amount, 'provider': 'moamalat'},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return MoamalatPrepareResult.fromJson(data);
  }

  Future<({double balance, WalletTransactionModel transaction})>
  confirmMoamalat(Map<String, dynamic> callbackPayload) async {
    final response = await dio.post(
      ApiConstants.walletMoamalatConfirm,
      data: callbackPayload,
    );

    return _parseTopUpResponse(response.data as Map<String, dynamic>);
  }

  Future<void> failMoamalat({
    required String merchantReference,
    String reason = 'user_cancelled',
    Map<String, dynamic>? callbackPayload,
  }) async {
    await dio.post(
      ApiConstants.walletMoamalatFail,
      data: <String, dynamic>{
        ...?callbackPayload,
        'merchant_reference': merchantReference,
        'reason': reason,
      },
    );
  }

  ({double balance, WalletTransactionModel transaction}) _parseTopUpResponse(
    Map<String, dynamic> responseData,
  ) {
    final data = responseData['data'] as Map<String, dynamic>;

    return (
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      transaction: WalletTransactionModel.fromJson(
        data['transaction'] as Map<String, dynamic>,
      ),
    );
  }
}
