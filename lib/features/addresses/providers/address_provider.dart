import 'package:flutter/foundation.dart';
import '../models/address_model.dart';
import '../repositories/address_repository.dart';

class AddressProvider extends ChangeNotifier {
  final AddressRepository _repo;

  AddressProvider(this._repo);

  // ── Map Config ──────────────────────────────────────────────────────────────
  MapConfig? _mapConfig;
  bool _isLoadingConfig = false;
  String? _configError;

  MapConfig? get mapConfig => _mapConfig;
  bool get isLoadingConfig => _isLoadingConfig;
  String? get configError => _configError;

  Future<void> loadMapConfig({bool forceRefresh = false}) async {
    if (_mapConfig != null && !forceRefresh) return;
    _isLoadingConfig = true;
    _configError = null;
    notifyListeners();

    try {
      _mapConfig = await _repo.fetchMapConfig();
    } catch (e) {
      _configError = e.toString();
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  // ── Addresses List ───────────────────────────────────────────────────────────
  List<AddressModel> _addresses = [];
  bool _isLoadingAddresses = false;
  String? _addressesError;

  List<AddressModel> get addresses => _addresses;
  bool get isLoadingAddresses => _isLoadingAddresses;
  String? get addressesError => _addressesError;

  AddressModel? get defaultAddress {
    try {
      return _addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  Future<void> loadAddresses({bool forceRefresh = false}) async {
    if (_addresses.isNotEmpty && !forceRefresh) return;
    _isLoadingAddresses = true;
    _addressesError = null;
    notifyListeners();

    try {
      _addresses = await _repo.fetchAddresses();
    } catch (e) {
      _addressesError = e.toString();
    } finally {
      _isLoadingAddresses = false;
      notifyListeners();
    }
  }

  // ── Save (Create / Update) ───────────────────────────────────────────────────
  bool _isSaving = false;
  String? _saveError;

  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  /// إنشاء عنوان جديد — returns the created AddressModel or null on error
  Future<AddressModel?> createAddress(Map<String, dynamic> body) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final created = await _repo.createAddress(body);
      _addresses = [created, ..._addresses];
      if (created.isDefault) _markOnlyOneDefault(created.id);
      notifyListeners();
      return created;
    } catch (e) {
      _saveError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// تعديل عنوان موجود — returns updated AddressModel or null on error
  Future<AddressModel?> updateAddress(int id, Map<String, dynamic> body) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final updated = await _repo.updateAddress(id, body);
      final idx = _addresses.indexWhere((a) => a.id == id);
      if (idx != -1) {
        _addresses = List.from(_addresses)..[idx] = updated;
      }
      if (updated.isDefault) _markOnlyOneDefault(updated.id);
      notifyListeners();
      return updated;
    } catch (e) {
      _saveError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────────
  Future<bool> deleteAddress(int id) async {
    try {
      await _repo.deleteAddress(id);
      _addresses = _addresses.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _saveError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Set Default ───────────────────────────────────────────────────────────────
  Future<bool> setDefault(int id) async {
    try {
      await _repo.setDefaultAddress(id);
      _markOnlyOneDefault(id);
      notifyListeners();
      return true;
    } catch (e) {
      _saveError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _markOnlyOneDefault(int id) {
    _addresses = _addresses
        .map((a) => a.copyWith(isDefault: a.id == id))
        .toList();
  }

  // ── Route Estimate ────────────────────────────────────────────────────────────
  RouteEstimateResult? _routeEstimate;
  bool _isEstimating = false;

  RouteEstimateResult? get routeEstimate => _routeEstimate;
  bool get isEstimating => _isEstimating;

  Future<void> estimateRoute({
    required AddressLocation origin,
    required AddressLocation destination,
  }) async {
    _isEstimating = true;
    _routeEstimate = null;
    notifyListeners();

    try {
      _routeEstimate = await _repo.estimateRoute(
        origin: origin,
        destination: destination,
      );
    } catch (_) {
      // لا نوقف التجربة بسبب خطأ في التقدير
    } finally {
      _isEstimating = false;
      notifyListeners();
    }
  }

  void clearRouteEstimate() {
    _routeEstimate = null;
    notifyListeners();
  }

  void clearSaveError() {
    _saveError = null;
    notifyListeners();
  }

  void clearUserScopedData() {
    _addresses = [];
    _isLoadingAddresses = false;
    _addressesError = null;
    _isSaving = false;
    _saveError = null;
    _routeEstimate = null;
    _isEstimating = false;
    notifyListeners();
  }
}
