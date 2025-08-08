import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/watermark_config.dart';
import '../models/image_container.dart';

/// 水印尺寸参数
class _WatermarkDimensions {
  final double watermarkHeight;
  final double padding;
  final double maxTextWidth;
  final int watermarkWidth;
  final double fontScaleFactor;

  _WatermarkDimensions({
    required this.watermarkHeight,
    required this.padding,
    required this.maxTextWidth,
    required this.watermarkWidth,
    required this.fontScaleFactor,
  });
}

/// 文本图像集合
class _TextImages {
  final ui.Image leftTop;
  final ui.Image leftBottom;
  final ui.Image rightTop;
  final ui.Image rightBottom;
  final ui.Image leftText;
  final ui.Image rightText;

  _TextImages({
    required this.leftTop,
    required this.leftBottom,
    required this.rightTop,
    required this.rightBottom,
    required this.leftText,
    required this.rightText,
  });
}

/// 内容位置信息
class _ContentPositions {
  final double leftContentY;
  final double rightContentY;
  final double logoY;
  final double padding;

  _ContentPositions({
    required this.leftContentY,
    required this.rightContentY,
    required this.logoY,
    required this.padding,
  });
}

/// 水印处理器基类
abstract class WatermarkProcessor {
  final WatermarkConfig config;

  WatermarkProcessor(this.config);

  /// 处理图像
  Future<ui.Image> process(ImageContainer container);

  /// 加载Logo图像
  Future<ui.Image?> loadLogo(String make) async {
    final logoMap = {
      'Canon': 'lib/data/logos/canon.png',
      'Nikon': 'lib/data/logos/nikon.png',
      'SONY': 'lib/data/logos/sony.png',
      'FUJIFILM': 'lib/data/logos/fujifilm.png',
      'Olympus': 'lib/data/logos/olympus_blue_gold.png',
      'Panasonic': 'lib/data/logos/panasonic.png',
      'PENTAX': 'lib/data/logos/pentax.png',
      'RICOH': 'lib/data/logos/ricoh.png',
      'HASSELBLAD': 'lib/data/logos/hasselblad.png',
      'Leica': 'lib/data/logos/leica_logo.png',
      'DJI': 'lib/data/logos/DJI.jpg',
      'APPLE': 'lib/data/logos/apple.png',
      'HUAWEI': 'lib/data/logos/xmage.png',
    };

    String logoPath = logoMap[make] ?? 'lib/data/logos/empty.png';

    try {
      final ByteData data = await rootBundle.load(logoPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      // Failed to load logo: $e
      return null;
    }
  }

  /// 创建文字图像 - 优化版本
  Future<ui.Image> createTextImage(
    String text,
    TextStyle style,
    double maxWidth,
  ) async {
    // 快速参数验证
    if (maxWidth <= 0 || !maxWidth.isFinite) {
      throw ArgumentError('最大宽度必须大于0且为有限值');
    }

    if (style.fontSize == null ||
        style.fontSize! <= 0 ||
        !style.fontSize!.isFinite) {
      throw ArgumentError('字体大小必须大于0且为有限值');
    }

    // 空文本快速返回
    if (text.isEmpty) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = Colors.transparent,
      );
      final picture = recorder.endRecording();
      return await picture.toImage(1, 1);
    }

    // 创建文本画笔，一次性配置所有属性
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    // 初始布局
    textPainter.layout(maxWidth: maxWidth);

    // 如果需要调整字体大小，直接计算并重新布局
    if (textPainter.width > maxWidth * 0.95) {
      final scale = (maxWidth * 0.95) / textPainter.width;
      final adjustedFontSize = style.fontSize! * scale;
      final adjustedStyle = style.copyWith(fontSize: adjustedFontSize);

      // 直接更新TextPainter的text属性，避免重新创建
      textPainter.text = TextSpan(text: text, style: adjustedStyle);
      textPainter.layout(maxWidth: maxWidth);
    }

    // 预计算最终尺寸
    final width = math.max(1, textPainter.width.ceil()).clamp(1, 4096);
    final height = math.max(1, textPainter.height.ceil()).clamp(1, 4096);

    // 一次性创建并绘制
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    textPainter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();

    return await picture.toImage(width, height);
  }

  /// 合并图像（垂直或水平）- 优化版本
  Future<ui.Image> mergeImages(
    List<ui.Image> images, {
    bool vertical = true,
    Alignment alignment = Alignment.center,
    Color backgroundColor = Colors.transparent,
    double spacing = 0,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('Images list cannot be empty');
    }

    // 检查spacing有效性
    if (!spacing.isFinite || spacing < 0) {
      throw ArgumentError('间距必须为非负有限值');
    }

    // 预计算所有图像信息和位置，避免重复计算
    final imageInfos = <({int width, int height, double x, double y})>[];
    int totalWidth = 0;
    int totalHeight = 0;
    double currentOffset = 0;

    // 第一遍：计算尺寸和基本位置
    if (vertical) {
      totalWidth = images.map((img) => img.width).reduce(math.max);
      totalHeight =
          images.fold(0, (sum, img) => sum + img.height) +
          (spacing * (images.length - 1)).toInt();
    } else {
      totalWidth =
          images.fold(0, (sum, img) => sum + img.width) +
          (spacing * (images.length - 1)).toInt();
      totalHeight = images.map((img) => img.height).reduce(math.max);
    }

    // 检查结果尺寸有效性
    if (totalWidth <= 0 || totalHeight <= 0) {
      throw ArgumentError('结果图像尺寸无效');
    }

    // 第二遍：计算精确位置
    for (final image in images) {
      double x = 0;
      double y = 0;

      if (vertical) {
        y = currentOffset;
        // 根据对齐方式计算x坐标
        switch (alignment) {
          case Alignment.center:
            x = (totalWidth - image.width) / 2;
            break;
          case Alignment.centerRight:
            x = totalWidth - image.width.toDouble();
            break;
          default:
            x = 0;
        }
        currentOffset += image.height + spacing;
      } else {
        x = currentOffset;
        // 根据对齐方式计算y坐标
        switch (alignment) {
          case Alignment.center:
            y = (totalHeight - image.height) / 2;
            break;
          case Alignment.bottomCenter:
            y = totalHeight - image.height.toDouble();
            break;
          default:
            y = 0;
        }
        currentOffset += image.width + spacing;
      }

      imageInfos.add((width: image.width, height: image.height, x: x, y: y));
    }

    // 创建画布并一次性绘制所有内容
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 填充背景
    if (backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight.toDouble()),
        Paint()..color = backgroundColor,
      );
    }

    // 批量绘制图像，减少Paint对象创建
    final paint = Paint();
    for (int i = 0; i < images.length; i++) {
      final info = imageInfos[i];
      canvas.drawImage(images[i], Offset(info.x, info.y), paint);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(totalWidth, totalHeight);
  }

  /// 添加边框
  Future<ui.Image> addBorder(
    ui.Image image,
    double borderWidth,
    Color borderColor,
  ) async {
    // 检查参数有效性
    if (borderWidth < 0) {
      throw ArgumentError('边框宽度不能为负数');
    }

    // 检查源图像有效性
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('源图像尺寸无效');
    }

    final width = image.width + (borderWidth * 2).toInt();
    final height = image.height + (borderWidth * 2).toInt();

    // 检查结果尺寸有效性
    if (width <= 0 || height <= 0) {
      throw ArgumentError('结果图像尺寸无效');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制边框背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = borderColor,
    );

    // 绘制原图
    canvas.drawImage(image, Offset(borderWidth, borderWidth), Paint());

    final picture = recorder.endRecording();
    // 检查尺寸有效性
    if (width <= 0 || height <= 0) {
      throw ArgumentError('边框图像尺寸无效');
    }
    return await picture.toImage(width, height);
  }

  /// 添加阴影
  Future<ui.Image> addShadow(
    ui.Image image, {
    double blurRadius = 10,
    Color shadowColor = Colors.black54,
    Offset offset = const Offset(5, 5),
  }) async {
    // 检查参数有效性
    if (blurRadius < 0) {
      throw ArgumentError('模糊半径不能为负数');
    }

    // 检查源图像有效性
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('源图像尺寸无效');
    }

    final width = image.width + (blurRadius * 4).toInt();
    final height = image.height + (blurRadius * 4).toInt();

    // 检查结果尺寸有效性
    if (width <= 0 || height <= 0) {
      throw ArgumentError('结果图像尺寸无效');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制阴影
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    canvas.drawRect(
      Rect.fromLTWH(
        blurRadius * 2 + offset.dx,
        blurRadius * 2 + offset.dy,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      shadowPaint,
    );

    // 绘制原图
    canvas.drawImage(image, Offset(blurRadius * 2, blurRadius * 2), Paint());

    final picture = recorder.endRecording();
    // 检查尺寸有效性
    if (width <= 0 || height <= 0) {
      throw ArgumentError('阴影图像尺寸无效');
    }
    return await picture.toImage(width, height);
  }

  /// 缩放图像
  Future<ui.Image> resizeImage(
    ui.Image image,
    int targetWidth,
    int targetHeight,
  ) async {
    // 检查参数有效性
    if (targetWidth <= 0 || targetHeight <= 0) {
      throw ArgumentError('目标宽度和高度必须大于0');
    }

    // 检查源图像有效性
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('源图像尺寸无效');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final dstRect = Rect.fromLTWH(
      0,
      0,
      targetWidth.toDouble(),
      targetHeight.toDouble(),
    );

    // 检查矩形有效性
    if (srcRect.isEmpty || dstRect.isEmpty) {
      throw ArgumentError('源矩形或目标矩形无效');
    }

    // 确保矩形的坐标和尺寸都是有限的数值
    if (!srcRect.left.isFinite ||
        !srcRect.top.isFinite ||
        !srcRect.right.isFinite ||
        !srcRect.bottom.isFinite ||
        !dstRect.left.isFinite ||
        !dstRect.top.isFinite ||
        !dstRect.right.isFinite ||
        !dstRect.bottom.isFinite) {
      throw ArgumentError('矩形坐标包含无效数值');
    }

    // 在绘制前进行最后的验证
    if (srcRect.isEmpty ||
        dstRect.isEmpty ||
        !srcRect.isFinite ||
        !dstRect.isFinite) {
      throw ArgumentError('矩形参数无效');
    }

    canvas.drawImageRect(image, srcRect, dstRect, Paint());

    final picture = recorder.endRecording();
    // 检查尺寸有效性
    if (targetWidth <= 0 || targetHeight <= 0) {
      throw ArgumentError('缩放图像尺寸无效');
    }
    return await picture.toImage(targetWidth, targetHeight);
  }

  /// 创建模糊背景
  Future<ui.Image> createBlurredBackground(
    ui.Image image,
    double blurSigma,
  ) async {
    // 检查参数有效性
    if (blurSigma < 0) {
      throw ArgumentError('模糊sigma值不能为负数');
    }

    // 检查源图像有效性
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('源图像尺寸无效');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

    canvas.drawImage(image, Offset.zero, paint);

    // 添加白色遮罩
    canvas.drawRect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );

    final picture = recorder.endRecording();
    // 检查尺寸有效性
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('模糊背景图像尺寸无效');
    }
    return await picture.toImage(image.width, image.height);
  }

  /// 获取字体样式
  TextStyle getTextStyle(ElementConfig element, {double fontSize = 14}) {
    final fontFamily = element.isBold
        ? 'AlibabaPuHuiTi-Bold'
        : 'AlibabaPuHuiTi-Light';

    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize * config.fontSize,
      color: element.color,
      fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
    );
  }
}

/// Normal布局处理器 - 优化版本
class NormalWatermarkProcessor extends WatermarkProcessor {
  NormalWatermarkProcessor(super.config);

  /// 填充图像以匹配目标高度
  Future<ui.Image> padImage(ui.Image image, int targetHeight) async {
    if (image.height >= targetHeight) {
      return image;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final y = (targetHeight - image.height) / 2.0;
    canvas.drawImage(image, Offset(0, y), Paint());

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, targetHeight);
  }

  @override
  Future<ui.Image> process(ImageContainer container) async {
    // 验证容器有效性
    if (container.width <= 0 || container.height <= 0) {
      throw ArgumentError('图像容器尺寸无效: ${container.width}x${container.height}');
    }

    // 预计算所有尺寸参数
    final dimensions = _calculateDimensions(container);

    // 并行创建所有文本图像，减少等待时间
    final textImagesFuture = _createAllTextImages(container, dimensions);

    // 并行加载Logo（如果需要）
    final logoFuture = config.logoEnabled
        ? _loadAndResizeLogo(container.make, dimensions.watermarkHeight)
        : Future.value(null);

    // 等待所有异步操作完成
    final results = await Future.wait([textImagesFuture, logoFuture]);
    final textImages = results[0] as _TextImages;
    final logo = results[1] as ui.Image?;

    // 一次性创建水印条，避免多次Canvas操作
    final watermark = await _createWatermarkStrip(
      container,
      dimensions,
      textImages,
      logo,
    );

    // 合并原图和水印
    final result = await _combineImageAndWatermark(
      container,
      watermark,
      dimensions,
    );

    // 清理中间资源
    _cleanupResources(textImages, logo);

    return result;
  }

  /// 计算所有尺寸参数
  _WatermarkDimensions _calculateDimensions(ImageContainer container) {
    // 根据图片长宽比，动态调整水印占比和边距
    final isHorizontal = container.aspectRatio >= 1;
    final watermarkHeightRatio = isHorizontal ? 0.08 : 0.09;
    final paddingRatio = isHorizontal ? 0.25 : 0.3;
    final fontScaleFactor = isHorizontal ? 1.0 : 0.8; // 新增字体缩放因子

    double watermarkHeight = container.height * watermarkHeightRatio;
    final padding = watermarkHeight * paddingRatio;

    // 预估文字高度，确保水印区域足够高
    final estimatedTextHeight = watermarkHeight * 0.28 * 2 + padding * 0.5;
    final minRequiredHeight = estimatedTextHeight + padding * 2;

    if (watermarkHeight < minRequiredHeight) {
      watermarkHeight = math.min(minRequiredHeight, container.height * 0.15);
    }

    final maxTextWidth = container.width * (isHorizontal ? 0.4 : 0.8);

    return _WatermarkDimensions(
      watermarkHeight: watermarkHeight,
      padding: padding,
      maxTextWidth: maxTextWidth,
      watermarkWidth: container.width,
      fontScaleFactor: fontScaleFactor,
    );
  }

  /// 并行创建所有文本图像
  Future<_TextImages> _createAllTextImages(
    ImageContainer container,
    _WatermarkDimensions dimensions,
  ) async {
    // 并行创建四个文本图像
    final futures = [
      createTextImage(
        container.getAttributeString(
          config.leftTop.type,
          customValue: config.leftTop.customValue,
        ),
        getTextStyle(
          config.leftTop,
          fontSize:
              dimensions.watermarkHeight * 0.28 * dimensions.fontScaleFactor,
        ),
        dimensions.maxTextWidth,
      ),
      createTextImage(
        container.getAttributeString(
          config.leftBottom.type,
          customValue: config.leftBottom.customValue,
        ),
        getTextStyle(
          config.leftBottom,
          fontSize:
              dimensions.watermarkHeight * 0.24 * dimensions.fontScaleFactor,
        ),
        dimensions.maxTextWidth,
      ),
      createTextImage(
        container.getAttributeString(
          config.rightTop.type,
          customValue: config.rightTop.customValue,
        ),
        getTextStyle(
          config.rightTop,
          fontSize:
              dimensions.watermarkHeight * 0.28 * dimensions.fontScaleFactor,
        ),
        dimensions.maxTextWidth,
      ),
      createTextImage(
        container.getAttributeString(
          config.rightBottom.type,
          customValue: config.rightBottom.customValue,
        ),
        getTextStyle(
          config.rightBottom,
          fontSize:
              dimensions.watermarkHeight * 0.24 * dimensions.fontScaleFactor,
        ),
        dimensions.maxTextWidth,
      ),
    ];

    final results = await Future.wait(futures);

    // 并行合并左右文字
    final mergeFutures = [
      mergeImages(
        [results[0], results[1]],
        vertical: true,
        alignment: Alignment.centerLeft,
        spacing: dimensions.padding * 0.5,
      ),
      mergeImages(
        [results[2], results[3]],
        vertical: true,
        alignment: Alignment.centerRight,
        spacing: dimensions.padding * 0.5,
      ),
    ];

    final mergedResults = await Future.wait(mergeFutures);

    // 统一高度
    final maxHeight = math.max(
      mergedResults[0].height,
      mergedResults[1].height,
    );
    final paddedFutures = [
      padImage(mergedResults[0], maxHeight),
      padImage(mergedResults[1], maxHeight),
    ];
    final paddedResults = await Future.wait(paddedFutures);

    return _TextImages(
      leftTop: results[0],
      leftBottom: results[1],
      rightTop: results[2],
      rightBottom: results[3],
      leftText: paddedResults[0],
      rightText: paddedResults[1],
    );
  }

  /// 加载并调整Logo尺寸
  Future<ui.Image?> _loadAndResizeLogo(
    String make,
    double watermarkHeight,
  ) async {
    final logo = await loadLogo(make);
    if (logo == null) return null;

    final logoHeight = (watermarkHeight * 0.8).toInt();
    final logoWidth = (logo.width * logoHeight / logo.height).toInt();
    final resizedLogo = await resizeImage(logo, logoWidth, logoHeight);

    // 释放原始Logo
    logo.dispose();
    return resizedLogo;
  }

  /// 创建水印条
  Future<ui.Image> _createWatermarkStrip(
    ImageContainer container,
    _WatermarkDimensions dimensions,
    _TextImages textImages,
    ui.Image? logo,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        dimensions.watermarkWidth.toDouble(),
        dimensions.watermarkHeight,
      ),
      Paint()..color = config.backgroundColor,
    );

    // 使用优化的绘制逻辑
    await _drawWatermarkContent(canvas, dimensions, textImages, logo);

    final picture = recorder.endRecording();
    return await picture.toImage(
      dimensions.watermarkWidth,
      dimensions.watermarkHeight.toInt(),
    );
  }

  /// 绘制水印内容
  Future<void> _drawWatermarkContent(
    Canvas canvas,
    _WatermarkDimensions dimensions,
    _TextImages textImages,
    ui.Image? logo,
  ) async {
    // 预计算位置信息
    final positions = _calculateContentPositions(dimensions, textImages, logo);

    // 批量绘制，减少Paint对象创建
    final paint = Paint();

    // 绘制左侧内容
    _drawLeftContent(canvas, paint, positions, textImages, logo, dimensions);

    // 绘制右侧内容
    _drawRightContent(canvas, paint, positions, textImages, logo, dimensions);
  }

  /// 计算内容位置
  _ContentPositions _calculateContentPositions(
    _WatermarkDimensions dimensions,
    _TextImages textImages,
    ui.Image? logo,
  ) {
    // 计算基础位置
    double leftContentY =
        (dimensions.watermarkHeight - textImages.leftText.height) / 2;
    double rightContentY =
        (dimensions.watermarkHeight - textImages.rightText.height) / 2;
    double logoY = (dimensions.watermarkHeight - (logo?.height ?? 0)) / 2;

    // 考虑白边影响
    if (config.whiteMarginEnabled) {
      final borderWidth =
          dimensions.watermarkWidth * config.whiteMarginWidth / 100;
      leftContentY =
          (dimensions.watermarkHeight -
                  textImages.leftText.height -
                  2 * borderWidth) /
              2 +
          borderWidth;
      rightContentY =
          (dimensions.watermarkHeight -
                  textImages.rightText.height -
                  2 * borderWidth) /
              2 +
          borderWidth;
      logoY =
          (dimensions.watermarkHeight - (logo?.height ?? 0) - 2 * borderWidth) /
              2 +
          borderWidth;
    }

    return _ContentPositions(
      leftContentY: math.max(0.0, leftContentY),
      rightContentY: math.max(0.0, rightContentY),
      logoY: math.max(0.0, logoY),
      padding: dimensions.padding,
    );
  }

  /// 绘制左侧内容
  void _drawLeftContent(
    Canvas canvas,
    Paint paint,
    _ContentPositions positions,
    _TextImages textImages,
    ui.Image? logo,
    _WatermarkDimensions dimensions,
  ) {
    if (logo != null) {
      switch (config.logoPosition) {
        case LogoPosition.leftTextLeft:
          _drawLogoTextLayout(
            canvas,
            paint,
            positions,
            logo,
            textImages.leftText,
            true,
            dimensions,
          );
          break;
        case LogoPosition.leftTextRight:
          _drawTextLogoLayout(
            canvas,
            paint,
            positions,
            textImages.leftText,
            logo,
            true,
            dimensions,
          );
          break;
        default:
          canvas.drawImage(
            textImages.leftText,
            Offset(positions.padding, positions.leftContentY),
            paint,
          );
      }
    } else {
      canvas.drawImage(
        textImages.leftText,
        Offset(positions.padding, positions.leftContentY),
        paint,
      );
    }
  }

  /// 绘制右侧内容
  void _drawRightContent(
    Canvas canvas,
    Paint paint,
    _ContentPositions positions,
    _TextImages textImages,
    ui.Image? logo,
    _WatermarkDimensions dimensions,
  ) {
    final watermarkWidth = dimensions.watermarkWidth.toDouble();
    final rightTextWidth = textImages.rightText.width.toDouble();

    if (logo != null) {
      switch (config.logoPosition) {
        case LogoPosition.rightTextLeft:
          _drawLogoTextLayout(
            canvas,
            paint,
            positions,
            logo,
            textImages.rightText,
            false,
            dimensions,
          );
          break;
        case LogoPosition.rightTextRight:
          _drawTextLogoLayout(
            canvas,
            paint,
            positions,
            textImages.rightText,
            logo,
            false,
            dimensions,
          );
          break;
        default:
          final textX = watermarkWidth - rightTextWidth - positions.padding;
          canvas.drawImage(
            textImages.rightText,
            Offset(textX, positions.rightContentY),
            paint,
          );
      }
    } else {
      final textX = watermarkWidth - rightTextWidth - positions.padding;
      canvas.drawImage(
        textImages.rightText,
        Offset(textX, positions.rightContentY),
        paint,
      );
    }
  }

  /// 绘制Logo-文本布局
  void _drawLogoTextLayout(
    Canvas canvas,
    Paint paint,
    _ContentPositions positions,
    ui.Image logo,
    ui.Image text,
    bool isLeft,
    _WatermarkDimensions dimensions,
  ) {
    // 实现Logo在文本左侧的布局逻辑
    // 简化实现，避免复杂的计算
    if (isLeft) {
      canvas.drawImage(logo, Offset(positions.padding, positions.logoY), paint);
      canvas.drawImage(
        text,
        Offset(
          positions.padding + logo.width + positions.padding * 0.5,
          positions.leftContentY,
        ),
        paint,
      );
    } else {
      final watermarkWidth = dimensions.watermarkWidth.toDouble();
      final totalWidth = logo.width + text.width + positions.padding * 0.5;
      final startX = watermarkWidth - totalWidth - positions.padding;
      canvas.drawImage(logo, Offset(startX, positions.logoY), paint);
      canvas.drawImage(
        text,
        Offset(
          startX + logo.width + positions.padding * 0.5,
          positions.rightContentY,
        ),
        paint,
      );
    }
  }

  /// 绘制文本-Logo布局
  void _drawTextLogoLayout(
    Canvas canvas,
    Paint paint,
    _ContentPositions positions,
    ui.Image text,
    ui.Image logo,
    bool isLeft,
    _WatermarkDimensions dimensions,
  ) {
    // 实现文本在Logo左侧的布局逻辑
    if (isLeft) {
      canvas.drawImage(
        text,
        Offset(positions.padding, positions.leftContentY),
        paint,
      );
      canvas.drawImage(
        logo,
        Offset(
          positions.padding + text.width + positions.padding * 0.5,
          positions.logoY,
        ),
        paint,
      );
    } else {
      final watermarkWidth = dimensions.watermarkWidth.toDouble();
      final totalWidth = text.width + logo.width + positions.padding * 0.5;
      final startX = watermarkWidth - totalWidth - positions.padding;
      canvas.drawImage(text, Offset(startX, positions.rightContentY), paint);
      canvas.drawImage(
        logo,
        Offset(startX + text.width + positions.padding * 0.5, positions.logoY),
        paint,
      );
    }
  }

  /// 合并图像和水印
  Future<ui.Image> _combineImageAndWatermark(
    ImageContainer container,
    ui.Image watermark,
    _WatermarkDimensions dimensions,
  ) async {
    final finalHeight = container.height + dimensions.watermarkHeight.toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制原图
    canvas.drawImage(container.watermarkImage, Offset.zero, Paint());

    // 绘制水印
    canvas.drawImage(
      watermark,
      Offset(0, container.height.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    var result = await picture.toImage(container.width, finalHeight);

    // 优先添加阴影（如果启用）
    if (config.shadowEnabled) {
      result = await addShadow(result);
    }

    // 再添加白边（如果启用），这样阴影就会在白边内部
    if (config.whiteMarginEnabled) {
      final borderWidth = container.width * config.whiteMarginWidth / 100;
      result = await addBorder(result, borderWidth, config.backgroundColor);
    }

    // 释放水印图像
    watermark.dispose();

    return result;
  }

  /// 清理资源
  void _cleanupResources(_TextImages textImages, ui.Image? logo) {
    textImages.leftTop.dispose();
    textImages.leftBottom.dispose();
    textImages.rightTop.dispose();
    textImages.rightBottom.dispose();
    textImages.leftText.dispose();
    textImages.rightText.dispose();
    logo?.dispose();
  }
}

/// 黑红配色水印处理器
class DarkWatermarkProcessor extends NormalWatermarkProcessor {
  DarkWatermarkProcessor(WatermarkConfig config)
    : super(
        // 创建一个修改后的配置，使用黑红配色，但保留用户选择的Logo位置
        config.copyWith(
          backgroundColor: const Color(0xFF212121), // 深灰色背景
          leftTop: config.leftTop.copyWith(
            color: const Color(0xFFD32F2F), // 红色
            isBold: true,
          ),
          leftBottom: config.leftBottom.copyWith(
            color: const Color(0xFFD4D1CC), // 浅灰色
            isBold: false,
          ),
          rightTop: config.rightTop.copyWith(
            color: const Color(0xFFD32F2F), // 红色
            isBold: true,
          ),
          rightBottom: config.rightBottom.copyWith(
            color: const Color(0xFFD4D1CC), // 浅灰色
            isBold: false,
          ),
        ),
      );
}

/// 背景模糊+白框处理器
class BackgroundBlurWithBorderProcessor extends WatermarkProcessor {
  BackgroundBlurWithBorderProcessor(super.config);

  @override
  Future<ui.Image> process(ImageContainer container) async {
    final paddingPercent =
        config.layoutType == WatermarkLayoutType.backgroundBlurWithBorder
        ? ((config.extraSettings['backgroundBlurPaddingPercent'] ?? 0.18)
              as double)
        : 0.18;
    final blurSigma = 35.0;

    // 先生成带水印的前景图像
    final normalProcessor = NormalWatermarkProcessor(config);
    final watermarkedImage = await normalProcessor.process(container);

    // 计算白边宽度
    final borderWidth =
        config.whiteMarginWidth *
        math.min(watermarkedImage.width, watermarkedImage.height) /
        256;

    // 给带水印的图像添加白色边框
    final imageWithBorder = await addBorder(
      watermarkedImage,
      borderWidth,
      Colors.white,
    );

    // 创建模糊背景 - 使用原始图像
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    canvas.drawImage(container.originalImage, Offset.zero, paint);

    final blurredPicture = recorder.endRecording();
    final blurredImage = await blurredPicture.toImage(
      container.width,
      container.height,
    );

    // 计算新尺寸（基于带边框的图像）
    final newWidth = (imageWithBorder.width * (1 + paddingPercent)).toInt();
    final newHeight = (imageWithBorder.height * (1 + paddingPercent)).toInt();

    // 缩放模糊背景到新尺寸
    final scaledBackground = await resizeImage(
      blurredImage,
      newWidth,
      newHeight,
    );

    // 创建最终图像
    final finalRecorder = ui.PictureRecorder();
    final finalCanvas = Canvas(finalRecorder);

    // 绘制缩放后的模糊背景
    finalCanvas.drawImage(scaledBackground, Offset.zero, Paint());

    // 添加白色遮罩层（10%不透明度）
    finalCanvas.drawRect(
      Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );

    // 绘制带白框的水印图（居中）
    final offsetX = (newWidth - imageWithBorder.width) / 2;
    final offsetY = (newHeight - imageWithBorder.height) / 2;
    finalCanvas.drawImage(imageWithBorder, Offset(offsetX, offsetY), Paint());

    final finalPicture = finalRecorder.endRecording();
    final result = await finalPicture.toImage(newWidth, newHeight);

    // 清理资源
    watermarkedImage.dispose();
    imageWithBorder.dispose();
    blurredImage.dispose();
    scaledBackground.dispose();

    return result;
  }
}

/// 处理器工厂
class WatermarkProcessorFactory {
  static WatermarkProcessor create(WatermarkConfig config) {
    switch (config.layoutType) {
      case WatermarkLayoutType.pureWhiteBorder:
        return NormalWatermarkProcessor(config);
      case WatermarkLayoutType.darkWatermarkLeftLogo:
        return DarkWatermarkProcessor(config);
      case WatermarkLayoutType.backgroundBlurWithBorder:
        return BackgroundBlurWithBorderProcessor(config);
    }
  }
}
