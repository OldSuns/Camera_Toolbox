import 'dart:io';
import 'dart:ui' as ui;
import 'package:exif_reader/exif_reader.dart';
import 'package:path/path.dart' as path;
import 'watermark_config.dart';

/// 图像容器，管理原始图像、EXIF信息和水印图像
class ImageContainer {
  final File sourceFile;
  final ui.Image originalImage;
  final Map<String, IfdTag> exifData;

  // 图像信息
  final int originalWidth;
  final int originalHeight;

  // EXIF提取的信息
  final String model;
  final String make;
  final String lensModel;
  final String lensMake;
  final DateTime? dateTime;
  final String focalLength;
  final String focalLengthIn35mm;
  final String fNumber;
  final String exposureTime;
  final String iso;
  final String? gpsInfo;

  // 水印图像
  ui.Image? _watermarkImage;

  // 是否使用等效焦距
  bool useEquivalentFocalLength = false;
  Map<WatermarkElementType, String> customTexts = {};

  ImageContainer({
    required this.sourceFile,
    required this.originalImage,
    required this.exifData,
  }) : originalWidth = originalImage.width,
       originalHeight = originalImage.height,
       model = _extractExifValue(exifData, 'Model', 'Unknown'),
       make = _extractExifValue(exifData, 'Make', 'Unknown'),
       lensModel = _extractLensModel(exifData),
       lensMake = _extractExifValue(exifData, 'LensMake', ''),
       dateTime = _extractDateTime(exifData),
       focalLength = _extractFocalLength(exifData),
       focalLengthIn35mm = _extractFocalLengthIn35mm(exifData),
       fNumber = _extractFNumber(exifData),
       exposureTime = _extractExposureTime(exifData),
       iso = _extractISO(exifData),
       gpsInfo = _extractGPSInfo(exifData);

  /// 从图像数据创建容器（用于Isolate中的处理）
  ImageContainer.fromImageData({
    required this.originalImage,
    required this.exifData,
    required int width,
    required int height,
  }) : sourceFile = File(''), // 临时文件，在Isolate中不需要实际文件
       originalWidth = width,
       originalHeight = height,
       model = _extractExifValue(exifData, 'Model', 'Unknown'),
       make = _extractExifValue(exifData, 'Make', 'Unknown'),
       lensModel = _extractLensModel(exifData),
       lensMake = _extractExifValue(exifData, 'LensMake', ''),
       dateTime = _extractDateTime(exifData),
       focalLength = _extractFocalLength(exifData),
       focalLengthIn35mm = _extractFocalLengthIn35mm(exifData),
       fNumber = _extractFNumber(exifData),
       exposureTime = _extractExposureTime(exifData),
       iso = _extractISO(exifData),
       gpsInfo = _extractGPSInfo(exifData);

  /// 获取水印图像
  ui.Image get watermarkImage => _watermarkImage ?? originalImage;

  /// 更新水印图像
  void updateWatermarkImage(ui.Image image) {
    _watermarkImage?.dispose();
    _watermarkImage = image;
  }

  /// 获取宽高比
  double get aspectRatio => originalWidth / originalHeight;

  /// 获取当前宽度
  int get width => watermarkImage.width;

  /// 获取当前高度
  int get height => watermarkImage.height;

  /// 获取文件名（不含扩展名）
  String get filename => path.basenameWithoutExtension(sourceFile.path);

  /// 获取总像素数（MP）
  String get totalPixels {
    final mp = (originalWidth * originalHeight) / 1000000.0;
    return '${mp.toStringAsFixed(2)} MP';
  }

  /// 获取拍摄参数字符串
  String getParamString({bool useEquivalent = false}) {
    final focal = useEquivalent && focalLengthIn35mm.isNotEmpty
        ? focalLengthIn35mm
        : focalLength;

    final parts = <String>[];
    if (focal.isNotEmpty) parts.add('${focal}mm');
    if (fNumber.isNotEmpty) parts.add('f/$fNumber');
    if (exposureTime.isNotEmpty) parts.add(exposureTime);
    if (iso.isNotEmpty) parts.add('ISO$iso');

    // 如果没有参数，返回一个提示信息
    if (parts.isEmpty) {
      return '无拍摄参数';
    }

    return parts.join('  ');
  }

  /// 获取属性字符串
  String getAttributeString(WatermarkElementType type, {String? customValue}) {
    if (customTexts.containsKey(type)) {
      return customTexts[type]!;
    }

    switch (type) {
      case WatermarkElementType.model:
        return model;
      case WatermarkElementType.make:
        return make;
      case WatermarkElementType.lensModel:
        return lensModel;
      case WatermarkElementType.param:
        return getParamString(useEquivalent: useEquivalentFocalLength);
      case WatermarkElementType.datetime:
        return dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')} ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}'
            : '';
      case WatermarkElementType.date:
        return dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')}'
            : '';
      case WatermarkElementType.custom:
        return customValue ?? '';
      case WatermarkElementType.none:
        return '';
      case WatermarkElementType.lensMakeLensModel:
        return '$lensMake $lensModel'.trim();
      case WatermarkElementType.cameraModelLensModel:
        return '$model $lensModel'.trim();
      case WatermarkElementType.totalPixel:
        return totalPixels;
      case WatermarkElementType.cameraMakeCameraModel:
        return '$make $model'.trim();
      case WatermarkElementType.filename:
        return filename;
      case WatermarkElementType.dateFilename:
        final date = dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')}'
            : '';
        return '$date $filename'.trim();
      case WatermarkElementType.datetimeFilename:
        final datetime = dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')} ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}'
            : '';
        return '$datetime $filename'.trim();
      case WatermarkElementType.geoInfo:
        return gpsInfo ?? '无';
    }
  }

  /// 获取原始属性字符串（不考虑customTexts）
  String getOriginalAttributeString(
    WatermarkElementType type, {
    String? customValue,
  }) {
    switch (type) {
      case WatermarkElementType.model:
        return model;
      case WatermarkElementType.make:
        return make;
      case WatermarkElementType.lensModel:
        return lensModel;
      case WatermarkElementType.param:
        return getParamString(useEquivalent: useEquivalentFocalLength);
      case WatermarkElementType.datetime:
        return dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')} ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}'
            : '';
      case WatermarkElementType.date:
        return dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')}'
            : '';
      case WatermarkElementType.custom:
        return customValue ?? '';
      case WatermarkElementType.none:
        return '';
      case WatermarkElementType.lensMakeLensModel:
        return '$lensMake $lensModel'.trim();
      case WatermarkElementType.cameraModelLensModel:
        return '$model $lensModel'.trim();
      case WatermarkElementType.totalPixel:
        return totalPixels;
      case WatermarkElementType.cameraMakeCameraModel:
        return '$make $model'.trim();
      case WatermarkElementType.filename:
        return filename;
      case WatermarkElementType.dateFilename:
        final date = dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')}'
            : '';
        return '$date $filename'.trim();
      case WatermarkElementType.datetimeFilename:
        final datetime = dateTime != null
            ? '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')} ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}'
            : '';
        return '$datetime $filename'.trim();
      case WatermarkElementType.geoInfo:
        return gpsInfo ?? '无';
    }
  }

  /// 释放资源
  void dispose() {
    _watermarkImage?.dispose();
  }

  // 静态辅助方法
  static String _extractExifValue(
    Map<String, IfdTag> exifData,
    String key,
    String defaultValue,
  ) {
    final tag = exifData['Image $key'] ?? exifData['EXIF $key'];
    if (tag != null) {
      return tag.printable.replaceAll('"', '').trim();
    }
    return defaultValue;
  }

  static String _extractLensModel(Map<String, IfdTag> exifData) {
    // 尝试多个可能的镜头型号字段
    final lensModelKeys = ['LensModel', 'Lens', 'LensID', 'LensType'];
    for (final key in lensModelKeys) {
      final value = _extractExifValue(exifData, key, '');
      if (value.isNotEmpty) return value;
    }
    return 'Unknown Lens';
  }

  static DateTime? _extractDateTime(Map<String, IfdTag> exifData) {
    final dateTimeStr = _extractExifValue(exifData, 'DateTimeOriginal', '');
    if (dateTimeStr.isEmpty) {
      final dateTimeStr2 = _extractExifValue(exifData, 'DateTime', '');
      if (dateTimeStr2.isEmpty) return null;
      return _parseDateTime(dateTimeStr2);
    }
    return _parseDateTime(dateTimeStr);
  }

  static DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // EXIF日期格式通常是 "YYYY:MM:DD HH:MM:SS"
      final parts = dateTimeStr.split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');

      if (dateParts.length != 3 || timeParts.length != 3) return null;

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (e) {
      return null;
    }
  }

  static String _extractFocalLength(Map<String, IfdTag> exifData) {
    // 尝试多个可能的焦距字段
    final focalLengthKeys = ['FocalLength', 'FocalLengthIn35mmFilm'];
    for (final key in focalLengthKeys) {
      final tag = exifData['EXIF $key'];
      if (tag != null) {
        // 尝试从values中提取焦距值
        if (tag.values is List && (tag.values as List).isNotEmpty) {
          final values = tag.values as List;
          final value = values.first;
          if (value is Ratio) {
            final focalValue = value.numerator / value.denominator;
            // 对于整数焦距，不显示小数点
            if (focalValue == focalValue.toInt()) {
              return focalValue.toInt().toString();
            }
            // 对于非整数焦距，保留一位小数
            return focalValue
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'\.0$'), '');
          } else if (value is int || value is double) {
            final focalValue = value is int
                ? value.toDouble()
                : value as double;
            // 对于整数焦距，不显示小数点
            if (focalValue == focalValue.toInt()) {
              return focalValue.toInt().toString();
            }
            // 对于非整数焦距，保留一位小数
            return focalValue
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'\.0$'), '');
          }
        }
        // 如果values不可用，使用printable
        final printable = tag.printable.trim();
        // 尝试解析数字
        final match = RegExp(r'(\d+\.?\d*)').firstMatch(printable);
        if (match != null) {
          final focalValue = double.parse(match.group(1)!);
          // 对于整数焦距，不显示小数点
          if (focalValue == focalValue.toInt()) {
            return focalValue.toInt().toString();
          }
          // 对于非整数焦距，保留一位小数
          return focalValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        }
        if (printable.isNotEmpty) {
          // 移除单位
          return printable.replaceAll(RegExp(r'[^\d.]+'), '');
        }
      }
    }
    return '';
  }

  static String _extractFocalLengthIn35mm(Map<String, IfdTag> exifData) {
    // 尝试多个可能的等效焦距字段
    final focalLengthKeys = ['FocalLengthIn35mmFilm', 'FocalLength'];
    for (final key in focalLengthKeys) {
      final tag = exifData['EXIF $key'];
      if (tag != null) {
        // 尝试从values中提取焦距值
        if (tag.values is List && (tag.values as List).isNotEmpty) {
          final values = tag.values as List;
          final value = values.first;
          if (value is Ratio) {
            final focalValue = value.numerator / value.denominator;
            // 对于整数焦距，不显示小数点
            if (focalValue == focalValue.toInt()) {
              return focalValue.toInt().toString();
            }
            // 对于非整数焦距，保留一位小数
            return focalValue
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'\.0$'), '');
          } else if (value is int || value is double) {
            final focalValue = value is int
                ? value.toDouble()
                : value as double;
            // 对于整数焦距，不显示小数点
            if (focalValue == focalValue.toInt()) {
              return focalValue.toInt().toString();
            }
            // 对于非整数焦距，保留一位小数
            return focalValue
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'\.0$'), '');
          }
        }
        // 如果values不可用，使用printable
        final printable = tag.printable.trim();
        // 尝试解析数字
        final match = RegExp(r'(\d+\.?\d*)').firstMatch(printable);
        if (match != null) {
          final focalValue = double.parse(match.group(1)!);
          // 对于整数焦距，不显示小数点
          if (focalValue == focalValue.toInt()) {
            return focalValue.toInt().toString();
          }
          // 对于非整数焦距，保留一位小数
          return focalValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        }
        if (printable.isNotEmpty) {
          // 移除单位
          return printable.replaceAll(RegExp(r'[^\d.]+'), '');
        }
      }
    }
    return '';
  }

  static String _extractFNumber(Map<String, IfdTag> exifData) {
    // 尝试多个可能的光圈值字段
    final fNumberKeys = ['FNumber', 'ApertureValue', 'MaxApertureValue'];
    for (final key in fNumberKeys) {
      final tag = exifData['EXIF $key'];
      if (tag != null) {
        // 尝试从values中提取光圈值
        if (tag.values is List && (tag.values as List).isNotEmpty) {
          final values = tag.values as List;
          final value = values.first;
          if (value is Ratio) {
            final fValue = value.numerator / value.denominator;
            // 验证光圈值合理性并保留一位小数
            if (_isValidApertureValue(fValue)) {
              return fValue.toStringAsFixed(1);
            }
          } else if (value is int || value is double) {
            final fValue = value is int ? value.toDouble() : value as double;
            // 验证光圈值合理性并保留一位小数
            if (_isValidApertureValue(fValue)) {
              return fValue.toStringAsFixed(1);
            }
          }
        }
        // 如果values不可用，使用printable
        final printable = tag.printable.trim();

        // 首先尝试解析分数格式（如 "71/10" 表示 7.1）
        if (printable.contains('/')) {
          final parts = printable.split('/');
          if (parts.length == 2) {
            final numerator = double.tryParse(parts[0]);
            final denominator = double.tryParse(parts[1]);
            if (numerator != null && denominator != null && denominator != 0) {
              final fValue = numerator / denominator;
              if (_isValidApertureValue(fValue)) {
                return fValue.toStringAsFixed(1);
              }
            }
          }
        }

        // 尝试解析小数格式
        final match = RegExp(r'(\d+\.?\d*)').firstMatch(printable);
        if (match != null) {
          final fValue = double.tryParse(match.group(1)!);
          if (fValue != null && _isValidApertureValue(fValue)) {
            return fValue.toStringAsFixed(1);
          }
        }

        // 如果以上都失败，返回原始字符串（移除多余字符）
        if (printable.isNotEmpty) {
          // 尝试提取合理的数字部分
          final cleanValue = printable.replaceAll(RegExp(r'[^\d./]'), '');
          if (cleanValue.isNotEmpty) {
            return cleanValue;
          }
        }
      }
    }
    return '';
  }

  /// 验证光圈值是否合理
  /// 通常光圈值范围在 f/0.5 到 f/32 之间
  static bool _isValidApertureValue(double value) {
    return value >= 0.5 && value <= 32.0;
  }

  static String _extractExposureTime(Map<String, IfdTag> exifData) {
    // 尝试多个可能的快门速度字段
    final exposureTimeKeys = ['ExposureTime', 'ShutterSpeedValue'];
    for (final key in exposureTimeKeys) {
      final tag = exifData['EXIF $key'];
      if (tag != null) {
        // 尝试从values中提取快门速度
        if (tag.values is List && (tag.values as List).isNotEmpty) {
          final values = tag.values as List;
          final value = values.first;
          if (value is Ratio) {
            final exposureValue = value.numerator / value.denominator;
            // 对于分数形式的快门速度
            if (exposureValue >= 1) {
              // 大于1秒的曝光时间
              return '${exposureValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}"';
            } else {
              // 计算分数形式
              final denominator = (1 / exposureValue).round();
              return '1/$denominator';
            }
          } else if (value is int || value is double) {
            final exposureValue = value is int
                ? value.toDouble()
                : value as double;
            if (exposureValue >= 1) {
              // 大于1秒的曝光时间
              return '${exposureValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}"';
            } else {
              // 计算分数形式
              final denominator = (1 / exposureValue).round();
              return '1/$denominator';
            }
          }
        }
        // 如果values不可用，使用printable
        final printable = tag.printable.trim();
        // 尝试解析分数形式
        final fractionMatch = RegExp(r'(\d+)/(\d+)').firstMatch(printable);
        if (fractionMatch != null) {
          final numerator = int.parse(fractionMatch.group(1)!);
          final denominator = int.parse(fractionMatch.group(2)!);
          if (numerator == 1 && denominator > 1) {
            return '1/$denominator';
          } else {
            final value = numerator / denominator;
            if (value >= 1) {
              // 大于1秒的曝光时间
              return '${value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}"';
            } else {
              // 计算分数形式
              final denominator = (1 / value).round();
              return '1/$denominator';
            }
          }
        }
        // 尝试解析小数形式
        final decimalMatch = RegExp(r'(\d+\.?\d*)').firstMatch(printable);
        if (decimalMatch != null) {
          final exposureValue = double.parse(decimalMatch.group(1)!);
          if (exposureValue >= 1) {
            // 大于1秒的曝光时间
            return '${exposureValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}"';
          } else {
            // 计算分数形式
            final denominator = (1 / exposureValue).round();
            return '1/$denominator';
          }
        }
        if (printable.isNotEmpty) {
          return printable;
        }
      }
    }
    return '';
  }

  static String _extractISO(Map<String, IfdTag> exifData) {
    // 尝试多个可能的ISO字段
    final isoKeys = [
      'ISOSpeedRatings',
      'ISO',
      'PhotographicSensitivity',
      'RecommendedExposureIndex',
    ];
    for (final key in isoKeys) {
      final tag = exifData['EXIF $key'];
      if (tag != null) {
        // 尝试从values中提取ISO值
        if (tag.values is List && (tag.values as List).isNotEmpty) {
          final values = tag.values as List;
          final value = values.first;
          if (value is int) {
            return value.toString();
          } else if (value is double) {
            return value.round().toString();
          }
        }
        // 如果values不可用，使用printable
        final printable = tag.printable.trim();
        // 提取数字部分
        final match = RegExp(r'\d+').firstMatch(printable);
        if (match != null) {
          return match.group(0)!;
        }
        if (printable.isNotEmpty) {
          return printable;
        }
      }
    }
    return '';
  }

  static String? _extractGPSInfo(Map<String, IfdTag> exifData) {
    final latTag = exifData['GPS GPSLatitude'];
    final latRefTag = exifData['GPS GPSLatitudeRef'];
    final lonTag = exifData['GPS GPSLongitude'];
    final lonRefTag = exifData['GPS GPSLongitudeRef'];

    if (latTag != null &&
        latRefTag != null &&
        lonTag != null &&
        lonRefTag != null) {
      if (latTag.values is! List || lonTag.values is! List) {
        return null;
      }

      final latValues = latTag.values as List;
      final lonValues = lonTag.values as List;

      if (latValues.length != 3 || lonValues.length != 3) {
        return null;
      }

      // 检查是否都是Ratio类型
      bool allRatios = true;
      for (final v in latValues) {
        if (v is! Ratio) {
          allRatios = false;
          break;
        }
      }
      if (!allRatios) return null;

      for (final v in lonValues) {
        if (v is! Ratio) {
          allRatios = false;
          break;
        }
      }
      if (!allRatios) return null;

      final lat = _convertGPSToDecimal(
        latValues.cast<Ratio>(),
        latRefTag.printable,
      );
      final lon = _convertGPSToDecimal(
        lonValues.cast<Ratio>(),
        lonRefTag.printable,
      );

      if (lat != null && lon != null) {
        final latStr = '${lat.abs().toStringAsFixed(6)}°${latRefTag.printable}';
        final lonStr = '${lon.abs().toStringAsFixed(6)}°${lonRefTag.printable}';
        return '$latStr $lonStr';
      }
    }
    return null;
  }

  static double? _convertGPSToDecimal(List<Ratio> values, String ref) {
    if (values.length != 3) return null;

    final degrees = values[0].numerator / values[0].denominator;
    final minutes = values[1].numerator / values[1].denominator;
    final seconds = values[2].numerator / values[2].denominator;

    var decimal = degrees + (minutes / 60) + (seconds / 3600);

    if (ref == 'S' || ref == 'W') {
      decimal = -decimal;
    }

    return decimal;
  }

  /// 从文件创建图像容器
  static Future<ImageContainer> fromFile(File file) async {
    // 读取文件字节
    final bytes = await file.readAsBytes();

    // 读取EXIF信息
    final exifData = await readExifFromBytes(bytes);

    // 解码图像
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    return ImageContainer(
      sourceFile: file,
      originalImage: image,
      exifData: exifData,
    );
  }
}
