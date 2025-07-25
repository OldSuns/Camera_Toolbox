import 'package:flutter/foundation.dart';
import 'camera_data_service.dart';
import 'models/camera_data.dart';

class CameraDatabaseViewModel extends ChangeNotifier {
  final CameraDataService _cameraDataService;

  CameraDatabaseViewModel(this._cameraDataService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<String> _brands = [];
  List<String> get brands => _brands;

  List<String> _models = [];
  List<String> get models => _models;

  String? _selectedBrand;
  String? get selectedBrand => _selectedBrand;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;

  CameraData? _cameraData;
  CameraData? get cameraData => _cameraData;

  // Comparison mode state
  bool _isCompareMode = false;
  bool get isCompareMode => _isCompareMode;

  String? _selectedBrand2;
  String? get selectedBrand2 => _selectedBrand2;

  List<String> _models2 = [];
  List<String> get models2 => _models2;

  String? _selectedModel2;
  String? get selectedModel2 => _selectedModel2;

  CameraData? _cameraData2;
  CameraData? get cameraData2 => _cameraData2;

  void toggleCompareMode() {
    _isCompareMode = !_isCompareMode;
    if (!_isCompareMode) {
      _selectedBrand2 = null;
      _selectedModel2 = null;
      _cameraData2 = null;
      _models2 = [];
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    _setLoading(true);
    _error = null;
    try {
      await _cameraDataService.loadCameraData();
      _brands = _cameraDataService.getBrands();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void selectBrand(String? brand, {bool isSecond = false}) {
    if (!isSecond) {
      if (_selectedBrand == brand) return;
      _selectedBrand = brand;
      _selectedModel = null;
      _cameraData = null;
      if (brand != null) {
        _models = _cameraDataService.getModelsForBrand(brand);
      } else {
        _models = [];
      }
    } else {
      if (_selectedBrand2 == brand) return;
      _selectedBrand2 = brand;
      _selectedModel2 = null;
      _cameraData2 = null;
      if (brand != null) {
        _models2 = _cameraDataService.getModelsForBrand(brand);
      } else {
        _models2 = [];
      }
    }
    notifyListeners();
  }

  void selectModel(String? model, {bool isSecond = false}) {
    if (!isSecond) {
      if (_selectedModel == model) return;
      _selectedModel = model;
      _cameraData = null;
    } else {
      if (_selectedModel2 == model) return;
      _selectedModel2 = model;
      _cameraData2 = null;
    }
    notifyListeners();
  }

  void search() {
    if (_selectedBrand != null && _selectedModel != null) {
      _cameraData = _cameraDataService.getCameraData(
        _selectedBrand!,
        _selectedModel!,
      );
    } else {
      _cameraData = null;
    }

    if (_isCompareMode) {
      if (_selectedBrand2 != null && _selectedModel2 != null) {
        _cameraData2 = _cameraDataService.getCameraData(
          _selectedBrand2!,
          _selectedModel2!,
        );
      } else {
        _cameraData2 = null;
      }
    }

    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
