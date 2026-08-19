import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import 'order_detail_screen.dart';

/// شاشة دفع معاملات للطلبات
class OrderMoamalatScreen extends StatefulWidget {
  final MoamalatOrderCheckout checkout;
  final String orderNumber;

  const OrderMoamalatScreen({
    super.key,
    required this.checkout,
    required this.orderNumber,
  });

  @override
  State<OrderMoamalatScreen> createState() => _OrderMoamalatScreenState();
}

class _OrderMoamalatScreenState extends State<OrderMoamalatScreen> {
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
      'scriptUrl': widget.checkout.scriptUrl,
      'MID': widget.checkout.mid,
      'TID': widget.checkout.tid,
      'AmountTrxn': widget.checkout.amountTrxn,
      'MerchantReference': widget.checkout.merchantReference,
      'TrxDateTime': widget.checkout.trxDateTime,
      'SecureHash': widget.checkout.secureHash,
    });

    return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>معاملات - الدفع</title>
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
            send('complete', callbackPayload || {});
          },
          errorCallback: function(errorPayload) {
            const payload = errorPayload || {};
            if (!payload.MerchantReference) {
              payload.MerchantReference = checkout.MerchantReference;
            }
            send('error', payload);
          },
          cancelCallback: function() {
            send('cancel', {
              MerchantReference: checkout.MerchantReference
            });
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
    final payload = _normalizePayload(event['payload']);
    final merchantReference = _resolveMerchantReference(payload);

    if (merchantReference.isNotEmpty) {
      payload['MerchantReference'] = merchantReference;
      payload['merchant_reference'] ??= merchantReference;
    }

    _handledResult = true;
    if (mounted) {
      setState(() => _isProcessing = true);
    }

    final provider = context.read<OrdersProvider>();

    switch (type) {
      case 'complete':
        final order = await provider.confirmMoamalat(payload);
        if (!mounted) return;
        if (order != null) {
          await _closeLightbox();
          if (!mounted) return;
          _navigateToSuccess(order);
          return;
        }

        setState(() => _isProcessing = false);
        _showErrorAndGoBack(
          provider.errorMessage ?? 'فشل تأكيد الدفع عبر معاملات',
        );
        return;

      case 'error':
      case 'cancel':
        await provider.failMoamalat(
          merchantReference: merchantReference,
          reason: _resolveFailureReason(type, payload),
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showAwaitingDialog();
        return;

      case 'init_error':
        await provider.failMoamalat(
          merchantReference: merchantReference,
          reason: 'lightbox_init_failed',
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showErrorAndGoBack(_resolveInitErrorMessage(payload));
        return;

      default:
        await provider.failMoamalat(
          merchantReference: merchantReference,
          reason: 'unknown_callback',
          callbackPayload: payload,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showAwaitingDialog();
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
        'MerchantReference': widget.checkout.merchantReference,
        'message': 'Invalid callback payload received from LightBox.',
      },
    };
  }

  Map<String, dynamic> _normalizePayload(dynamic rawPayload) {
    if (rawPayload is Map<String, dynamic>) return rawPayload;
    if (rawPayload is Map) return Map<String, dynamic>.from(rawPayload);
    return <String, dynamic>{};
  }

  String _resolveMerchantReference(Map<String, dynamic> payload) {
    final direct =
        (payload['MerchantReference'] ?? payload['merchant_reference'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return widget.checkout.merchantReference;
  }

  String _resolveFailureReason(String type, Map<String, dynamic> payload) {
    if (type == 'cancel') {
      return 'user_cancelled';
    }

    final actionCode = payload['ActionCode']?.toString().trim();
    if (actionCode != null && actionCode.isNotEmpty) {
      return 'gateway_$actionCode';
    }

    final message = (payload['Message'] ?? payload['message'])
        ?.toString()
        .trim();
    if (message != null && message.isNotEmpty) {
      return 'lightbox_error';
    }

    return 'lightbox_error';
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

  Future<void> _closeLightbox() async {
    try {
      await _controller.runJavaScript(
        'window.Lightbox?.Checkout?.closeLightbox?.();',
      );
    } catch (_) {}
  }

  void _navigateToSuccess(OrderModel order) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderNumber: order.orderNumber,
          initialOrder: order,
          showSuccessBanner: true,
        ),
      ),
    );
  }

  void _showErrorAndGoBack(String message) {
    AppNotifications.showError(context, message);
    Navigator.of(context).pop();
  }

  void _showAwaitingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.hourglass_empty_rounded,
                color: Color(0xFFF59E0B),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'جاري التحقق',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تم إرسال الطلب وننتظر التأكيد النهائي من بوابة الدفع.\nيمكنك متابعة حالة الطلب من شاشة الطلبات.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    orderNumber: widget.orderNumber,
                    showSuccessBanner: false,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              elevation: 0,
            ),
            child: Text(
              'تفاصيل الطلب',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAndExit() async {
    if (_handledResult || _isProcessing) return;
    _handledResult = true;
    final provider = context.read<OrdersProvider>();
    await provider.failMoamalat(
      merchantReference: widget.checkout.merchantReference,
      reason: 'user_cancelled',
      callbackPayload: <String, dynamic>{
        'MerchantReference': widget.checkout.merchantReference,
      },
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && !_handledResult && !_isProcessing) {
          _handledResult = true;
          final provider = context.read<OrdersProvider>();
          await provider.failMoamalat(
            merchantReference: widget.checkout.merchantReference,
            reason: 'user_cancelled',
            callbackPayload: <String, dynamic>{
              'MerchantReference': widget.checkout.merchantReference,
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
