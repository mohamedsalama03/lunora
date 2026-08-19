import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../addresses/models/address_model.dart';
import '../../addresses/providers/address_provider.dart';
import '../../addresses/screens/address_list_screen.dart';
import '../../addresses/screens/address_map_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/widgets/auth_required_dialog.dart';
import '../../orders/models/order_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../orders/screens/order_moamalat_screen.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const double _misrataBaseShippingCost = 5.0;
  static const double _misrataCostPerKm = 1.0;

  String? _selectedPaymentMethod;
  bool _allowEmptyCartAutoExit = true;
  AddressModel? _selectedAddress;
  RouteEstimateResult? _selectedRouteEstimate;
  bool _isEstimatingShipping = false;
  int _shippingEstimateRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapCheckout();
    });
  }

  Future<void> _bootstrapCheckout() async {
    final canContinue = await _ensureAuthenticated();
    if (!mounted || !canContinue) {
      return;
    }

    await _loadAddressConfig();
    if (!mounted) {
      return;
    }

    await _loadLookups();
    if (!mounted) {
      return;
    }

    _autoFillFromSavedAddress();
  }

  Future<bool> _ensureAuthenticated() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      return true;
    }

    final action = await showAuthRequiredDialog(
      context,
      badge: 'إتمام الطلب يحتاج حساباً',
      title: 'سجّل دخولك قبل متابعة الدفع',
      message:
          'حتى نحفظ عنوانك ونربط الطلب بحسابك بشكل صحيح، نحتاج إلى تسجيل الدخول قبل إكمال عملية الشراء.',
      primaryLabel: 'تسجيل الدخول',
      secondaryLabel: 'لاحقاً',
      icon: AppIcons.shopping_bag_rounded,
    );

    if (!mounted) {
      return false;
    }

    if (action != AuthPromptAction.login) {
      Navigator.pop(context);
      return false;
    }

    final didAuthenticate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnAfterAuth: true),
      ),
    );

    if (!mounted || didAuthenticate != true) {
      if (mounted) {
        Navigator.pop(context);
      }
      return false;
    }

    return true;
  }

  Future<void> _loadLookups({bool forceRefresh = false}) async {
    await context.read<OrdersProvider>().loadLookups(
      forceRefresh: forceRefresh,
    );
    if (!mounted || _selectedPaymentMethod != null) {
      return;
    }

    final lookups = context.read<OrdersProvider>().lookups;
    final methods = lookups?.enabledPaymentMethods ?? const [];
    if (methods.isNotEmpty) {
      setState(() => _selectedPaymentMethod = methods.first.key);
    }
  }

  Future<void> _loadAddressConfig({bool forceRefresh = false}) async {
    await context.read<AddressProvider>().loadMapConfig(
      forceRefresh: forceRefresh,
    );
  }

  ShippingCityLookup? _selectedShippingLookup(OrdersLookups? lookups) {
    final selectedCity = _selectedAddress?.city.trim();
    final shippingCities = lookups?.shippingCities;
    if (selectedCity == null ||
        selectedCity.isEmpty ||
        shippingCities == null ||
        shippingCities.isEmpty) {
      return null;
    }

    for (final city in shippingCities) {
      if (_isSameCityName(city.name, selectedCity)) {
        return city;
      }
    }

    return null;
  }

  double _calculateShippingCost(OrdersLookups? lookups) {
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) {
      return 0.0;
    }

    if (_isInsideMisrataAddress(selectedAddress)) {
      final distanceKm = _selectedRouteEstimate?.distanceKm ?? 0.0;
      return _misrataBaseShippingCost + (distanceKm * _misrataCostPerKm);
    }

    return _selectedShippingLookup(lookups)?.shippingCost ?? 0.0;
  }

  bool _hasSupportedShipping(OrdersLookups? lookups) {
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) {
      return false;
    }

    return _isInsideMisrataAddress(selectedAddress) ||
        _selectedShippingLookup(lookups) != null;
  }

  bool _isInsideMisrataAddress(AddressModel address) {
    final config = context.read<AddressProvider>().mapConfig;
    final city = address.city.trim();

    if (config != null && address.location.hasUsableCoordinates) {
      return config.isInsideMisrataBoundary(
        lat: address.location.lat,
        lng: address.location.lng,
        detectedCity: city,
      );
    }

    return _isMisrataCityName(city);
  }

  bool _isMisrataCityName(String value) {
    final normalized = _normalizeCityName(value);
    final misrata = _normalizeCityName('مصراتة');
    return normalized == 'misrata' ||
        normalized == 'musrata' ||
        normalized == 'misurata' ||
        normalized == misrata ||
        normalized.contains(misrata);
  }

  bool _isSameCityName(String left, String right) {
    final normalizedLeft = _normalizeCityName(left);
    final normalizedRight = _normalizeCityName(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }

    return normalizedLeft == normalizedRight ||
        normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft);
  }

  String _normalizeCityName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[\u0623\u0625\u0622\u0671]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[ىي]'), 'ي')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _autoFillFromSavedAddress() {
    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.addresses.isEmpty) {
      addressProvider.loadAddresses().then((_) {
        if (!mounted) return;
        _applyDefaultAddress(addressProvider);
      });
      return;
    }

    _applyDefaultAddress(addressProvider);
  }

  void _applyDefaultAddress(AddressProvider addressProvider) {
    final defaultAddress = addressProvider.defaultAddress;
    if (defaultAddress != null) {
      _applyAddress(defaultAddress);
    }
  }

  void _applyAddress(AddressModel address) {
    setState(() {
      _selectedAddress = address;
      _selectedRouteEstimate = null;
    });
    unawaited(_refreshSelectedAddressRouteEstimate(address));
  }

  Future<void> _refreshSelectedAddressRouteEstimate(
    AddressModel address,
  ) async {
    final addressProvider = context.read<AddressProvider>();
    final config = addressProvider.mapConfig;
    final requestId = ++_shippingEstimateRequestId;
    final canEstimate =
        config != null &&
        config.storeLocation.hasUsableCoordinates &&
        address.location.hasUsableCoordinates &&
        _isInsideMisrataAddress(address);

    if (!canEstimate) {
      if (!mounted) return;
      setState(() {
        _isEstimatingShipping = false;
        _selectedRouteEstimate = null;
      });
      return;
    }

    setState(() {
      _isEstimatingShipping = true;
      _selectedRouteEstimate = null;
    });

    await addressProvider.estimateRoute(
      origin: config.storeLocation,
      destination: address.location,
    );

    if (!mounted || requestId != _shippingEstimateRequestId) {
      return;
    }

    setState(() {
      _selectedRouteEstimate = addressProvider.routeEstimate;
      _isEstimatingShipping = false;
    });
  }

  Future<void> _openAddressPicker() async {
    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.mapConfig == null) {
      await addressProvider.loadMapConfig();
    }

    if (!mounted) return;

    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressListScreen(
          selectionMode: true,
          selectedAddressId: _selectedAddress?.id,
        ),
      ),
    );

    if (result != null && mounted) {
      _applyAddress(result);
    }
  }

  Future<void> _openMapForNewAddress() async {
    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.mapConfig == null) {
      await addressProvider.loadMapConfig();
    }
    if (!mounted) return;

    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(builder: (_) => const AddressMapScreen()),
    );

    if (result != null && mounted) {
      _applyAddress(result);
    }
  }

  String _shippingSummaryValue({
    required bool hasSelectedAddress,
    required bool hasSupportedShipping,
    required double shippingCost,
  }) {
    if (!hasSelectedAddress) {
      return 'اختر عنوان التوصيل أولاً';
    }

    if (_isEstimatingShipping) {
      return 'جاري حساب المسافة';
    }

    if (!hasSupportedShipping) {
      return 'هذه المدينة غير مدعومة';
    }

    return _formatShippingMoney(shippingCost);
  }

  Future<void> _placeOrder() async {
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) {
      AppNotifications.showError(
        context,
        'يرجى اختيار عنوان توصيل محفوظ قبل تأكيد الطلب.',
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      AppNotifications.showError(context, 'يرجى اختيار طريقة الدفع.');
      return;
    }

    final ordersProvider = context.read<OrdersProvider>();
    final lookups = ordersProvider.lookups;
    if (lookups == null) {
      AppNotifications.showError(
        context,
        ordersProvider.lookupsError ?? 'تعذر تحميل إعدادات الدفع والشحن.',
      );
      return;
    }

    final fullName = selectedAddress.fullName.trim();
    final phone = selectedAddress.phone.trim();
    if (fullName.isEmpty || !RegExp(r'^09\d{8}$').hasMatch(phone)) {
      AppNotifications.showError(
        context,
        'العنوان المحدد يحتاج اسمًا ورقم هاتف صالحًا. يرجى تعديل العنوان أولًا.',
      );
      return;
    }

    if (_isEstimatingShipping) {
      AppNotifications.showError(
        context,
        'يرجى الانتظار حتى يتم حساب رسوم التوصيل لهذا العنوان.',
      );
      return;
    }

    final hasSupportedShipping = _hasSupportedShipping(lookups);
    if (!hasSupportedShipping) {
      AppNotifications.showError(
        context,
        'مدينة العنوان المحدد غير مدعومة حاليًا للتوصيل. يرجى اختيار عنوان آخر أو تعديل المدينة.',
      );
      return;
    }

    final cart = context.read<CartProvider>();
    if (!cart.canCheckout) {
      AppNotifications.showError(
        context,
        'يوجد منتج غير متوفر أو كمية أعلى من المخزون المتاح.',
      );
      return;
    }

    if (_selectedPaymentMethod == 'wallet') {
      final balance = lookups.walletBalance;
      final total = cart.totalPrice + _calculateShippingCost(lookups);
      if (balance < total) {
        AppNotifications.showError(
          context,
          'رصيد المحفظة غير كافٍ (${_formatMoney(balance)}).',
        );
        return;
      }
    }

    final items = cart.items
        .map(
          (item) => <String, dynamic>{
            'product_id': item.productId,
            if (item.productVariantId != null)
              'product_variant_id': item.productVariantId,
            'quantity': item.quantity,
          },
        )
        .toList();

    final response = await ordersProvider.createOrder(
      items: items,
      paymentMethod: _selectedPaymentMethod!,
      shippingAddressId: selectedAddress.id,
      shipping: <String, dynamic>{'full_name': fullName, 'phone': phone},
    );

    if (!mounted) return;

    if (response == null) {
      AppNotifications.showError(
        context,
        ordersProvider.errorMessage ?? 'فشل إنشاء الطلب.',
      );
      return;
    }

    _allowEmptyCartAutoExit = false;

    if (_selectedPaymentMethod == 'moamalat') {
      final paymentAction = response.paymentAction;
      final hasLightboxPayload =
          paymentAction != null && paymentAction.type == 'moamalat_lightbox';

      cart.clearCart();

      if (hasLightboxPayload) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderMoamalatScreen(
              checkout: paymentAction.checkout,
              orderNumber: response.order.orderNumber,
            ),
          ),
        );
        return;
      }

      AppNotifications.showError(
        context,
        ordersProvider.errorMessage ??
            'تم إنشاء الطلب لكن لم تصل بيانات LightBox من الخادم.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderNumber: response.order.orderNumber,
            initialOrder: response.order,
          ),
        ),
      );
      return;
    }

    if (response.order.payment.isWallet && response.order.payment.isPaid) {
      _syncWalletBalanceAfterCheckout(
        lookups: lookups,
        paidAmount: response.order.payment.amount,
      );
    }

    cart.clearCart();

    if (response.order.payment.isPaid || response.order.payment.isCod) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderNumber: response.order.orderNumber,
            initialOrder: response.order,
            showSuccessBanner: response.order.payment.isPaid,
          ),
        ),
      );
      return;
    }

    AppNotifications.showError(
      context,
      ordersProvider.errorMessage ?? 'تعذر تجهيز بوابة الدفع.',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderNumber: response.order.orderNumber,
          initialOrder: response.order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = context.select<CartProvider, int>(
      (cart) => cart.itemCount,
    );
    final subtotal = context.select<CartProvider, double>(
      (cart) => cart.totalPrice,
    );
    final lookups = context.select<OrdersProvider, OrdersLookups?>(
      (orders) => orders.lookups,
    );
    final lookupsLoading = context.select<OrdersProvider, bool>(
      (orders) => orders.lookupsLoading,
    );
    final lookupsError = context.select<OrdersProvider, String?>(
      (orders) => orders.lookupsError,
    );
    final isCreating = context.select<OrdersProvider, bool>(
      (orders) => orders.isCreatingOrder,
    );
    final hasSupportedShipping = _hasSupportedShipping(lookups);
    final shippingCost = _calculateShippingCost(lookups);
    final total = subtotal + shippingCost;

    if (_allowEmptyCartAutoExit && itemCount == 0 && !isCreating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF6F5),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CheckoutHeader(),
                const SizedBox(height: 22),
                _buildShippingForm(lookups),
                const SizedBox(height: 22),
                _buildDeliveryMethodCard(
                  hasSelectedAddress: _selectedAddress != null,
                  hasSupportedShipping: hasSupportedShipping,
                  shippingCost: shippingCost,
                ),
                const SizedBox(height: 22),
                if (lookupsLoading)
                  const _CheckoutSectionCard(
                    child: SizedBox(
                      height: 78,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.roseGold,
                        ),
                      ),
                    ),
                  )
                else if (lookups != null)
                  _buildPaymentMethods(lookups, total: total)
                else
                  _buildPaymentMethodsUnavailable(
                    message: lookupsError ?? 'تعذر تحميل طرق الدفع المتاحة.',
                    onRetry: () => _loadLookups(forceRefresh: true),
                  ),
                const SizedBox(height: 8),
                _buildOrderSummary(
                  subtotal: subtotal,
                  shippingCost: shippingCost,
                  total: total,
                  hasSelectedAddress: _selectedAddress != null,
                  hasSupportedCity: hasSupportedShipping,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _BottomBar(
          total: total,
          isLoading: isCreating,
          onConfirm: isCreating || _isEstimatingShipping ? null : _placeOrder,
        ),
      ),
    );
  }

  Widget _buildShippingForm(OrdersLookups? lookups) {
    final selectedAddress = _selectedAddress;
    final hasSupportedShipping = _hasSupportedShipping(lookups);

    return _CheckoutSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckoutSectionTitle(
            icon: AppIcons.location_on_outlined,
            title: 'عنوان التوصيل',
            actionLabel: selectedAddress == null ? 'إضافة' : 'تغيير',
            onAction: selectedAddress == null
                ? _openMapForNewAddress
                : _openAddressPicker,
          ),
          const SizedBox(height: 14),
          if (selectedAddress != null) ...[
            Text(
              selectedAddress.fullName.trim().isNotEmpty
                  ? selectedAddress.fullName.trim()
                  : selectedAddress.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mauve,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatAddressLine(selectedAddress),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.taupe,
                height: 1.35,
              ),
            ),
            if (!hasSupportedShipping || _isEstimatingShipping) ...[
              const SizedBox(height: 10),
              Text(
                _shippingSummaryValue(
                  hasSelectedAddress: true,
                  hasSupportedShipping: hasSupportedShipping,
                  shippingCost: _calculateShippingCost(lookups),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasSupportedShipping
                      ? AppColors.taupe
                      : const Color(0xFFB45309),
                ),
              ),
            ],
          ] else ...[
            Text(
              'اختر عنواناً محفوظاً أو أضف موقع توصيل جديداً.',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: AppColors.taupe,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SoftOutlineButton(
                    label: 'العناوين المحفوظة',
                    icon: AppIcons.bookmarks_outlined,
                    onTap: _openAddressPicker,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SoftOutlineButton(
                    label: 'عنوان جديد',
                    icon: AppIcons.add_location_alt_outlined,
                    onTap: _openMapForNewAddress,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodCard({
    required bool hasSelectedAddress,
    required bool hasSupportedShipping,
    required double shippingCost,
  }) {
    final shippingLabel = !hasSelectedAddress
        ? 'اختر العنوان'
        : hasSupportedShipping
        ? _formatShippingMoney(shippingCost)
        : 'غير متاح';

    return _CheckoutSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CheckoutSectionTitle(
            icon: AppIcons.local_shipping_rounded,
            title: 'التوصيل',
          ),
          const SizedBox(height: 17),
          _DeliveryOptionRow(title: 'خدمة التوصيل', price: shippingLabel),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(OrdersLookups lookups, {required double total}) {
    final methods = lookups.enabledPaymentMethods;
    if (methods.isEmpty) {
      return _buildPaymentMethodsUnavailable(
        message: 'لا توجد طرق دفع متاحة حالياً.',
        onRetry: () => _loadLookups(forceRefresh: true),
      );
    }

    final walletBalance = lookups.walletBalance;
    return _CheckoutSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CheckoutSectionTitle(
            icon: AppIcons.credit_card_rounded,
            title: 'طريقة الدفع',
          ),
          const SizedBox(height: 18),
          Row(
            children: methods.map((method) {
              final isInsufficient = method.isWallet && walletBalance < total;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: method == methods.last ? 0 : 8,
                  ),
                  child: _PaymentMethodPill(
                    label: _paymentDisplayLabel(method),
                    value: method.key,
                    groupValue: _selectedPaymentMethod,
                    isDisabled: isInsufficient,
                    onChanged: isInsufficient
                        ? null
                        : (value) => setState(() {
                            _selectedPaymentMethod = value;
                          }),
                  ),
                ),
              );
            }).toList(),
          ),
          if (methods.any((method) => method.isWallet && walletBalance < total))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'رصيد المحفظة غير كافٍ لإتمام هذا الطلب.',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsUnavailable({
    required String message,
    required VoidCallback onRetry,
  }) {
    return _CheckoutSectionCard(
      child: Column(
        children: [
          const _CheckoutSectionTitle(
            icon: AppIcons.error_outline_rounded,
            title: 'طريقة الدفع',
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.taupe,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _SoftOutlineButton(
            label: 'إعادة المحاولة',
            icon: AppIcons.refresh_rounded,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }

  String _paymentDisplayLabel(PaymentMethodLookup method) {
    if (method.isMoamalat) return 'بطاقة';
    if (method.isWallet) return 'المحفظة';
    if (method.isCod) return 'نقداً';

    final label = method.label.trim();
    if (label.isEmpty) return 'دفع';
    final words = label.split(RegExp(r'\s+'));
    return words.first.length > 9 ? words.first.substring(0, 9) : words.first;
  }

  void _syncWalletBalanceAfterCheckout({
    required OrdersLookups lookups,
    required double paidAmount,
  }) {
    final nextBalance = (lookups.walletBalance - paidAmount).clamp(
      0.0,
      double.infinity,
    );

    context.read<OrdersProvider>().updateLookupsWalletBalance(nextBalance);
    context.read<WalletProvider>().updateLocalBalance(nextBalance);

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      authProvider.updateUser(user.copyWith(walletBalance: nextBalance));
    }
  }

  Widget _buildOrderSummary({
    required double subtotal,
    required double shippingCost,
    required double total,
    required bool hasSelectedAddress,
    required bool hasSupportedCity,
  }) {
    final shippingValue = _shippingSummaryValue(
      hasSelectedAddress: hasSelectedAddress,
      hasSupportedShipping: hasSupportedCity,
      shippingCost: shippingCost,
    );

    return _CheckoutSectionCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        children: [
          _SummaryRow(title: 'المجموع الفرعي', value: _formatMoney(subtotal)),
          const SizedBox(height: 13),
          _SummaryRow(title: 'رسوم التوصيل', value: shippingValue),
          const SizedBox(height: 13),
          _SummaryRow(title: 'الضريبة', value: _formatMoney(0)),
          const SizedBox(height: 17),
          Divider(color: AppColors.divider.withValues(alpha: 0.85), height: 1),
          const SizedBox(height: 20),
          _SummaryRow(
            title: 'الإجمالي',
            value: _formatMoney(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.roseGold.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  AppIcons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppColors.mauve,
                ),
              ),
            ),
          ),
          Text(
            'إتمام الطلب',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.mauve,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CheckoutSectionCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(19, 20, 19, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseGold.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CheckoutSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CheckoutSectionTitle({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.roseGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.mauve,
              height: 1,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                actionLabel!,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.roseGold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SoftOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SoftOutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.rosePink.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.roseGold),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.taupe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryOptionRow extends StatelessWidget {
  final String title;
  final String price;

  const _DeliveryOptionRow({required this.title, required this.price});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.rosePink.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.radio_button_checked_rounded,
            size: 17,
            color: AppColors.roseGold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.mauve,
              ),
            ),
          ),
          Text(
            price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.roseGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodPill extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String?>? onChanged;
  final bool isDisabled;

  const _PaymentMethodPill({
    required this.label,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: isDisabled ? null : () => onChanged?.call(value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 43,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.surfaceVariant.withValues(alpha: 0.55)
              : isSelected
              ? const Color(0xFFC77F91)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: AppColors.rosePink.withValues(alpha: 0.28),
                  width: 1,
                ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDisabled
                ? AppColors.textHint
                : isSelected
                ? Colors.white
                : AppColors.taupe,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = isTotal
        ? GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.mauve,
          )
        : GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.taupe,
          );

    return Row(
      children: [
        Text(title, style: titleStyle),
        const Spacer(),
        Text(
          value,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.cairo(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: AppColors.mauve,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double total;
  final bool isLoading;
  final VoidCallback? onConfirm;

  const _BottomBar({
    required this.total,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Opacity(
          opacity: onConfirm == null ? 0.62 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onConfirm,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFC77F91),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text(
                          'تأكيد الطلب · ${_formatMoney(total)}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAddressLine(AddressModel address) {
  final parts = <String>[
    address.addressLine1,
    if ((address.addressLine2 ?? '').trim().isNotEmpty) address.addressLine2!,
    address.city,
    if ((address.postalCode ?? '').trim().isNotEmpty) address.postalCode!,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();

  if (parts.isEmpty && address.formattedAddress.trim().isNotEmpty) {
    return address.formattedAddress.trim();
  }

  return parts.join(' · ');
}

String _formatMoney(num value) {
  return '${value.round()} د.ل';
}

String _formatShippingMoney(double value) {
  if (value <= 0) return 'مجاني';
  return '${value.round()} د.ل';
}
