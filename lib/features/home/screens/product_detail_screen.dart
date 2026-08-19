import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../shared/widgets/aila_ui.dart';
import '../../cart/providers/cart_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../../core/utils/app_notifications.dart';
import '../../../core/models/product_model.dart';
import '../providers/home_provider.dart';

/// Returns the elegant AILA product title style: Playfair Display serif for
/// Latin names (matching the Lovable `text-display` token), Cairo for Arabic
/// names since Playfair has no Arabic glyphs.
bool _containsArabic(String value) => RegExp(r'[؀-ۿ]').hasMatch(value);

TextStyle _ailaProductTitle(
  String text, {
  double size = 28,
  Color color = AppColors.mauve,
}) {
  if (_containsArabic(text)) {
    return GoogleFonts.cairo(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.18,
    );
  }
  // Latin names use Playfair Display (letter-spacing -0.015em) to mirror the
  // Lovable design's serif display type.
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.06,
    letterSpacing: size * -0.015,
  );
}

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedTab = 0;
  ProductModel? _productDetails;
  List<ProductModel> _relatedProducts = const [];
  bool _isLoadingDetails = false;
  String? _selectedImageUrl;
  String? _selectedColorValue;
  late PageController _pageController;
  late ValueNotifier<String?> _selectedImageNotifier;

  ProductModel get _currentProduct => _productDetails ?? widget.product;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedImageUrl = _normalizeImageUrl(widget.product.thumbnail);
    _selectedImageNotifier = ValueNotifier<String?>(_selectedImageUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductDetails();
      _loadRelatedProducts();
    });
  }

  @override
  void dispose() {
    _selectedImageNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _normalizeColorValue(String value) => value.trim().toLowerCase();

  bool _sameColorValue(String left, String right) =>
      _normalizeColorValue(left) == _normalizeColorValue(right);

  bool _isHexColor(String value) => RegExp(
    r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  ).hasMatch(value.trim());

  bool _isColorVariant(VariantModel variant) =>
      variant.type.trim().toLowerCase() == 'color';

  void _setSelectedImage(String? imageUrl) {
    final normalized = _normalizeImageUrl(imageUrl);
    if (_selectedImageUrl == normalized) {
      return;
    }

    _selectedImageUrl = normalized;
    _selectedImageNotifier.value = normalized;
  }

  Color? _parseColorValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lower = normalized.toLowerCase();
    switch (lower) {
      case 'black':
      case 'أسود':
      case 'اسود':
        return Colors.black;
      case 'white':
      case 'أبيض':
      case 'ابيض':
        return Colors.white;
      case 'red':
      case 'أحمر':
      case 'احمر':
        return Colors.red;
      case 'green':
      case 'أخضر':
      case 'اخضر':
        return Colors.green;
      case 'blue':
      case 'أزرق':
      case 'ازرق':
        return Colors.blue;
      case 'yellow':
      case 'أصفر':
      case 'اصفر':
        return Colors.yellow;
      case 'orange':
      case 'برتقالي':
        return Colors.orange;
      case 'purple':
      case 'بنفسجي':
        return Colors.purple;
      case 'pink':
      case 'وردي':
        return Colors.pink;
      case 'brown':
      case 'بني':
        return Colors.brown;
      case 'grey':
      case 'gray':
      case 'رمادي':
        return Colors.grey;
      case 'silver':
      case 'فضي':
        return const Color(0xFFC0C0C0);
      case 'gold':
      case 'ذهبي':
        return const Color(0xFFFFD700);
      case 'navy':
      case 'كحلي':
        return const Color(0xFF8E4A54);
    }

    if (!_isHexColor(normalized)) {
      return null;
    }

    var hex = normalized.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    return Color(int.parse(hex, radix: 16));
  }

  String? _colorDisplayLabel(String value) {
    final lower = value.trim().toLowerCase();
    switch (lower) {
      case '#000000':
      case 'black':
      case 'أسود':
      case 'اسود':
        return 'أسود';
      case '#ffffff':
      case 'white':
      case 'أبيض':
      case 'ابيض':
        return 'أبيض';
      case '#ff0000':
      case 'red':
      case 'أحمر':
      case 'احمر':
        return 'أحمر';
      case '#00ff00':
      case 'green':
      case 'أخضر':
      case 'اخضر':
        return 'أخضر';
      case '#0000ff':
      case 'blue':
      case 'أزرق':
      case 'ازرق':
        return 'أزرق';
      case '#ffff00':
      case 'yellow':
      case 'أصفر':
      case 'اصفر':
        return 'أصفر';
      case 'orange':
      case 'برتقالي':
        return 'برتقالي';
      case 'purple':
      case 'بنفسجي':
        return 'بنفسجي';
      case 'pink':
      case 'وردي':
        return 'وردي';
      case 'brown':
      case 'بني':
        return 'بني';
      case 'grey':
      case 'gray':
      case 'رمادي':
        return 'رمادي';
      case 'silver':
      case 'فضي':
        return 'فضي';
      case 'gold':
      case 'ذهبي':
        return 'ذهبي';
      case 'navy':
      case 'كحلي':
        return 'كحلي';
    }

    if (_isHexColor(value)) {
      return null;
    }

    return value.trim().isEmpty ? null : value.trim();
  }

  List<String> _buildColorValues(ProductModel product) {
    final values = <String>[];

    void addValue(String? rawValue) {
      final value = rawValue?.trim();
      if (value == null || value.isEmpty) {
        return;
      }
      if (values.any((item) => _sameColorValue(item, value))) {
        return;
      }
      values.add(value);
    }

    for (final color in product.options?.colors ?? const <String>[]) {
      addValue(color);
    }

    for (final variant in product.variants ?? const <VariantModel>[]) {
      if (_isColorVariant(variant)) {
        addValue(variant.value);
      }
    }

    return values;
  }

  String? _resolveSelectedColorValue(
    List<String> colorValues, {
    String? preferredValue,
  }) {
    final candidate = preferredValue ?? _selectedColorValue;
    if (candidate != null) {
      for (final colorValue in colorValues) {
        if (_sameColorValue(colorValue, candidate)) {
          return colorValue;
        }
      }
    }

    return colorValues.isNotEmpty ? colorValues.first : null;
  }

  VariantModel? _findColorVariant(ProductModel product, String? colorValue) {
    if (colorValue == null) {
      return null;
    }

    for (final variant in product.variants ?? const <VariantModel>[]) {
      if (_isColorVariant(variant) &&
          _sameColorValue(variant.value, colorValue)) {
        return variant;
      }
    }

    return null;
  }

  int _maxPurchasableQuantity(ProductModel product, VariantModel? variant) {
    return variant?.maxPurchasableQuantity ?? product.maxPurchasableQuantity;
  }

  void _fitQuantityToStock(int maxQuantity) {
    if (maxQuantity <= 0) {
      _quantity = 1;
      return;
    }

    if (_quantity > maxQuantity) {
      _quantity = maxQuantity;
      return;
    }

    if (_quantity < 1) {
      _quantity = 1;
    }
  }

  void _selectColor(ProductModel product, String colorValue) {
    final variant = _findColorVariant(product, colorValue);
    final variantImageUrl = _normalizeImageUrl(variant?.imageUrl);
    final maxQuantity = _maxPurchasableQuantity(product, variant);

    setState(() {
      _selectedColorValue = colorValue;
      _fitQuantityToStock(maxQuantity);
      if (variantImageUrl != null) {
        _setSelectedImage(variantImageUrl);

        // Find index and animate PageView
        final galleryUrls = _buildGalleryImageUrls(product);
        final index = galleryUrls.indexOf(variantImageUrl);
        if (index != -1 && _pageController.hasClients) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  List<String> _buildGalleryImageUrls(ProductModel product) {
    final urls = <String>[];
    final thumbnailUrl = _normalizeImageUrl(product.thumbnail);
    if (thumbnailUrl != null) {
      urls.add(thumbnailUrl);
    }

    final images = [...?product.images]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) {
          return a.isPrimary ? -1 : 1;
        }
        return a.sortOrder.compareTo(b.sortOrder);
      });

    for (final image in images) {
      final imageUrl = _normalizeImageUrl(image.url);
      if (imageUrl != null && !urls.contains(imageUrl)) {
        urls.add(imageUrl);
      }
    }

    for (final variant in product.variants ?? const <VariantModel>[]) {
      if (!_isColorVariant(variant)) {
        continue;
      }

      final imageUrl = _normalizeImageUrl(variant.imageUrl);
      if (imageUrl != null && !urls.contains(imageUrl)) {
        urls.add(imageUrl);
      }
    }

    return urls;
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final details = await context
          .read<HomeProvider>()
          .repository
          .fetchProductDetails(widget.product.slug);

      if (!mounted) {
        return;
      }

      final galleryImageUrls = _buildGalleryImageUrls(details);
      final currentSelectedImage = _normalizeImageUrl(_selectedImageUrl);
      final colorValues = _buildColorValues(details);
      final selectedColorValue = _resolveSelectedColorValue(colorValues);
      final selectedColorVariant = _findColorVariant(
        details,
        selectedColorValue,
      );
      final selectedColorImageUrl = _normalizeImageUrl(
        selectedColorVariant?.imageUrl,
      );
      final resolvedSelectedImageUrl =
          selectedColorImageUrl ??
          (galleryImageUrls.contains(currentSelectedImage)
              ? currentSelectedImage
              : (galleryImageUrls.isNotEmpty ? galleryImageUrls.first : null));

      setState(() {
        _productDetails = details;
        _selectedColorValue = selectedColorValue;
        final maxQuantity = _maxPurchasableQuantity(
          details,
          selectedColorVariant,
        );
        _fitQuantityToStock(maxQuantity);
        _isLoadingDetails = false;
      });
      _setSelectedImage(resolvedSelectedImageUrl);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _loadRelatedProducts() async {
    final repository = context.read<HomeProvider>().repository;
    final categorySlug = widget.product.category?.slug;
    try {
      final response = await repository.fetchProducts(
        categorySlug: categorySlug,
        perPage: 10,
        sort: 'recommended',
      );
      if (!mounted) return;
      final products = (response['products'] as List<ProductModel>)
          .where((p) => p.id != widget.product.id)
          .take(8)
          .toList();
      setState(() => _relatedProducts = products);
    } catch (_) {
      // Related products are optional — fail silently.
    }
  }

  CartItem _buildCartItem({
    required ProductModel product,
    required double effectivePrice,
    required VariantModel? selectedColorVariant,
    required String? selectedColorValue,
    required int maxQuantity,
    required bool isPurchasable,
    required int quantity,
  }) {
    final selectedColorLabel = selectedColorValue == null
        ? null
        : (_colorDisplayLabel(selectedColorValue) ?? selectedColorValue);

    return CartItem(
      id: CartItem.buildId(
        productId: product.id,
        productVariantId: selectedColorVariant?.id,
        variantKey: selectedColorValue,
      ),
      productId: product.id,
      productVariantId: selectedColorVariant?.id,
      name: product.name,
      variantInfo: selectedColorLabel == null
          ? null
          : 'اللون: $selectedColorLabel',
      price: effectivePrice,
      imageUrl: _selectedImageUrl ?? product.thumbnail ?? '',
      maxQuantity: maxQuantity,
      isAvailable: isPurchasable,
      quantity: quantity,
    );
  }

  void _addToBag({
    required ProductModel product,
    required double effectivePrice,
    required VariantModel? selectedColorVariant,
    required String? selectedColorValue,
    required int maxQuantity,
    required bool isPurchasable,
  }) {
    if (!isPurchasable) {
      AppNotifications.showError(context, 'هذا المنتج غير متوفر حالياً');
      return;
    }

    final result = context.read<CartProvider>().addItem(
      _buildCartItem(
        product: product,
        effectivePrice: effectivePrice,
        selectedColorVariant: selectedColorVariant,
        selectedColorValue: selectedColorValue,
        maxQuantity: maxQuantity,
        isPurchasable: isPurchasable,
        quantity: _quantity,
      ),
    );

    if (!result.didChange) {
      AppNotifications.showError(
        context,
        result.isLimitReached
            ? 'الكمية المتاحة حالياً ${result.maxQuantity ?? maxQuantity} فقط'
            : 'هذا المنتج غير متوفر حالياً',
      );
      return;
    }

    HapticFeedback.lightImpact();
    AppNotifications.showSuccess(context, 'تمت إضافة المنتج إلى الحقيبة');
  }

  void _openCart() {
    context.read<AppShellController>().setIndex(AppShellController.cartIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    // Image stage takes ~58% of the viewport height (Lovable `h-[58vh]`),
    // gently clamped so it stays graceful on very small / very tall devices.
    final headerHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      380.0,
      560.0,
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final galleryCacheWidth =
        (MediaQuery.sizeOf(context).width * devicePixelRatio).round().clamp(
          720,
          1600,
        );
    final galleryImageUrls = _buildGalleryImageUrls(product);
    final colorValues = _buildColorValues(product);
    final selectedColorValue = _resolveSelectedColorValue(colorValues);
    final selectedColorVariant = _findColorVariant(product, selectedColorValue);
    final effectivePrice =
        selectedColorVariant?.finalPrice ?? product.pricing.effectivePrice;
    final isPurchasable = selectedColorVariant != null
        ? product.stock.isAvailable && selectedColorVariant.isAvailable
        : product.isPurchasable;
    final maxQuantity = _maxPurchasableQuantity(product, selectedColorVariant);
    final canDecreaseQuantity = isPurchasable && _quantity > 1;
    final canIncreaseQuantity = isPurchasable && _quantity < maxQuantity;
    final eyebrowLabel = (product.brand?.name ?? product.category?.name)
        ?.trim();
    final subtitleText = product.shortDescription?.trim();
    final lineTotal = effectivePrice * _quantity;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ImageHeader(
                    product: product,
                    headerHeight: headerHeight,
                    galleryImageUrls: galleryImageUrls,
                    cacheWidth: galleryCacheWidth,
                    pageController: _pageController,
                    selectedImageNotifier: _selectedImageNotifier,
                    onPageChanged: (index) {
                      if (galleryImageUrls.isNotEmpty) {
                        _setSelectedImage(galleryImageUrls[index]);
                      }
                    },
                    onDotTap: (index) {
                      _setSelectedImage(galleryImageUrls[index]);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    onBack: () => Navigator.pop(context),
                    onCart: _openCart,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildContent(
                    product: product,
                    headerHeight: headerHeight,
                    eyebrowLabel: eyebrowLabel,
                    subtitleText: subtitleText,
                    colorValues: colorValues,
                    selectedColorValue: selectedColorValue,
                    effectivePrice: effectivePrice,
                    canDecreaseQuantity: canDecreaseQuantity,
                    canIncreaseQuantity: canIncreaseQuantity,
                  ),
                ),
              ],
            ),

            // --- Bottom Action Bar (TOTAL + Add to Bag) ---
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                total: lineTotal,
                isPurchasable: isPurchasable,
                onAddToBag: () => _addToBag(
                  product: product,
                  effectivePrice: effectivePrice,
                  selectedColorVariant: selectedColorVariant,
                  selectedColorValue: selectedColorValue,
                  maxQuantity: maxQuantity,
                  isPurchasable: isPurchasable,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required ProductModel product,
    required double headerHeight,
    required String? eyebrowLabel,
    required String? subtitleText,
    required List<String> colorValues,
    required String? selectedColorValue,
    required double effectivePrice,
    required bool canDecreaseQuantity,
    required bool canIncreaseQuantity,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - headerHeight + 32,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      transform: Matrix4.translationValues(0, -32, 0),
      child: Padding(
        // Top padding must clear the 32px overlap so the title sits comfortably
        // below the image (visible gap = 48 - 32 = 16px), not on top of it.
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingDetails)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),

            _ProductHeading(
              productName: product.name,
              eyebrowLabel: eyebrowLabel,
              subtitleText: subtitleText,
            ),

            // Rating — hidden for brand-new products that have no reviews yet.
            if (product.rating.count > 0) ...[
              const SizedBox(height: 16),
              _RatingRow(rating: product.rating),
            ],
            const SizedBox(height: 24),

            // Tabs
            _TabPills(
              labels: const ['الوصف', 'المكوّنات', 'طريقة الاستخدام'],
              selectedIndex: _selectedTab,
              onChanged: (i) => setState(() => _selectedTab = i),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedTab),
                child: _buildTabBody(product),
              ),
            ),
            const SizedBox(height: 28),

            // Colors
            if (colorValues.isNotEmpty) ...[
              _buildColorsSection(product, colorValues, selectedColorValue),
              const SizedBox(height: 28),
            ],

            // Sizes
            if (product.options?.sizes.isNotEmpty ?? false) ...[
              _buildSizesSection(product),
              const SizedBox(height: 28),
            ],

            // Quantity
            Row(
              children: [
                Text(
                  'الكمية',
                  style: GoogleFonts.cairo(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mauve,
                  ),
                ),
                const Spacer(),
                _QuantityStepper(
                  quantity: _quantity,
                  canDecrease: canDecreaseQuantity,
                  canIncrease: canIncreaseQuantity,
                  onDecrease: () {
                    if (!canDecreaseQuantity) return;
                    setState(() => _quantity--);
                  },
                  onIncrease: () {
                    if (!canIncreaseQuantity) return;
                    setState(() => _quantity++);
                  },
                ),
              ],
            ),

            // You may also love
            if (_relatedProducts.isNotEmpty) ...[
              const SizedBox(height: 36),
              Text(
                'قد يعجبكِ أيضاً',
                style: GoogleFonts.cairo(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mauve,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _relatedProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _RelatedProductCard(
                      product: _relatedProducts[index],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(ProductModel product) {
    switch (_selectedTab) {
      case 1:
        final ingredients = product.ingredients?.trim();
        if (ingredients != null && ingredients.isNotEmpty) {
          return _buildTabText(ingredients);
        }

        final tags = product.tags ?? const <String>[];
        if (tags.isEmpty) {
          return const _TabPlaceholder(
            text: 'لم تتم إضافة المكوّنات لهذا المنتج بعد',
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mauve,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      case 2:
        final usageInstructions = product.usageInstructions?.trim();
        if (usageInstructions != null && usageInstructions.isNotEmpty) {
          return _buildTabText(usageInstructions);
        }

        final details = <_DetailRow>[
          if (product.brand != null && product.brand!.name.trim().isNotEmpty)
            _DetailRow('العلامة التجارية', product.brand!.name.trim()),
          if (product.category != null &&
              product.category!.name.trim().isNotEmpty)
            _DetailRow('التصنيف', product.category!.name.trim()),
          if (product.weight != null && product.weight!.trim().isNotEmpty)
            _DetailRow('الوزن', product.weight!.trim()),
          if (product.sku != null && product.sku!.trim().isNotEmpty)
            _DetailRow('رمز المنتج', product.sku!.trim()),
        ];
        if (details.isEmpty) {
          return const _TabPlaceholder(
            text: 'لم تتم إضافة تعليمات الاستخدام لهذا المنتج بعد',
          );
        }
        return Column(children: details);
      default:
        final description = product.description?.trim();
        if (description == null || description.isEmpty) {
          return const _TabPlaceholder(text: 'لا يوجد وصف متاح لهذا المنتج');
        }
        return Text(description, style: _tabBodyTextStyle);
    }
  }

  TextStyle get _tabBodyTextStyle => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.taupe,
    height: 1.7,
  );

  Widget _buildTabText(String text) {
    return Text(text, style: _tabBodyTextStyle);
  }

  Widget _buildColorsSection(
    ProductModel product,
    List<String> colorValues,
    String? selectedColorValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'اللون',
              style: GoogleFonts.cairo(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mauve,
              ),
            ),
            if (selectedColorValue != null &&
                _colorDisplayLabel(selectedColorValue) != null) ...[
              const SizedBox(width: 8),
              Text(
                _colorDisplayLabel(selectedColorValue)!,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.taupe,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colorValues.map((colorValue) {
            final swatchColor = _parseColorValue(colorValue);
            final isSelected =
                selectedColorValue != null &&
                _sameColorValue(selectedColorValue, colorValue);
            final hasValidColor = swatchColor != null;

            return GestureDetector(
              onTap: () => _selectColor(product, colorValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                width: isSelected ? 48 : 42,
                height: isSelected ? 48 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: isSelected ? 2 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.shadowCard,
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isSelected ? 3 : 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasValidColor
                        ? swatchColor
                        : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.divider,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: !hasValidColor
                      ? const Icon(
                          AppIcons.palette_outlined,
                          size: 16,
                          color: AppColors.textHint,
                        )
                      : (isSelected
                            ? Icon(
                                AppIcons.check_rounded,
                                size: 20,
                                color: swatchColor.computeLuminance() > 0.5
                                    ? Colors.black87
                                    : Colors.white,
                              )
                            : null),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSizesSection(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المقاسات',
          style: GoogleFonts.cairo(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mauve,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.options!.sizes.map((sizeName) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                sizeName,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mauve,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Image header ──────────────────────────────────────────────────────────────

class _ImageHeader extends StatelessWidget {
  final ProductModel product;
  final double headerHeight;
  final List<String> galleryImageUrls;
  final int cacheWidth;
  final PageController pageController;
  final ValueNotifier<String?> selectedImageNotifier;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onDotTap;
  final VoidCallback onBack;
  final VoidCallback onCart;

  const _ImageHeader({
    required this.product,
    required this.headerHeight,
    required this.galleryImageUrls,
    required this.cacheWidth,
    required this.pageController,
    required this.selectedImageNotifier,
    required this.onPageChanged,
    required this.onDotTap,
    required this.onBack,
    required this.onCart,
  });

  @override
  Widget build(BuildContext context) {
    final hasImages = galleryImageUrls.isNotEmpty;

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Image gallery on a soft blush stage with a softly rounded base
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.blushGradient,
                ),
                child: PageView.builder(
                  controller: pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: hasImages ? galleryImageUrls.length : 1,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    final imageUrl = hasImages ? galleryImageUrls[index] : null;

                    Widget imageWidget = imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: cacheWidth,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    AppIcons.image_outlined,
                                    size: 120,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                          )
                        : Center(
                            child: Icon(
                              AppIcons.image_outlined,
                              size: 120,
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          );

                    if (index == 0) {
                      return Hero(
                        tag: 'product_icon_${product.id}',
                        child: imageWidget,
                      );
                    }
                    return imageWidget;
                  },
                ),
              ),
            ),
          ),

          // Top buttons (back / cart + favorite)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _GlassCircleButton(
                    icon: AppIcons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    onTap: onBack,
                  ),
                  const Spacer(),
                  Selector<CartProvider, int>(
                    selector: (_, cart) => cart.itemCount,
                    builder: (_, cartCount, _) => _GlassCircleButton(
                      icon: AppIcons.shopping_cart_outlined,
                      iconSize: 18,
                      badgeCount: cartCount,
                      onTap: onCart,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, _) {
                      final isFav = wishlist.isFavorite(product.id);
                      return _GlassCircleButton(
                        icon: isFav
                            ? AppIcons.favorite_rounded
                            : AppIcons.favorite_border_rounded,
                        iconSize: 16,
                        iconColor: isFav ? AppColors.badge : AppColors.roseGold,
                        onTap: () {
                          wishlist.toggleFavorite(product);
                          AppNotifications.showSuccess(
                            context,
                            isFav
                                ? 'تمت الإزالة من المفضلة'
                                : 'تمت الإضافة للمفضلة',
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Dot indicators
          if (galleryImageUrls.length > 1)
            Positioned(
              bottom: 46,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<String?>(
                  valueListenable: selectedImageNotifier,
                  builder: (context, selectedImageUrl, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(galleryImageUrls.length, (
                          index,
                        ) {
                          final isActive =
                              galleryImageUrls[index] == selectedImageUrl;
                          return GestureDetector(
                            onTap: () => onDotTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isActive
                                    ? AppColors.roseGold
                                    : AppColors.textHint.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final int badgeCount;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 18,
    this.iconColor = AppColors.mauve,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 30,
                    spreadRadius: -10,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.badge,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: GoogleFonts.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductHeading extends StatelessWidget {
  final String productName;
  final String? eyebrowLabel;
  final String? subtitleText;

  const _ProductHeading({
    required this.productName,
    required this.eyebrowLabel,
    required this.subtitleText,
  });

  double _titleSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final length = productName.characters.length;
    // Mirrors Lovable's `text-3xl` (~30px) display title, eased down for
    // longer names and narrow screens.
    final baseSize = width < 360 ? 26.0 : 29.0;

    if (length >= 22) {
      return baseSize - 3;
    }
    if (length >= 16) {
      return baseSize - 1.5;
    }
    return baseSize;
  }

  @override
  Widget build(BuildContext context) {
    final eyebrow = eyebrowLabel?.trim();
    final subtitle = subtitleText?.trim();
    final hasEyebrow = eyebrow != null && eyebrow.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    final hasArabicName = _containsArabic(productName);

    return SizedBox(
      width: double.infinity,
      child: Column(
        // Left-aligned (RTL start) to match the Lovable product header.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEyebrow) ...[
            Text(
              _containsArabic(eyebrow) ? eyebrow : eyebrow.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: _containsArabic(eyebrow) ? 0 : 3.0,
                color: AppColors.roseGold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: _ailaProductTitle(
              productName,
              size: _titleSize(context),
            ).copyWith(height: hasArabicName ? 1.14 : 1.05),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.taupe,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Rating ──────────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final RatingModel rating;

  const _RatingRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final average = rating.average;
    final filledStars = average.round().clamp(0, 5);

    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final isFilled = index < filledStars;
            return Padding(
              padding: EdgeInsetsDirectional.only(end: index == 4 ? 0 : 4),
              child: Icon(
                isFilled ? AppIcons.star_rounded : AppIcons.star_border_rounded,
                size: 14,
                color: AppColors.roseGold,
              ),
            );
          }),
        ),
        const SizedBox(width: 12),
        Text(
          '${average.toStringAsFixed(1)} · ${rating.count} تقييم',
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.taupe,
          ),
        ),
      ],
    );
  }
}

// ─── Tabs ──────────────────────────────────────────────────────────────────────

class _TabPills extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabPills({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isActive = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 20,
                            spreadRadius: -6,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.mauve : AppColors.taupe,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  final String text;

  const _TabPlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          AppIcons.info_outline_rounded,
          size: 18,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textHint,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.taupe,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.mauve,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quantity stepper ────────────────────────────────────────────────────────

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: canDecrease ? onDecrease : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                AppIcons.remove_rounded,
                size: 15,
                color: canDecrease
                    ? AppColors.roseGold
                    : AppColors.textHint.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                '$quantity',
                key: ValueKey<int>(quantity),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mauve,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canIncrease ? onIncrease : null,
            child: Opacity(
              opacity: canIncrease ? 1 : 0.5,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: AppColors.roseGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  AppIcons.add_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom bar ──────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final double total;
  final bool isPurchasable;
  final VoidCallback onAddToBag;

  const _BottomBar({
    required this.total,
    required this.isPurchasable,
    required this.onAddToBag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 30,
            spreadRadius: -6,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الإجمالي',
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.taupe,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${total.toStringAsFixed(2)} د.ل',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mauve,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AilaGradientButton(
                  label: isPurchasable ? 'أضيفي إلى الحقيبة' : 'غير متوفر',
                  icon: AppIcons.shopping_bag_outlined,
                  height: 52,
                  onPressed: isPurchasable ? onAddToBag : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Related product card ──────────────────────────────────────────────────────

class _RelatedProductCard extends StatelessWidget {
  final ProductModel product;

  const _RelatedProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = product.thumbnail?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final eyebrowRaw = (product.category?.name ?? product.brand?.name)?.trim();
    final eyebrowLabel = (eyebrowRaw != null && eyebrowRaw.isNotEmpty)
        ? eyebrowRaw.toUpperCase()
        : null;
    final subtitle = (product.shortDescription?.trim().isNotEmpty ?? false)
        ? product.shortDescription!.trim()
        : (product.brand?.name ?? '');
    final effectivePrice = product.pricing.effectivePrice;
    final canAdd = product.isPurchasable;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.rosePink.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.blush,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      child: hasThumbnail
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(26),
                              ),
                              child: Image.network(
                                thumbnailUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 360,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        AppIcons.image_outlined,
                                        size: 42,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                AppIcons.image_outlined,
                                size: 42,
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                    ),
                  ),
                  if (product.pricing.isOnSale || product.isFeatured)
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          product.pricing.isOnSale ? 'خصم' : 'مميز',
                          style: GoogleFonts.cairo(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.roseGold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlist, _) {
                        final isFav = wishlist.isFavorite(product.id);
                        return GestureDetector(
                          onTap: () {
                            wishlist.toggleFavorite(product);
                            AppNotifications.showSuccess(
                              context,
                              isFav
                                  ? 'تمت الإزالة من المفضلة'
                                  : 'تمت الإضافة للمفضلة',
                            );
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowCard,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFav
                                  ? AppIcons.favorite_rounded
                                  : AppIcons.favorite_border_rounded,
                              size: 16,
                              color: AppColors.roseGold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrowLabel != null) ...[
                    Text(
                      eyebrowLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.taupe,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ailaProductTitle(product.name, size: 14),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.taupe,
                        height: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                '${effectivePrice.toStringAsFixed(0)} د.ل',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.mauve,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (product.pricing.isOnSale) ...[
                              const SizedBox(width: 5),
                              Text(
                                product.pricing.price.toStringAsFixed(0),
                                style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHint,
                                  decoration: TextDecoration.lineThrough,
                                  height: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          if (!canAdd) {
                            AppNotifications.showError(
                              context,
                              'المنتج غير متوفر حالياً',
                            );
                            return;
                          }
                          final result = context.read<CartProvider>().addItem(
                            CartItem(
                              id: CartItem.buildId(productId: product.id),
                              productId: product.id,
                              name: product.name,
                              price: effectivePrice,
                              imageUrl: product.thumbnail ?? '',
                              maxQuantity: product.maxPurchasableQuantity,
                              isAvailable: true,
                              quantity: 1,
                            ),
                          );
                          if (!result.didChange) {
                            AppNotifications.showError(
                              context,
                              result.isLimitReached
                                  ? 'الكمية المتاحة حالياً ${result.maxQuantity ?? product.maxPurchasableQuantity} فقط'
                                  : 'المنتج غير متوفر حالياً',
                            );
                            return;
                          }
                          AppNotifications.showSuccess(
                            context,
                            'تمت إضافة ${product.name} للحقيبة',
                          );
                        },
                        child: Opacity(
                          opacity: canAdd ? 1 : 0.5,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: AppColors.roseGradient,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              AppIcons.add_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
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
}
