import 'dart:typed_data';

/// EXIF数据模型类
/// 用于存储和管理从图片中读取的EXIF信息
class ExifData {
  /// 原始EXIF数据
  final Map<String, dynamic> rawData;

  /// 翻译后的EXIF数据（中文标题）
  final Map<String, String> translatedData;

  /// 图片路径
  final String imagePath;

  /// 是否成功读取EXIF
  final bool hasExif;

  /// 错误信息（如果有）
  final String? errorMessage;

  /// 缩略图数据
  final Uint8List? thumbnailBytes;

  ExifData({
    required this.rawData,
    required this.translatedData,
    required this.imagePath,
    this.thumbnailBytes,
    this.hasExif = true,
    this.errorMessage,
  });

  /// 获取所有可展示的EXIF信息
  Map<String, String> get displayData => translatedData;

  /// 检查是否有GPS信息
  bool get hasGpsInfo {
    return translatedData.containsKey('纬度') && translatedData.containsKey('经度');
  }

  /// 获取GPS坐标
  Map<String, double>? get gpsCoordinates {
    if (!hasGpsInfo) return null;

    try {
      final latitude = _parseCoordinate(translatedData['纬度']);
      final longitude = _parseCoordinate(translatedData['经度']);
      if (latitude == null || longitude == null) {
        return null;
      }
      return {'latitude': latitude, 'longitude': longitude};
    } catch (e) {
      return null;
    }
  }

  double? _parseCoordinate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final normalized = value.replaceAll('°', '').trim();
    return double.tryParse(normalized);
  }

  /// 创建空EXIF数据
  factory ExifData.empty(String imagePath) {
    return ExifData(
      rawData: {},
      translatedData: {},
      imagePath: imagePath,
      hasExif: false,
      errorMessage: '未找到EXIF信息',
      thumbnailBytes: null,
    );
  }

  /// 创建错误EXIF数据
  factory ExifData.error(String imagePath, String error) {
    return ExifData(
      rawData: {},
      translatedData: {},
      imagePath: imagePath,
      hasExif: false,
      errorMessage: error,
      thumbnailBytes: null,
    );
  }
}
