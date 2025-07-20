/// EXIF标签中文映射工具
/// 将EXIF标签转换为中文显示名称
class ExifTranslator {
  /// EXIF标签到中文的映射表
  static const Map<String, String> _exifTranslations = {
    // 图片基本信息
    'Image ImageWidth': '图片宽度',
    'Image ImageLength': '图片高度',
    'Image BitsPerSample': '位深度',
    'Image Compression': '压缩方式',
    'Image PhotometricInterpretation': '颜色空间',
    'Image Make': '相机制造商',
    'Image Model': '相机型号',
    'Image Orientation': '方向',
    'Image SamplesPerPixel': '每像素样本数',
    'Image XResolution': 'X分辨率',
    'Image YResolution': 'Y分辨率',
    'Image ResolutionUnit': '分辨率单位',
    'Image Software': '软件',
    'Image DateTime': '修改时间',
    'Image Artist': '作者',
    'Image Copyright': '版权信息',
    'Image ExifOffset': 'EXIF偏移量',
    'Image GPSInfo': 'GPS信息',

    // EXIF信息
    'EXIF ExposureTime': '曝光时间',
    'EXIF FNumber': '光圈值',
    'EXIF ExposureProgram': '曝光程序',
    'EXIF ISOSpeedRatings': 'ISO感光度',
    'EXIF ExifVersion': 'EXIF版本',
    'EXIF DateTimeOriginal': '拍摄时间',
    'EXIF DateTimeDigitized': '数字化时间',
    'EXIF ComponentsConfiguration': '组件配置',
    'EXIF CompressedBitsPerPixel': '压缩位每像素',
    'EXIF ShutterSpeedValue': '快门速度',
    'EXIF ApertureValue': '光圈值',
    'EXIF BrightnessValue': '亮度值',
    'EXIF ExposureBiasValue': '曝光补偿',
    'EXIF MaxApertureValue': '最大光圈值',
    'EXIF SubjectDistance': '主体距离',
    'EXIF MeteringMode': '测光模式',
    'EXIF LightSource': '光源',
    'EXIF Flash': '闪光灯',
    'EXIF FocalLength': '焦距',
    'EXIF MakerNote': '制造商注释',
    'EXIF UserComment': '用户注释',
    'EXIF FlashPixVersion': 'FlashPix版本',
    'EXIF ColorSpace': '颜色空间',
    'EXIF PixelXDimension': '像素宽度',
    'EXIF PixelYDimension': '像素高度',
    'EXIF RelatedSoundFile': '相关音频文件',
    'EXIF FocalPlaneXResolution': '焦平面X分辨率',
    'EXIF FocalPlaneYResolution': '焦平面Y分辨率',
    'EXIF FocalPlaneResolutionUnit': '焦平面分辨率单位',
    'EXIF SensingMethod': '传感方式',
    'EXIF FileSource': '文件来源',
    'EXIF SceneType': '场景类型',
    'EXIF CFAPattern': 'CFA模式',
    'EXIF CustomRendered': '自定义渲染',
    'EXIF ExposureMode': '曝光模式',
    'EXIF WhiteBalance': '白平衡',
    'EXIF DigitalZoomRatio': '数字变焦比例',
    'EXIF FocalLengthIn35mmFilm': '35mm等效焦距',
    'EXIF SceneCaptureType': '场景拍摄类型',
    'EXIF GainControl': '增益控制',
    'EXIF Contrast': '对比度',
    'EXIF Saturation': '饱和度',
    'EXIF Sharpness': '锐度',
    'EXIF DeviceSettingDescription': '设备设置描述',
    'EXIF SubjectDistanceRange': '主体距离范围',
    'EXIF ImageUniqueID': '图片唯一ID',

    // GPS信息
    'GPS GPSVersionID': 'GPS版本',
    'GPS GPSLatitudeRef': '纬度参考',
    'GPS GPSLatitude': '纬度',
    'GPS GPSLongitudeRef': '经度参考',
    'GPS GPSLongitude': '经度',
    'GPS GPSAltitudeRef': '海拔参考',
    'GPS GPSAltitude': '海拔',
    'GPS GPSTimeStamp': 'GPS时间',
    'GPS GPSSatellites': '卫星',
    'GPS GPSStatus': 'GPS状态',
    'GPS GPSMeasureMode': '测量模式',
    'GPS GPSDOP': '精度因子',
    'GPSSpeedRef': '速度参考',
    'GPS GPSSpeed': '速度',
    'GPS GPSTrackRef': '方向参考',
    'GPS GPSTrack': '方向',
    'GPS GPSImgDirectionRef': '图片方向参考',
    'GPS GPSImgDirection': '图片方向',
    'GPS GPSMapDatum': '地图基准',
    'GPS GPSDestLatitudeRef': '目标纬度参考',
    'GPS GPSDestLatitude': '目标纬度',
    'GPS GPSDestLongitudeRef': '目标经度参考',
    'GPS GPSDestLongitude': '目标经度',
    'GPS GPSDestBearingRef': '目标方位参考',
    'GPS GPSDestBearing': '目标方位',
    'GPS GPSDestDistanceRef': '目标距离参考',
    'GPS GPSDestDistance': '目标距离',
    'GPS GPSProcessingMethod': '处理方法',
    'GPS GPSAreaInformation': '区域信息',
    'GPS GPSDateStamp': 'GPS日期',
    'GPS GPSDifferential': 'GPS差分',

    // 缩略图信息
    'Thumbnail Compression': '缩略图压缩',
    'Thumbnail XResolution': '缩略图X分辨率',
    'Thumbnail YResolution': '缩略图Y分辨率',
    'Thumbnail ResolutionUnit': '缩略图分辨率单位',
    'Thumbnail JPEGInterchangeFormat': '缩略图JPEG交换格式',
    'Thumbnail JPEGInterchangeFormatLength': '缩略图JPEG交换格式长度',
  };

  /// 获取EXIF标签的中文名称
  static String translate(String tag) {
    return _exifTranslations[tag] ?? tag;
  }

  /// 获取所有支持的EXIF标签
  static List<String> get supportedTags => _exifTranslations.keys.toList();

  /// 检查标签是否支持中文翻译
  static bool isSupported(String tag) {
    return _exifTranslations.containsKey(tag);
  }

  /// 格式化EXIF值
  static String formatValue(dynamic value) {
    if (value == null) return '未知';

    // 处理列表值
    if (value is List) {
      return value.join(', ');
    }

    // 处理字符串值
    if (value is String) {
      return value.trim();
    }

    // 处理数值
    if (value is num) {
      // 处理GPS坐标
      if (value is double && value.abs() < 180) {
        return value.toStringAsFixed(6);
      }
      return value.toString();
    }

    return value.toString();
  }

  /// 格式化GPS坐标
  static String? formatGpsCoordinate(List<dynamic>? coordinates, String? ref) {
    if (coordinates == null || coordinates.isEmpty || ref == null) return null;

    try {
      // 将GPS坐标转换为度分秒格式
      double degrees = 0;
      if (coordinates.isNotEmpty) {
        degrees = _parseRational(coordinates[0]);
      }

      double minutes = 0;
      if (coordinates.length >= 2) {
        minutes = _parseRational(coordinates[1]);
      }

      double seconds = 0;
      if (coordinates.length >= 3) {
        seconds = _parseRational(coordinates[2]);
      }

      double decimal = degrees + minutes / 60 + seconds / 3600;

      // 根据参考方向调整符号
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return '${decimal.toStringAsFixed(6)}°';
    } catch (e) {
      return null;
    }
  }

  /// 解析有理数格式
  static double _parseRational(dynamic value) {
    if (value is List && value.length == 2) {
      return value[0] / value[1];
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }

  /// 格式化日期时间
  static String? formatDateTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return null;

    try {
      // EXIF日期格式: "2023:12:25 14:30:25"
      final parts = dateTime.split(' ');
      if (parts.length != 2) return dateTime;

      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');

      if (dateParts.length != 3 || timeParts.length != 3) return dateTime;

      final year = dateParts[0];
      final month = dateParts[1].padLeft(2, '0');
      final day = dateParts[2].padLeft(2, '0');

      final hour = timeParts[0];
      final minute = timeParts[1].padLeft(2, '0');
      final second = timeParts[2].padLeft(2, '0');

      return '$year-$month-$day $hour:$minute:$second';
    } catch (e) {
      return dateTime;
    }
  }
}
