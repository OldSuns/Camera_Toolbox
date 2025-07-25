import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models/camera_data.dart';

List<dynamic> _parseJson(String jsonString) {
  return jsonDecode(jsonString) as List<dynamic>;
}

class CameraDataService {
  List<CameraData> _cameraDataCache = [];
  static const String _dataPath = 'lib/data/camera_data/camera_data.json';

  Future<void> loadCameraData() async {
    if (_cameraDataCache.isNotEmpty) {
      return;
    }
    try {
      final jsonString = await rootBundle.loadString(_dataPath);
      final List<dynamic> jsonList = await compute(_parseJson, jsonString);
      _cameraDataCache = jsonList
          .map((json) => CameraData.fromMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading camera data: $e');
      rethrow;
    }
  }

  List<String> getBrands() {
    if (_cameraDataCache.isEmpty) {
      return [];
    }
    final brands = _cameraDataCache.map((e) => e.brand).toSet().toList();
    brands.sort();
    return brands;
  }

  List<String> getModelsForBrand(String brand) {
    if (_cameraDataCache.isEmpty) {
      return [];
    }
    final models = _cameraDataCache
        .where((e) => e.brand == brand)
        .map((e) => e.model)
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  CameraData? getCameraData(String brand, String model) {
    if (_cameraDataCache.isEmpty) {
      return null;
    }
    try {
      return _cameraDataCache.firstWhere(
        (e) => e.brand == brand && e.model == model,
      );
    } catch (e) {
      return null;
    }
  }
}
