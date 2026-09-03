import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_aila/core/theme/app_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import '../services/geocoding_service.dart';
import '../services/places_service.dart';

class AddressMapScreen extends StatefulWidget {
  final AddressModel? editAddress;

  const AddressMapScreen({super.key, this.editAddress});

  @override
  State<AddressMapScreen> createState() => _AddressMapScreenState();
}

class _AddressMapScreenState extends State<AddressMapScreen> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _address1Ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final GeocodingService _geocodingService = GeocodingService();
  final PlacesService _placesService = PlacesService();

  LatLng? _markerPosition;
  String _resolvedAddress = '';
  String _resolvedCity = '';
  String? _placeId;
  String? _selectedCity;
  String _lastAutofilledAddressLine1 = '';
  bool _isOutsideMisrata = false;
  bool _isGeocodingLoading = false;
  bool _showBottomPanel = false;
  bool _isSaving = false;

  List<PlacePrediction> _predictions = const <PlacePrediction>[];
  bool _showPredictions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _labelCtrl.text = widget.editAddress?.label ?? 'البيت';
    _notesCtrl.text = widget.editAddress?.notes ?? '';
    _address1Ctrl.text = widget.editAddress?.addressLine1 ?? '';
    _selectedCity = widget.editAddress?.city;
    _lastAutofilledAddressLine1 = widget.editAddress?.addressLine1 ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _labelCtrl.dispose();
    _notesCtrl.dispose();
    _address1Ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final provider = context.read<AddressProvider>();
    if (provider.mapConfig == null) {
      await provider.loadMapConfig();
    }
    if (!mounted) return;

    final config = provider.mapConfig;
    if (config == null) return;

    if (widget.editAddress != null) {
      final address = widget.editAddress!;
      final target = LatLng(address.location.lat, address.location.lng);
      await _moveCamera(target);
      if (!mounted) return;

      setState(() {
        _markerPosition = target;
        _resolvedAddress = address.formattedAddress;
        _placeId = address.placeId;
        _showBottomPanel = true;
      });
      _syncCityStateForLocation(
        target,
        detectedCity: address.city,
        preserveManualSelection: true,
      );
      return;
    }

    if (config.defaultAddress != null) {
      final loc = config.defaultAddress!.location;
      await _moveCamera(LatLng(loc.lat, loc.lng));
      return;
    }

    await _moveCamera(
      LatLng(config.defaultCenter.lat, config.defaultCenter.lng),
    );
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 14.5}) async {
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      _markerPosition = pos;
      _showBottomPanel = true;
    });
    _reverseGeocode(pos);
  }

  void _onMarkerDragEnd(LatLng pos) {
    setState(() {
      _markerPosition = pos;
      _showBottomPanel = true;
    });
    _reverseGeocode(pos);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isGeocodingLoading = true);

    try {
      final config = context.read<AddressProvider>().mapConfig;
      final result = await _geocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;

      if (result != null) {
        final detectedSupportedCity = config?.findSupportedCity(<String?>[
          result.city,
          result.formattedAddress,
          result.street,
        ]);

        setState(() {
          _resolvedAddress = result.formattedAddress;
          _placeId = result.placeId.isNotEmpty ? result.placeId : null;
          _syncAddressLine1FromAutoCandidate(
            result.street.isNotEmpty ? result.street : result.formattedAddress,
          );
          _resolvedCity = detectedSupportedCity?.name ?? result.city;
          _showBottomPanel = true;
        });

        _syncCityStateForLocation(
          pos,
          detectedCity: detectedSupportedCity?.name ?? result.city,
          preserveManualSelection: true,
        );
      } else {
        setState(() {
          _resolvedCity = '';
          _showBottomPanel = true;
        });
        _syncCityStateForLocation(pos, preserveManualSelection: true);
      }

      _triggerRouteEstimate(pos);
    } finally {
      if (mounted) {
        setState(() => _isGeocodingLoading = false);
      }
    }
  }

  void _syncAddressLine1FromAutoCandidate(String candidate) {
    final normalizedCandidate = candidate.trim();
    if (normalizedCandidate.isEmpty) return;

    final currentValue = _address1Ctrl.text.trim();
    if (currentValue.isEmpty ||
        currentValue == _lastAutofilledAddressLine1 ||
        currentValue == _resolvedAddress) {
      _address1Ctrl.text = normalizedCandidate;
      _lastAutofilledAddressLine1 = normalizedCandidate;
    }
  }

  void _syncCityStateForLocation(
    LatLng pos, {
    String detectedCity = '',
    bool preserveManualSelection = false,
  }) {
    final config = context.read<AddressProvider>().mapConfig;
    if (config == null) {
      setState(() {
        _resolvedCity = detectedCity;
        _selectedCity = detectedCity.trim().isNotEmpty
            ? detectedCity.trim()
            : null;
        _isOutsideMisrata = false;
      });
      return;
    }

    final matchedDetectedCity = config.findCity(detectedCity);
    final insideMisrata = config.isInsideMisrataBoundary(
      lat: pos.latitude,
      lng: pos.longitude,
      detectedCity: detectedCity,
    );

    if (insideMisrata) {
      final misrataName =
          config.misrataCity?.name ??
          matchedDetectedCity?.name ??
          (detectedCity.trim().isNotEmpty ? detectedCity.trim() : 'مصراتة');
      setState(() {
        _resolvedCity = misrataName;
        _selectedCity = misrataName;
        _isOutsideMisrata = false;
      });
      return;
    }

    final currentSelection = preserveManualSelection && _selectedCity != null
        ? config.findCity(_selectedCity!)
        : null;
    final nextSelection = currentSelection?.name ?? matchedDetectedCity?.name;

    setState(() {
      _resolvedCity = detectedCity.trim();
      _selectedCity = nextSelection;
      _isOutsideMisrata = true;
    });
  }

  void _triggerRouteEstimate(LatLng destination) {
    final config = context.read<AddressProvider>().mapConfig;
    if (config == null) return;

    context.read<AddressProvider>().estimateRoute(
      origin: config.storeLocation,
      destination: AddressLocation(
        lat: destination.latitude,
        lng: destination.longitude,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (mounted) {
        AppNotifications.showError(context, 'خدمة الموقع غير مفعلة');
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          AppNotifications.showError(context, 'لم يتم منح إذن الموقع');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        AppNotifications.showError(
          context,
          'إذن الموقع محظور. افتح الإعدادات.',
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final target = LatLng(position.latitude, position.longitude);
    await _moveCamera(target, zoom: 16);
    _onMapTap(target);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _showPredictions = false);
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _fetchPredictions(value),
    );
  }

  Future<void> _fetchPredictions(String input) async {
    final results = await _placesService.autocomplete(input);
    if (!mounted) return;

    setState(() {
      _predictions = results;
      _showPredictions = results.isNotEmpty;
    });
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    setState(() => _showPredictions = false);
    _searchCtrl.text = prediction.mainText;

    final details = await _placesService.getDetails(prediction.placeId);
    if (details == null || !mounted) return;

    final target = LatLng(details.lat, details.lng);
    await _moveCamera(target, zoom: 16);

    setState(() {
      _markerPosition = target;
      _placeId = prediction.placeId;
      _resolvedAddress = details.formattedAddress;
      _syncAddressLine1FromAutoCandidate(details.formattedAddress);
      _showBottomPanel = true;
    });

    _reverseGeocode(target);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_markerPosition == null) {
      AppNotifications.showError(context, 'يرجى تحديد موقعك على الخريطة');
      return;
    }
    if (_isGeocodingLoading) {
      AppNotifications.showError(context, 'جارٍ تحديد الموقع، يرجى الانتظار.');
      return;
    }

    final selectedCity = _selectedCity?.trim() ?? '';
    if (selectedCity.isEmpty) {
      AppNotifications.showError(
        context,
        _isOutsideMisrata
            ? 'هذا الموقع خارج حدود مصراتة. يرجى اختيار المدينة من القائمة المعتمدة.'
            : 'تعذر تحديد المدينة من الموقع الحالي. حاول تحريك المؤشر إلى نقطة أوضح.',
      );
      return;
    }

    final config = context.read<AddressProvider>().mapConfig;
    final user = context.read<AuthProvider>().user;
    final addressLine1 = _address1Ctrl.text.trim().isNotEmpty
        ? _address1Ctrl.text.trim()
        : (_resolvedAddress.isNotEmpty ? _resolvedAddress : selectedCity);

    setState(() => _isSaving = true);

    final body = <String, dynamic>{
      'label': _labelCtrl.text.trim(),
      'full_name': widget.editAddress?.fullName ?? user?.name ?? '',
      'phone': widget.editAddress?.phone ?? user?.phone ?? '',
      'latitude': _markerPosition!.latitude,
      'longitude': _markerPosition!.longitude,
      'formatted_address': _resolvedAddress,
      'address_line1': addressLine1,
      'city': selectedCity,
      'country': config?.defaultCountry ?? 'Libya',
      if (_placeId != null && _placeId!.trim().isNotEmpty) 'place_id': _placeId,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      'is_default': widget.editAddress?.isDefault ?? false,
    };

    final provider = context.read<AddressProvider>();
    final result = widget.editAddress != null
        ? await provider.updateAddress(widget.editAddress!.id, body)
        : await provider.createAddress(body);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      Navigator.pop(context, result);
    } else {
      AppNotifications.showError(
        context,
        provider.saveError ?? 'تعذر حفظ العنوان',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddressProvider>();
    final config = provider.mapConfig;

    final initialPosition = widget.editAddress != null
        ? LatLng(
            widget.editAddress!.location.lat,
            widget.editAddress!.location.lng,
          )
        : config != null
        ? LatLng(config.defaultCenter.lat, config.defaultCenter.lng)
        : const LatLng(32.8872, 13.1913);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 13,
              ),
              onMapCreated: (controller) => _mapController.complete(controller),
              onTap: _onMapTap,
              markers: {
                if (_markerPosition != null)
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: _markerPosition!,
                    draggable: true,
                    onDragEnd: _onMarkerDragEnd,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRose,
                    ),
                  ),
                if (config != null)
                  Marker(
                    markerId: const MarkerId('store'),
                    position: LatLng(
                      config.storeLocation.lat,
                      config.storeLocation.lng,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                    infoWindow: const InfoWindow(title: 'موقع المتجر'),
                  ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (_isGeocodingLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppColors.accent,
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      children: [
                        _circleBtn(
                          AppIcons.arrow_back_ios_new_rounded,
                          () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _searchField()),
                      ],
                    ),
                  ),
                  if (_showPredictions && _predictions.isNotEmpty)
                    _predictionsDropdown(),
                ],
              ),
            ),
            Positioned(
              left: 18,
              bottom: _showBottomPanel
                  ? MediaQuery.sizeOf(context).height * 0.56 + 16
                  : 92,
              child: _circleBtn(
                AppIcons.my_location_rounded,
                _goToMyLocation,
                color: AppColors.primary,
                iconColor: AppColors.surface,
              ),
            ),
            if (_markerPosition == null && !provider.isLoadingConfig)
              _buildHint(),
            if (_showBottomPanel || widget.editAddress != null)
              _buildBottomSheet(provider, config),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.neutral.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
        textDirection: TextDirection.rtl,
        style: GoogleFonts.cairo(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن موقع أو عنوان...',
          hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textHint),
          prefixIcon: const Icon(
            AppIcons.search_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    AppIcons.close_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _showPredictions = false);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _predictionsDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 72, 0),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _predictions.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: AppColors.divider,
          ),
          itemBuilder: (_, index) {
            final prediction = _predictions[index];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              leading: const Icon(
                AppIcons.location_on_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              title: Text(
                prediction.mainText,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                prediction.secondaryText,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => _onPredictionSelected(prediction),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 80),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.neutral.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.touch_app_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'اضغط على الخريطة لتحديد موقعك',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(AddressProvider provider, MapConfig? config) {
    final selectedCityConfig = config?.findCity(_selectedCity ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.24,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const <double>[0.24, 0.56, 0.9],
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowFloat,
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.neutral.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.editAddress != null
                      ? 'تعديل تفاصيل العنوان'
                      : 'تفاصيل عنوان التوصيل',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'راجعي الموقع وأضيفي التفاصيل التي تساعد مندوب التوصيل.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_resolvedAddress.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowCard,
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.location_on_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _resolvedAddress,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _buildCityStateCard(selectedCityConfig),
                if (_isOutsideMisrata) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    decoration: _inputDecoration(
                      'اختر المدينة المعتمدة',
                      AppIcons.location_city_rounded,
                    ),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    validator: (value) {
                      if (_isOutsideMisrata &&
                          (value == null || value.trim().isEmpty)) {
                        return 'يرجى اختيار المدينة من القائمة المعتمدة';
                      }
                      return null;
                    },
                    items: (config?.supportedCities ?? const <SupportedCity>[])
                        .map(
                          (city) => DropdownMenuItem<String>(
                            value: city.name,
                            child: Text(
                              '${city.name} - ${city.shippingCost.toStringAsFixed(0)} د.ل',
                              style: GoogleFonts.cairo(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCity = value);
                    },
                  ),
                ],
                if (provider.isEstimating) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: AppColors.accent),
                ] else if (provider.routeEstimate != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        AppIcons.straighten_rounded,
                        provider.routeEstimate!.distanceText,
                      ),
                      _chip(
                        AppIcons.access_time_rounded,
                        provider.routeEstimate!.durationText,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _field(
                  _labelCtrl,
                  'اسم العنوان',
                  AppIcons.title_rounded,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 10),
                _field(
                  _address1Ctrl,
                  'العنوان التفصيلي',
                  AppIcons.home_rounded,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 10),
                _field(
                  _notesCtrl,
                  'ملاحظات للمندوب (اختياري)',
                  AppIcons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Opacity(
                    opacity: _isSaving ? 0.72 : 1,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSaving ? null : _save,
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowSoft,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: AppColors.surface,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    widget.editAddress != null
                                        ? 'حفظ التعديلات'
                                        : 'حفظ العنوان',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.surface,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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

  Widget _buildCityStateCard(SupportedCity? selectedCityConfig) {
    final title = _isOutsideMisrata
        ? (_selectedCity?.trim().isNotEmpty == true
              ? _selectedCity!
              : 'خارج حدود مصراتة')
        : (_selectedCity ?? _resolvedCity);

    final subtitle = _isOutsideMisrata
        ? 'هذا الموقع خارج حدود مصراتة، لذلك يجب اختيار مدينة من القائمة المعتمدة قبل الحفظ.'
        : 'داخل حدود مصراتة، سيتم اعتماد المدينة تلقائيًا على أنها مصراتة.';

    final badgeText = _isOutsideMisrata
        ? (_selectedCity?.trim().isNotEmpty == true
              ? 'اختيار يدوي'
              : 'اختر مدينة')
        : 'افتراضي';

    final badgeColor = _isOutsideMisrata
        ? const Color(0xFF92400E)
        : AppColors.accent;
    final badgeBg = _isOutsideMisrata
        ? const Color(0xFFFFF7ED)
        : AppColors.secondary;
    final badgeBorder = _isOutsideMisrata
        ? const Color(0xFFFCD34D)
        : AppColors.neutral;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isOutsideMisrata ? const Color(0xFFFFFBEB) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOutsideMisrata
              ? const Color(0xFFFDE68A)
              : AppColors.divider,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.trim().isNotEmpty
                          ? title.trim()
                          : 'سيتم تحديد المدينة من الموقع',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          if (selectedCityConfig != null) ...[
            const SizedBox(height: 10),
            Text(
              'سعر التوصيل لهذه المدينة: ${selectedCityConfig.shippingCost.toStringAsFixed(0)} د.ل',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _circleBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = AppColors.surface,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color == AppColors.surface
                  ? AppColors.neutral.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.neutral.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      textDirection: TextDirection.rtl,
      style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(
        color: AppColors.textHint,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
