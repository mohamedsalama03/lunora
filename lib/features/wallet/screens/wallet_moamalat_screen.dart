import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class WalletMoamalatScreen extends StatefulWidget {
  final MoamalatPrepareResult prepareResult;

  const WalletMoamalatScreen({super.key, required this.prepareResult});

  @override
  State<WalletMoamalatScreen> createState() => _WalletMoamalatScreenState();
}

class _WalletMoamalatScreenState extends State<WalletMoamalatScreen> {
  late final WebViewController _controller;
  bool _isPageLoading = true;
  bool _isProcessing = false;
  bool _handledResult = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFCEEF0))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isPageLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isPageLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() => _isPageLoading = false);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'MoamalatChannel',
        onMessageReceived: (message) async {
          await _handleJsMessage(message.message);
        },
      )
      ..loadHtmlString(_buildLightboxHtml());
  }

  String _buildLightboxHtml() {
    final checkoutJson = jsonEncode(<String, dynamic>{
      ...widget.prepareResult.checkout,
      'MerchantReference':
          widget.prepareResult.checkout['MerchantReference'] ??
          widget.prepareResult.merchantReference,
    });

    return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>معاملات - شحن المحفظة</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      background: #FFF8F7;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 20px;
    }
    .loader {
      text-align: center;
      color: #5A2E36;
      font-size: 15px;
      padding: 20px;
    }
    .loader .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid #F8E7EA;
      border-top-color: #B76E79;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="loader">
    <div class="spinner"></div>
    <p>جاري تحميل بوابة الدفع...</p>
  </div>

  <script>
    const checkout = $checkoutJson;

    function send(type, payload) {
      try {
        MoamalatChannel.postMessage(JSON.stringify({
          type: type,
          payload: payload || {}
        }));
      } catch (error) {}
    }

    function mergeCheckoutPayload(source) {
      const payload = { ...(source || {}) };

      if (!payload.MerchantReference) payload.MerchantReference = checkout.MerchantReference;
      if (!payload.MID) payload.MID = checkout.MID;
      if (!payload.TID) payload.TID = checkout.TID;
      if (!payload.AmountTrxn) payload.AmountTrxn = checkout.AmountTrxn;
      if (!payload.TrxDateTime) payload.TrxDateTime = checkout.TrxDateTime;
      if (!payload.SecureHash) payload.SecureHash = checkout.SecureHash;

      if (!payload.MerchantId && payload.MID) payload.MerchantId = payload.MID;
      if (!payload.TerminalId && payload.TID) payload.TerminalId = payload.TID;
      if (!payload.Amount && payload.AmountTrxn) payload.Amount = payload.AmountTrxn;
      if (!payload.DateTimeLocalTrxn && payload.TrxDateTime) {
        payload.DateTimeLocalTrxn = payload.TrxDateTime;
      }

      return payload;
    }

    function loadScript(src) {
      return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = src;
        script.onload = resolve;
        script.onerror = () => reject(new Error('Unable to load LightBox script.'));
        document.head.appendChild(script);
      });
    }

    async function startLightbox() {
      try {
        await loadScript(checkout.scriptUrl);

        if (!window.Lightbox || !window.Lightbox.Checkout) {
          throw new Error('LightBox object is not available.');
        }

        window.Lightbox.Checkout.configure = {
          MID: checkout.MID,
          TID: checkout.TID,
          AmountTrxn: checkout.AmountTrxn,
          MerchantReference: checkout.MerchantReference,
          TrxDateTime: checkout.TrxDateTime,
          SecureHash: checkout.SecureHash,
          completeCallback: function(callbackPayload) {
            send('complete', mergeCheckoutPayload(callbackPayload));
          },
          errorCallback: function(errorPayload) {
            const payload = mergeCheckoutPayload(errorPayload);
            send('error', payload);
          },
          cancelCallback: function() {
            send('cancel', mergeCheckoutPayload({
              MerchantReference: checkout.MerchantReference
            }));
          }
        };

        window.Lightbox.Checkout.showLightbox();
        document.querySelector('.loader').style.display = 'none';
      } catch (error) {
        send('init_error', {
          MerchantReference: checkout.MerchantReference,
          message: String(error)
        });

        const loaderText = document.querySelector('.loader p');
        if (loaderText) {
          loaderText.textContent = 'حدث خطأ أثناء تحميل بوابة الدفع';
        }
      }
    }

    window.addEventListener('load', startLightbox);
  </script>
</body>
</html>
''';
  }

  Future<void> _handleJsMessage(String rawMessage) async {
    if (_handledResult || _isProcessing) return;

    final event = _parseEvent(rawMessage);
    final type = (event['type'] as String? ?? '').trim();
    final payload = _buildGatewayPayload(_normalizePayload(event['payload']));
    final merchantReference = _resolveMerchantReference(payload);

    if (merchantReference.isNotEmpty) {
      payload['MerchantReference'] = merchantReference;
      payload['merchant_reference'] ??= merchantReference;
    }

    _handledResult = true;
    if (mounted) {
      setState(() => _isProcessing = true);
    }

    final walletProvider = context.read<WalletProvider>();

    switch (type) {
      case 'complete':
        final success = await walletProvider.confirmMoamalat(payload);
        if (!mounted) return;
        if (success) {
          _syncWalletBalanceAcrossApp(walletProvider.summary?.balance);
          await _closeLightbox();
          if (!mounted) return;
          AppNotifications.showSuccess(context, 'تم شحن المحفظة بنجاح');
          Navigator.of(context).pop(true);
          return;
        }

        setState(() => _isProcessing = false);
        _showErrorAndExit(
          walletProvider.errorMessage ?? 'فشل تأكيد شحن المحفظة عبر معاملات',
        );
        return;

      case 'error':
      case 'cancel':
        await walletProvider.failMoamalat(
          merchantReference: merchantReference,
          reason: _resolveFailureReason(type, payload),
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showErrorAndExit(_resolveFailureMessage(type, payload));
        return;

      case 'init_error':
        await walletProvider.failMoamalat(
          merchantReference: merchantReference,
          reason: 'lightbox_init_failed',
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showErrorAndExit(_resolveInitErrorMessage(payload));
        return;

      default:
        await walletProvider.failMoamalat(
          merchantReference: merchantReference,
          reason: 'unknown_callback',
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showErrorAndExit('تعذر التحقق من نتيجة عملية الشحن');
    }
  }

  Map<String, dynamic> _parseEvent(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        if (!decoded.containsKey('type') &&
            (decoded.containsKey('MerchantReference') ||
                decoded.containsKey('ActionCode'))) {
          return <String, dynamic>{'type': 'complete', 'payload': decoded};
        }
        return decoded;
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (!map.containsKey('type') &&
            (map.containsKey('MerchantReference') ||
                map.containsKey('ActionCode'))) {
          return <String, dynamic>{'type': 'complete', 'payload': map};
        }
        return map;
      }
    } catch (_) {}

    return <String, dynamic>{
      'type': 'init_error',
      'payload': <String, dynamic>{
        'MerchantReference': widget.prepareResult.merchantReference,
        'message': 'Invalid callback payload received from LightBox.',
      },
    };
  }

  Map<String, dynamic> _normalizePayload(dynamic rawPayload) {
    if (rawPayload is Map<String, dynamic>) return rawPayload;
    if (rawPayload is Map) return Map<String, dynamic>.from(rawPayload);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _buildGatewayPayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{};

    for (final entry in payload.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      normalized[entry.key] = value;
    }

    void setAlias(String target, List<String> candidates) {
      if (_hasValue(normalized[target])) return;
      for (final candidate in candidates) {
        if (_hasValue(normalized[candidate])) {
          normalized[target] = normalized[candidate];
          return;
        }
      }
    }

    setAlias('MerchantReference', <String>[
      'merchant_reference',
      'merchantReference',
    ]);
    setAlias('ActionCode', <String>['actionCode']);
    setAlias('Message', <String>['message']);
    setAlias('Status', <String>['status']);
    setAlias('Result', <String>['result']);
    setAlias('ResponseCode', <String>['responseCode', 'RespCode']);
    setAlias('ResultCode', <String>['resultCode', 'StatusCode']);
    setAlias('NetworkReference', <String>['networkReference']);
    setAlias('SecureHash', <String>['secure_hash', 'secureHash']);
    setAlias('MID', <String>['MerchantId']);
    setAlias('TID', <String>['TerminalId']);
    setAlias('AmountTrxn', <String>['Amount']);
    setAlias('TrxDateTime', <String>['DateTimeLocalTrxn']);

    final checkout = widget.prepareResult.checkout;
    final merchantReference = _resolveMerchantReference(normalized);

    normalized['MerchantReference'] = merchantReference;
    normalized['merchant_reference'] ??= merchantReference;
    normalized['MID'] ??= checkout['MID'];
    normalized['TID'] ??= checkout['TID'];
    normalized['AmountTrxn'] ??= checkout['AmountTrxn'];
    normalized['TrxDateTime'] ??= checkout['TrxDateTime'];
    normalized['SecureHash'] ??= checkout['SecureHash'];

    normalized['MerchantId'] ??= normalized['MID'] ?? checkout['MID'];
    normalized['TerminalId'] ??= normalized['TID'] ?? checkout['TID'];
    normalized['Amount'] ??= normalized['AmountTrxn'] ?? checkout['AmountTrxn'];
    normalized['DateTimeLocalTrxn'] ??=
        normalized['TrxDateTime'] ?? checkout['TrxDateTime'];

    return normalized;
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }

  String _resolveMerchantReference(Map<String, dynamic> payload) {
    final direct =
        (payload['MerchantReference'] ?? payload['merchant_reference'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return widget.prepareResult.merchantReference;
  }

  String _resolveFailureReason(String type, Map<String, dynamic> payload) {
    if (type == 'cancel') {
      return 'user_cancelled';
    }

    final actionCode = payload['ActionCode']?.toString().trim();
    if (actionCode != null && actionCode.isNotEmpty) {
      return 'gateway_$actionCode';
    }

    return 'lightbox_error';
  }

  String _resolveFailureMessage(String type, Map<String, dynamic> payload) {
    if (type == 'cancel') {
      return 'تم إلغاء عملية شحن المحفظة';
    }

    final message = (payload['Message'] ?? payload['message'])
        ?.toString()
        .trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'فشلت عملية شحن المحفظة عبر معاملات';
  }

  String _resolveInitErrorMessage(Map<String, dynamic> payload) {
    final message = (payload['message'] ?? payload['Message'])
        ?.toString()
        .trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'تعذر تحميل بوابة الدفع عبر معاملات';
  }

  void _syncWalletBalanceAcrossApp(double? balance) {
    if (balance == null) return;

    context.read<OrdersProvider>().updateLookupsWalletBalance(balance);

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      authProvider.updateUser(user.copyWith(walletBalance: balance));
    }
  }

  Future<void> _closeLightbox() async {
    try {
      await _controller.runJavaScript(
        'window.Lightbox?.Checkout?.closeLightbox?.();',
      );
    } catch (_) {}
  }

  void _showErrorAndExit(String message) {
    AppNotifications.showError(context, message);
    Navigator.of(context).pop(false);
  }

  Future<void> _cancelAndExit() async {
    if (_handledResult || _isProcessing) return;
    _handledResult = true;

    await context.read<WalletProvider>().failMoamalat(
      merchantReference: widget.prepareResult.merchantReference,
      reason: 'user_cancelled',
      callbackPayload: <String, dynamic>{
        'MerchantReference': widget.prepareResult.merchantReference,
      },
    );

    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && !_handledResult && !_isProcessing) {
          _handledResult = true;
          await context.read<WalletProvider>().failMoamalat(
            merchantReference: widget.prepareResult.merchantReference,
            reason: 'user_cancelled',
            callbackPayload: <String, dynamic>{
              'MerchantReference': widget.prepareResult.merchantReference,
            },
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFCEEF0),
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              AppIcons.close_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: _isProcessing ? null : _cancelAndExit,
          ),
          title: Text(
            'الدفع عبر معاملات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isPageLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            if (_isProcessing)
              Container(
                color: AppColors.mauve.withValues(alpha: 0.52),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    margin: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'جاري معالجة الدفع...',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
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
