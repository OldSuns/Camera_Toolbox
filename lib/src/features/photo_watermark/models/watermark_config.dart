import 'package:flutter/material.dart';

/// 水印布局类型
enum WatermarkLayoutType {
  pureWhiteBorder('白色边框', '纯白边框', const {}),
  darkWatermarkLeftLogo('normal(黑红配色)', '黑红配色', const {}),
  backgroundBlurWithBorder('背景模糊+白框', '背景模糊白框', const {});

  /// 扩展设置，用于存储额外的可调节参数
  final Map<String, dynamic> extraSettings;

  final String id;
  final String displayName;

  const WatermarkLayoutType(this.id, this.displayName, this.extraSettings);
}

/// 水印元素类型
enum WatermarkElementType {
  model('Model', '相机型号'),
  make('Make', '相机厂商'),
  lensModel('LensModel', '镜头型号'),
  param('Param', '拍摄参数'),
  datetime('Datetime', '拍摄时间'),
  date('Date', '拍摄日期'),
  custom('Custom', '自定义'),
  none('None', '无'),
  lensMakeLensModel('LensMake_LensModel', '镜头厂商+型号'),
  cameraModelLensModel('CameraModel_LensModel', '相机型号+镜头'),
  totalPixel('TotalPixel', '总像素'),
  cameraMakeCameraModel('CameraMake_CameraModel', '相机厂商+型号'),
  filename('Filename', '文件名'),
  dateFilename('Date_Filename', '日期+文件名'),
  datetimeFilename('Datetime_Filename', '时间+文件名'),
  geoInfo('GeoInfo', '地理位置');

  final String id;
  final String displayName;

  const WatermarkElementType(this.id, this.displayName);
}

/// Logo位置
enum LogoPosition {
  leftTextLeft, // 左侧文字左侧
  leftTextRight, // 左侧文字右侧
  rightTextLeft, // 右侧文字左侧
  rightTextRight, // 右侧文字右侧
}

/// 元素配置
class ElementConfig {
  final WatermarkElementType type;
  final Color color;
  final bool isBold;
  final String? customValue;

  ElementConfig({
    required this.type,
    this.color = Colors.black,
    this.isBold = false,
    this.customValue,
  });

  ElementConfig copyWith({
    WatermarkElementType? type,
    Color? color,
    bool? isBold,
    String? customValue,
  }) {
    return ElementConfig(
      type: type ?? this.type,
      color: color ?? this.color,
      isBold: isBold ?? this.isBold,
      customValue: customValue ?? this.customValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.id,
      'color': color.toARGB32(),
      'isBold': isBold,
      'customValue': customValue,
    };
  }

  factory ElementConfig.fromJson(Map<String, dynamic> json) {
    return ElementConfig(
      type: WatermarkElementType.values.firstWhere(
        (e) => e.id == json['type'],
        orElse: () => WatermarkElementType.none,
      ),
      color: Color(json['color'] ?? Colors.black.toARGB32()),
      isBold: json['isBold'] ?? false,
      customValue: json['customValue'],
    );
  }
}

/// 水印配置
class WatermarkConfig {
  // 布局设置
  final WatermarkLayoutType layoutType;
  final bool logoEnabled;
  final LogoPosition logoPosition;
  final Color backgroundColor;

  // 四角元素配置
  final ElementConfig leftTop;
  final ElementConfig leftBottom;
  final ElementConfig rightTop;
  final ElementConfig rightBottom;

  // 全局设置
  final bool whiteMarginEnabled;
  final double whiteMarginWidth;
  final bool shadowEnabled;
  final bool useEquivalentFocalLength;
  final bool paddingWithOriginalRatio;

  // 输出设置
  final int outputQuality;
  final String outputDirectory;

  // 字体设置
  final double fontSize;
  final double boldFontSize;

  final Map<String, dynamic> extraSettings;

  WatermarkConfig({
    this.extraSettings = const {},
    this.layoutType = WatermarkLayoutType.pureWhiteBorder,
    this.logoEnabled = true,
    this.logoPosition = LogoPosition.rightTextRight,
    this.backgroundColor = Colors.white,
    ElementConfig? leftTop,
    ElementConfig? leftBottom,
    ElementConfig? rightTop,
    ElementConfig? rightBottom,
    this.whiteMarginEnabled = true,
    this.whiteMarginWidth = 1.0,
    this.shadowEnabled = false,
    this.useEquivalentFocalLength = false,
    this.paddingWithOriginalRatio = false,
    this.outputQuality = 100,
    this.outputDirectory = 'output',
    this.fontSize = 1.0,
    this.boldFontSize = 1.0,
  }) : leftTop =
           leftTop ??
           ElementConfig(
             type: WatermarkElementType.lensModel,
             color: const Color(0xFF212121),
             isBold: true,
           ),
       leftBottom =
           leftBottom ??
           ElementConfig(
             type: WatermarkElementType.model,
             color: const Color(0xFF757575),
             isBold: false,
           ),
       rightTop =
           rightTop ??
           ElementConfig(
             type: WatermarkElementType.param,
             color: const Color(0xFF212121),
             isBold: true,
           ),
       rightBottom =
           rightBottom ??
           ElementConfig(
             type: WatermarkElementType.datetime,
             color: const Color(0xFF757575),
             isBold: false,
           );

  /// 创建黑红配色预设
  factory WatermarkConfig.darkTheme({
    LogoPosition logoPosition = LogoPosition.rightTextRight,
  }) {
    return WatermarkConfig(
      layoutType: WatermarkLayoutType.darkWatermarkLeftLogo,
      logoPosition: logoPosition,
      backgroundColor: const Color(0xFF212121),
      leftTop: ElementConfig(
        type: WatermarkElementType.lensModel,
        color: const Color(0xFFD32F2F),
        isBold: true,
      ),
      leftBottom: ElementConfig(
        type: WatermarkElementType.model,
        color: const Color(0xFFD4D1CC),
        isBold: false,
      ),
      rightTop: ElementConfig(
        type: WatermarkElementType.param,
        color: const Color(0xFFD32F2F),
        isBold: true,
      ),
      rightBottom: ElementConfig(
        type: WatermarkElementType.datetime,
        color: const Color(0xFFD4D1CC),
        isBold: false,
      ),
    );
  }

  WatermarkConfig copyWith({
    WatermarkLayoutType? layoutType,
    bool? logoEnabled,
    LogoPosition? logoPosition,
    Color? backgroundColor,
    ElementConfig? leftTop,
    ElementConfig? leftBottom,
    ElementConfig? rightTop,
    ElementConfig? rightBottom,
    bool? whiteMarginEnabled,
    double? whiteMarginWidth,
    bool? shadowEnabled,
    bool? useEquivalentFocalLength,
    bool? paddingWithOriginalRatio,
    int? outputQuality,
    String? outputDirectory,
    double? fontSize,
    double? boldFontSize,
    Map<String, dynamic>? extraSettings,
  }) {
    return WatermarkConfig(
      layoutType: layoutType ?? this.layoutType,
      logoEnabled: logoEnabled ?? this.logoEnabled,
      logoPosition: logoPosition ?? this.logoPosition,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      leftTop: leftTop ?? this.leftTop,
      leftBottom: leftBottom ?? this.leftBottom,
      rightTop: rightTop ?? this.rightTop,
      rightBottom: rightBottom ?? this.rightBottom,
      whiteMarginEnabled: whiteMarginEnabled ?? this.whiteMarginEnabled,
      whiteMarginWidth: whiteMarginWidth ?? this.whiteMarginWidth,
      shadowEnabled: shadowEnabled ?? this.shadowEnabled,
      useEquivalentFocalLength:
          useEquivalentFocalLength ?? this.useEquivalentFocalLength,
      paddingWithOriginalRatio:
          paddingWithOriginalRatio ?? this.paddingWithOriginalRatio,
      outputQuality: outputQuality ?? this.outputQuality,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      fontSize: fontSize ?? this.fontSize,
      boldFontSize: boldFontSize ?? this.boldFontSize,
      extraSettings: extraSettings ?? this.extraSettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'layoutType': layoutType.id,
      'logoEnabled': logoEnabled,
      'logoPosition': logoPosition.name,
      'backgroundColor': backgroundColor.toARGB32(),
      'leftTop': leftTop.toJson(),
      'leftBottom': leftBottom.toJson(),
      'rightTop': rightTop.toJson(),
      'rightBottom': rightBottom.toJson(),
      'whiteMarginEnabled': whiteMarginEnabled,
      'whiteMarginWidth': whiteMarginWidth,
      'shadowEnabled': shadowEnabled,
      'useEquivalentFocalLength': useEquivalentFocalLength,
      'paddingWithOriginalRatio': paddingWithOriginalRatio,
      'outputQuality': outputQuality,
      'outputDirectory': outputDirectory,
      'fontSize': fontSize,
      'boldFontSize': boldFontSize,
    };
  }

  factory WatermarkConfig.fromJson(Map<String, dynamic> json) {
    return WatermarkConfig(
      layoutType: WatermarkLayoutType.values.firstWhere(
        (e) => e.id == json['layoutType'],
        orElse: () => WatermarkLayoutType.pureWhiteBorder,
      ),
      logoEnabled: json['logoEnabled'] ?? true,
      logoPosition: LogoPosition.values.firstWhere(
        (e) => e.name == json['logoPosition'],
        orElse: () => LogoPosition.rightTextRight,
      ),
      backgroundColor: Color(
        json['backgroundColor'] ?? Colors.white.toARGB32(),
      ),
      leftTop: ElementConfig.fromJson(json['leftTop'] as Map<String, dynamic>),
      leftBottom: ElementConfig.fromJson(
        json['leftBottom'] as Map<String, dynamic>,
      ),
      rightTop: ElementConfig.fromJson(
        json['rightTop'] as Map<String, dynamic>,
      ),
      rightBottom: ElementConfig.fromJson(
        json['rightBottom'] as Map<String, dynamic>,
      ),
      whiteMarginEnabled: json['whiteMarginEnabled'] ?? true,
      whiteMarginWidth: (json['whiteMarginWidth'] ?? 1.0).toDouble(),
      shadowEnabled: json['shadowEnabled'] ?? false,
      useEquivalentFocalLength: json['useEquivalentFocalLength'] ?? false,
      paddingWithOriginalRatio: json['paddingWithOriginalRatio'] ?? false,
      outputQuality: json['outputQuality'] ?? 100,
      outputDirectory: json['outputDirectory'] ?? 'output',
      fontSize: (json['fontSize'] ?? 1.0).toDouble(),
      boldFontSize: (json['boldFontSize'] ?? 1.0).toDouble(),
    );
  }
}
