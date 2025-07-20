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

  ExifData({
    required this.rawData,
    required this.translatedData,
    required this.imagePath,
    this.hasExif = true,
    this.errorMessage,
  });

  /// 获取所有可展示的EXIF信息
  Map<String, String> get displayData => translatedData;

  /// 检查是否有GPS信息
  bool get hasGpsInfo {
    return rawData.containsKey('GPS GPSLatitude') &&
        rawData.containsKey('GPS GPSLongitude');
  }

  /// 获取GPS坐标
  Map<String, double>? get gpsCoordinates {
    if (!hasGpsInfo) return null;

    try {
      // 这里需要解析GPS坐标格式
      return null; // 暂时返回null，后续实现
    } catch (e) {
      return null;
    }
  }

  /// 创建空EXIF数据
  factory ExifData.empty(String imagePath) {
    return ExifData(
      rawData: {},
      translatedData: {},
      imagePath: imagePath,
      hasExif: false,
      errorMessage: '未找到EXIF信息',
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
    );
  }
}
