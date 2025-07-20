import 'dart:io';
import 'dart:typed_data';
import 'package:exif/exif.dart' as exif;
import '../models/exif_data.dart';
import '../utils/exif_translator.dart';

/// EXIF信息读取服务
/// 负责从图片文件中读取EXIF信息
class ExifService {
  /// 从文件路径读取EXIF信息
  static Future<ExifData> readExifFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ExifData.error(filePath, '文件不存在');
      }

      final bytes = await file.readAsBytes();
      return await _readExifFromBytes(bytes, filePath);
    } catch (e) {
      return ExifData.error(filePath, '读取文件失败: ${e.toString()}');
    }
  }

  /// 从字节数据读取EXIF信息
  static Future<ExifData> _readExifFromBytes(
    Uint8List bytes,
    String filePath,
  ) async {
    try {
      final data = await exif.readExifFromBytes(bytes);

      if (data.isEmpty) {
        return ExifData.empty(filePath);
      }

      // 过滤掉不需要的标签
      final filteredData = _filterExifData(data);

      // 翻译标签并格式化值
      final translatedData = _translateAndFormatExifData(filteredData);

      return ExifData(
        rawData: Map<String, dynamic>.from(data),
        translatedData: translatedData,
        imagePath: filePath,
        hasExif: true,
      );
    } catch (e) {
      return ExifData.error(filePath, '解析EXIF信息失败: ${e.toString()}');
    }
  }

  /// 过滤EXIF数据，移除不需要的标签
  static Map<String, dynamic> _filterExifData(Map<String, exif.IfdTag> data) {
    final filtered = <String, dynamic>{};

    // 定义需要保留的标签
    final importantTags = {
      // 图片基本信息
      'Image ImageWidth',
      'Image ImageLength',
      'Image Make',
      'Image Model',
      'Image Software',
      'Image DateTime',
      'Image Orientation',

      // EXIF信息
      'EXIF ExposureTime',
      'EXIF FNumber',
      'EXIF ISO',
      'EXIF ISOSpeedRatings',
      'EXIF DateTimeOriginal',
      'EXIF DateTimeDigitized',
      'EXIF FocalLength',
      'EXIF Flash',
      'EXIF WhiteBalance',
      'EXIF MeteringMode',
      'EXIF ExposureProgram',
      'EXIF ExposureMode',
      'EXIF FocalLengthIn35mmFilm',

      // GPS信息
      'GPS GPSLatitude',
      'GPS GPSLongitude',
      'GPS GPSAltitude',
      'GPS GPSDateStamp',
      'GPS GPSTimeStamp',
    };

    for (final entry in data.entries) {
      if (importantTags.contains(entry.key)) {
        filtered[entry.key] = entry.value.printable;
      }
    }

    return filtered;
  }

  /// 翻译并格式化EXIF数据
  static Map<String, String> _translateAndFormatExifData(
    Map<String, dynamic> data,
  ) {
    final translated = <String, String>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      // 翻译标签名称
      final translatedKey = ExifTranslator.translate(key);

      // 特殊处理某些值
      String formattedValue = ExifTranslator.formatValue(value);

      // 特殊处理GPS坐标
      if (key == 'GPS GPSLatitude' || key == 'GPS GPSLongitude') {
        final gpsKey = key == 'GPS GPSLatitude'
            ? 'GPS GPSLatitude'
            : 'GPS GPSLongitude';
        final refKey = key == 'GPS GPSLatitude'
            ? 'GPS GPSLatitudeRef'
            : 'GPS GPSLongitudeRef';

        final coordinates = data[gpsKey];
        final ref = data[refKey];

        if (coordinates != null && ref != null) {
          final formatted = ExifTranslator.formatGpsCoordinate(
            coordinates,
            ref,
          );
          if (formatted != null) {
            formattedValue = formatted;
          }
        }
      }

      // 特殊处理日期时间
      if (key.contains('DateTime')) {
        final formatted = ExifTranslator.formatDateTime(value);
        if (formatted != null) {
          formattedValue = formatted;
        }
      }

      // 特殊处理曝光时间
      if (key == 'EXIF ExposureTime') {
        formattedValue = _formatExposureTime(value);
      }

      // 特殊处理光圈值
      if (key == 'EXIF FNumber') {
        formattedValue = _formatFNumber(value);
      }

      // 特殊处理焦距
      if (key == 'EXIF FocalLength') {
        formattedValue = _formatFocalLength(value);
      }

      // 特殊处理ISO
      if (key == 'EXIF ISOSpeedRatings' || key == 'EXIF ISO') {
        formattedValue = 'ISO $value';
      }

      translated[translatedKey] = formattedValue;
    }

    return translated;
  }

  /// 格式化曝光时间
  static String _formatExposureTime(dynamic value) {
    if (value == null) return '未知';

    try {
      final strValue = value.toString();

      // 处理分数格式
      if (strValue.contains('/')) {
        final parts = strValue.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]) ?? 0;
          final denominator = double.tryParse(parts[1]) ?? 1;
          final result = numerator / denominator;

          if (result < 1) {
            return '1/${(1 / result).round()}秒';
          } else {
            return '${result.toStringAsFixed(2)}秒';
          }
        }
      }

      // 处理小数格式
      final exposureTime = double.tryParse(strValue) ?? 0;
      if (exposureTime < 1) {
        return '1/${(1 / exposureTime).round()}秒';
      } else {
        return '${exposureTime.toStringAsFixed(2)}秒';
      }
    } catch (e) {
      return value.toString();
    }
  }

  /// 格式化光圈值
  static String _formatFNumber(dynamic value) {
    if (value == null) return '未知';

    try {
      final strValue = value.toString();

      // 处理分数格式
      if (strValue.contains('/')) {
        final parts = strValue.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]) ?? 0;
          final denominator = double.tryParse(parts[1]) ?? 1;
          final result = numerator / denominator;
          return 'f/${result.toStringAsFixed(1)}';
        }
      }

      // 处理小数格式
      final fNumber = double.tryParse(strValue) ?? 0;
      return 'f/${fNumber.toStringAsFixed(1)}';
    } catch (e) {
      return value.toString();
    }
  }

  /// 格式化焦距
  static String _formatFocalLength(dynamic value) {
    if (value == null) return '未知';

    try {
      final strValue = value.toString();

      // 处理分数格式
      if (strValue.contains('/')) {
        final parts = strValue.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]) ?? 0;
          final denominator = double.tryParse(parts[1]) ?? 1;
          final result = numerator / denominator;
          return '${result.toStringAsFixed(1)}mm';
        }
      }

      // 处理小数格式
      final focalLength = double.tryParse(strValue) ?? 0;
      return '${focalLength.toStringAsFixed(1)}mm';
    } catch (e) {
      return value.toString();
    }
  }

  /// 检查文件是否为支持的图片格式
  static bool isSupportedImage(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'tiff', 'tif', 'webp'].contains(extension);
  }

  /// 获取图片基本信息
  static Future<Map<String, String>> getImageInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();

      return {
        '文件大小': _formatFileSize(stat.size),
        '文件类型': filePath.split('.').last.toUpperCase(),
        '修改时间': stat.modified.toString().substring(0, 19),
      };
    } catch (e) {
      return {};
    }
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
