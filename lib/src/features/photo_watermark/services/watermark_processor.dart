import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/watermark_config.dart';
import '../models/image_container.dart';

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

  /// 创建文字图像
  Future<ui.Image> createTextImage(
    String text,
    TextStyle style,
    double maxWidth,
  ) async {
    // 检查参数有效性
    if (maxWidth <= 0 || !maxWidth.isFinite) {
      throw ArgumentError('最大宽度必须大于0且为有限值');
    }

    // 检查字体大小有效性
    if (style.fontSize == null ||
        style.fontSize! <= 0 ||
        !style.fontSize!.isFinite) {
      throw ArgumentError('字体大小必须大于0且为有限值');
    }

    // 如果文本为空，返回一个空图像
    if (text.isEmpty) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // 绘制一个透明像素以确保图像有效
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = Colors.transparent,
      );
      final picture = recorder.endRecording();
      return await picture.toImage(1, 1);
    }

    // 创建文本画笔
    TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    // 布局文本
    textPainter.layout(maxWidth: maxWidth);

    // 如果文本宽度超过了最大宽度，调整字体大小
    TextStyle adjustedStyle = style;
    if (textPainter.width > maxWidth * 0.95) {
      // 留出5%的边距
      final scale = (maxWidth * 0.95) / textPainter.width;
      final adjustedFontSize = style.fontSize! * scale;
      adjustedStyle = style.copyWith(fontSize: adjustedFontSize);

      // 重新创建文本画笔并布局
      textPainter = TextPainter(
        text: TextSpan(text: text, style: adjustedStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: maxWidth);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    // 确保图像至少有1x1的尺寸，避免创建无效图像
    final width = math.max(1, textPainter.width.ceil());
    final height = math.max(1, textPainter.height.ceil());

    // 检查尺寸有效性
    if (width <= 0 || height <= 0 || !width.isFinite || !height.isFinite) {
      throw ArgumentError('文本图像尺寸无效: width=$width, height=$height');
    }

    // 限制最大尺寸以避免内存问题
    final maxSize = 4096;
    final finalWidth = math.min(width, maxSize);
    final finalHeight = math.min(height, maxSize);

    final image = await picture.toImage(finalWidth, finalHeight);

    return image;
  }

  /// 合并图像（垂直或水平）
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

    // 检查所有图像的有效性
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      if (image.width <= 0 || image.height <= 0) {
        throw ArgumentError('图像 $i 尺寸无效: ${image.width}x${image.height}');
      }
    }

    // 计算总尺寸
    int totalWidth = 0;
    int totalHeight = 0;

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

    // 创建画布
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 填充背景
    if (backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight.toDouble()),
        Paint()..color = backgroundColor,
      );
    }

    // 绘制图像
    double offset = 0;
    for (final image in images) {
      double x = 0;
      double y = 0;

      if (vertical) {
        y = offset;
        // 根据对齐方式计算x坐标
        if (alignment == Alignment.center) {
          x = (totalWidth - image.width) / 2;
        } else if (alignment == Alignment.centerRight) {
          x = totalWidth - image.width.toDouble();
        }
      } else {
        x = offset;
        // 根据对齐方式计算y坐标
        if (alignment == Alignment.center) {
          y = (totalHeight - image.height) / 2;
        } else if (alignment == Alignment.bottomCenter) {
          y = totalHeight - image.height.toDouble();
        }
      }

      canvas.drawImage(image, Offset(x, y), Paint());

      if (vertical) {
        offset += image.height + spacing;
      } else {
        offset += image.width + spacing;
      }
    }

    final picture = recorder.endRecording();
    // 检查尺寸有效性
    if (totalWidth <= 0 || totalHeight <= 0) {
      throw ArgumentError('合并图像尺寸无效');
    }
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

/// Normal布局处理器
class NormalWatermarkProcessor extends WatermarkProcessor {
  NormalWatermarkProcessor(super.config);

  @override
  Future<ui.Image> process(ImageContainer container) async {
    // 验证容器有效性
    if (container.width <= 0 || container.height <= 0) {
      throw ArgumentError('图像容器尺寸无效: ${container.width}x${container.height}');
    }

    // 计算水印高度 - 调整为8%以避免文字过大
    double watermarkHeight = container.height * 0.08;
    // 调整内边距为高度的25%
    final padding = watermarkHeight * 0.25;

    // 验证计算结果有效性
    if (!watermarkHeight.isFinite ||
        watermarkHeight <= 0 ||
        !padding.isFinite ||
        padding < 0) {
      throw ArgumentError('水印尺寸计算结果无效');
    }

    // 预估文字高度，确保水印区域足够高
    final estimatedTextHeight =
        watermarkHeight * 0.28 * 2 + padding * 0.5; // 两行文字加间距
    final minRequiredHeight = estimatedTextHeight + padding * 2; // 加上上下边距

    if (watermarkHeight < minRequiredHeight) {
      watermarkHeight = math.min(
        minRequiredHeight,
        container.height * 0.15,
      ); // 最大不超过图像高度的15%
    }

    // 计算最大文字宽度，考虑Logo和边距
    final maxTextWidth = container.width * 0.4; // 每侧最多占40%的宽度

    // 验证文字宽度有效性
    if (!maxTextWidth.isFinite || maxTextWidth <= 0) {
      throw ArgumentError('文字宽度计算结果无效');
    }

    // 创建四角文字 - 调整字体大小比例
    final leftTop = await createTextImage(
      container.getAttributeString(
        config.leftTop.type,
        customValue: config.leftTop.customValue,
      ),
      getTextStyle(config.leftTop, fontSize: watermarkHeight * 0.28), // 减小字体
      maxTextWidth,
    );

    final leftBottom = await createTextImage(
      container.getAttributeString(
        config.leftBottom.type,
        customValue: config.leftBottom.customValue,
      ),
      getTextStyle(config.leftBottom, fontSize: watermarkHeight * 0.24), // 减小字体
      maxTextWidth,
    );

    final rightTop = await createTextImage(
      container.getAttributeString(
        config.rightTop.type,
        customValue: config.rightTop.customValue,
      ),
      getTextStyle(config.rightTop, fontSize: watermarkHeight * 0.28), // 减小字体
      maxTextWidth,
    );

    final rightBottom = await createTextImage(
      container.getAttributeString(
        config.rightBottom.type,
        customValue: config.rightBottom.customValue,
      ),
      getTextStyle(
        config.rightBottom,
        fontSize: watermarkHeight * 0.24,
      ), // 减小字体
      maxTextWidth,
    );

    // 合并左侧文字 - 调整间距
    final leftText = await mergeImages(
      [leftTop, leftBottom],
      vertical: true,
      alignment: Alignment.centerLeft,
      spacing: padding * 0.5, // 减小文字间距
    );

    // 合并右侧文字 - 调整间距
    final rightText = await mergeImages(
      [rightTop, rightBottom],
      vertical: true,
      alignment: Alignment.centerRight,
      spacing: padding * 0.5, // 减小文字间距
    );

    // 加载Logo
    ui.Image? logo;
    if (config.logoEnabled) {
      logo = await loadLogo(container.make);
      if (logo != null) {
        // 缩放Logo到合适大小 - 调整为80%高度
        final logoHeight = (watermarkHeight * 0.8).toInt();
        final logoWidth = (logo.width * logoHeight / logo.height).toInt();
        logo = await resizeImage(logo, logoWidth, logoHeight);
      }
    }

    // 创建水印条
    final watermarkWidth = container.width;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, watermarkWidth.toDouble(), watermarkHeight),
      Paint()..color = config.backgroundColor,
    );

    // 绘制左侧内容
    // 计算考虑白边宽度的垂直居中位置
    double leftContentY = (watermarkHeight - leftText.height) / 2;
    double logoY = (watermarkHeight - (logo?.height ?? 0)) / 2;

    // 如果启用了白边，需要考虑白边宽度对内容位置的影响
    if (config.whiteMarginEnabled) {
      final borderWidth = watermarkWidth * config.whiteMarginWidth / 100;
      leftContentY =
          (watermarkHeight - leftText.height - 2 * borderWidth) / 2 +
          borderWidth;
      logoY =
          (watermarkHeight - (logo?.height ?? 0) - 2 * borderWidth) / 2 +
          borderWidth;
    }

    // 确保Y坐标不为负数且为有效值
    leftContentY = (leftContentY.isFinite && leftContentY >= 0)
        ? leftContentY
        : 0.0;
    logoY = (logoY.isFinite && logoY >= 0) ? logoY : 0.0;

    // 确保所有值都是有效的
    final validPadding = (padding.isFinite && padding >= 0) ? padding : 10.0;
    final validLogoY = logoY;
    final validLeftContentY = leftContentY;
    final validLogoWidth = (logo?.width ?? 0).toDouble();

    // 确保Logo宽度是有效值
    final safeLogoWidth = validLogoWidth.isFinite ? validLogoWidth : 0.0;

    // 绘制左侧内容和Logo
    if (logo != null) {
      switch (config.logoPosition) {
        case LogoPosition.leftTextLeft:
          // Logo在左侧文字左侧
          canvas.drawImage(logo, Offset(validPadding, validLogoY), Paint());
          // 添加分隔线
          final separatorX = validPadding + safeLogoWidth + validPadding / 2;
          final separatorY1 = validLogoY + logo.height * 0.2;
          final separatorY2 = validLogoY + logo.height * 0.8;
          // 确保分隔线坐标有效
          if (separatorX.isFinite &&
              separatorY1.isFinite &&
              separatorY2.isFinite) {
            canvas.drawLine(
              Offset(separatorX, separatorY1),
              Offset(separatorX, separatorY2),
              Paint()
                ..color = Colors.grey.withValues(alpha: 0.5)
                ..strokeWidth = 1,
            );
          }
          final leftTextX = separatorX + validPadding / 2;
          if (leftTextX.isFinite && leftTextX >= 0) {
            canvas.drawImage(
              leftText,
              Offset(leftTextX, validLeftContentY),
              Paint(),
            );
          }
          break;
        case LogoPosition.leftTextRight:
          // Logo在左侧文字右侧
          canvas.drawImage(
            leftText,
            Offset(validPadding, validLeftContentY),
            Paint(),
          );
          // 添加分隔线
          final separatorX = validPadding + leftText.width + validPadding / 2;
          final separatorY1 = validLogoY + logo.height * 0.2;
          final separatorY2 = validLogoY + logo.height * 0.8;
          // 确保分隔线坐标有效
          if (separatorX.isFinite &&
              separatorY1.isFinite &&
              separatorY2.isFinite) {
            canvas.drawLine(
              Offset(separatorX, separatorY1),
              Offset(separatorX, separatorY2),
              Paint()
                ..color = Colors.grey.withValues(alpha: 0.5)
                ..strokeWidth = 1,
            );
          }
          final logoX = separatorX + validPadding / 2;
          if (logoX.isFinite && logoX >= 0) {
            canvas.drawImage(logo, Offset(logoX, validLogoY), Paint());
          }
          break;
        default:
          // 默认布局：文字居左
          canvas.drawImage(
            leftText,
            Offset(validPadding, validLeftContentY),
            Paint(),
          );
      }
    } else {
      // 没有Logo时的布局
      canvas.drawImage(
        leftText,
        Offset(validPadding, validLeftContentY),
        Paint(),
      );
    }

    // 绘制右侧内容
    // 计算考虑白边宽度的垂直居中位置
    double rightContentY = (watermarkHeight - rightText.height) / 2;
    double rightLogoY = (watermarkHeight - (logo?.height ?? 0)) / 2;

    // 如果启用了白边，需要考虑白边宽度对内容位置的影响
    if (config.whiteMarginEnabled) {
      final borderWidth = watermarkWidth * config.whiteMarginWidth / 100;
      rightContentY =
          (watermarkHeight - rightText.height - 2 * borderWidth) / 2 +
          borderWidth;
      rightLogoY =
          (watermarkHeight - (logo?.height ?? 0) - 2 * borderWidth) / 2 +
          borderWidth;
    }

    // 确保Y坐标不为负数且为有效值
    rightContentY = (rightContentY.isFinite && rightContentY >= 0)
        ? rightContentY
        : 0.0;
    rightLogoY = (rightLogoY.isFinite && rightLogoY >= 0) ? rightLogoY : 0.0;

    // 确保所有值都是有效的
    final validWatermarkWidth = watermarkWidth.toDouble().isFinite
        ? watermarkWidth.toDouble()
        : 100.0;
    final validRightTextWidth = rightText.width.toDouble().isFinite
        ? rightText.width.toDouble()
        : 0.0;
    final validRightContentY = rightContentY;
    final validRightLogoY = rightLogoY;
    final validRightLogoWidth = (logo?.width ?? 0).toDouble();
    final safeRightLogoWidth = validRightLogoWidth.isFinite
        ? validRightLogoWidth
        : 0.0;

    // 绘制右侧内容和Logo
    if (logo != null) {
      switch (config.logoPosition) {
        case LogoPosition.rightTextLeft:
          // Logo在右侧文字左侧
          final logoX =
              validWatermarkWidth -
              validRightTextWidth -
              safeRightLogoWidth -
              validPadding * 2;
          if (logoX.isFinite && logoX >= 0) {
            canvas.drawImage(logo, Offset(logoX, validRightLogoY), Paint());
          }
          // 添加分隔线
          final separatorX =
              validWatermarkWidth - validRightTextWidth - validPadding * 1.5;
          final separatorY1 = validRightLogoY + logo.height * 0.2;
          final separatorY2 = validRightLogoY + logo.height * 0.8;
          if (separatorX.isFinite &&
              separatorY1.isFinite &&
              separatorY2.isFinite) {
            canvas.drawLine(
              Offset(separatorX, separatorY1),
              Offset(separatorX, separatorY2),
              Paint()
                ..color = Colors.grey.withValues(alpha: 0.5)
                ..strokeWidth = 1,
            );
          }
          final textX =
              validWatermarkWidth - validRightTextWidth - validPadding;
          if (textX.isFinite && textX >= 0) {
            canvas.drawImage(
              rightText,
              Offset(textX, validRightContentY),
              Paint(),
            );
          }
          break;
        case LogoPosition.rightTextRight:
          // Logo在右侧文字右侧
          final textX =
              validWatermarkWidth -
              validRightTextWidth -
              safeRightLogoWidth -
              validPadding * 2;
          if (textX.isFinite && textX >= 0) {
            canvas.drawImage(
              rightText,
              Offset(textX, validRightContentY),
              Paint(),
            );
          }
          // 添加分隔线
          final separatorX =
              validWatermarkWidth - safeRightLogoWidth - validPadding * 1.5;
          final separatorY1 = validRightLogoY + logo.height * 0.2;
          final separatorY2 = validRightLogoY + logo.height * 0.8;
          if (separatorX.isFinite &&
              separatorY1.isFinite &&
              separatorY2.isFinite) {
            canvas.drawLine(
              Offset(separatorX, separatorY1),
              Offset(separatorX, separatorY2),
              Paint()
                ..color = Colors.grey.withValues(alpha: 0.5)
                ..strokeWidth = 1,
            );
          }
          final logoX = validWatermarkWidth - safeRightLogoWidth - validPadding;
          if (logoX.isFinite && logoX >= 0) {
            canvas.drawImage(logo, Offset(logoX, validRightLogoY), Paint());
          }
          break;
        default:
          // 默认布局：文字居右
          final textX =
              validWatermarkWidth - validRightTextWidth - validPadding;
          if (textX.isFinite && textX >= 0) {
            canvas.drawImage(
              rightText,
              Offset(textX, validRightContentY),
              Paint(),
            );
          }
      }
    } else {
      // 没有Logo时的布局
      final textX = validWatermarkWidth - validRightTextWidth - validPadding;
      if (textX.isFinite && textX >= 0) {
        canvas.drawImage(rightText, Offset(textX, validRightContentY), Paint());
      }
    }

    final watermarkPicture = recorder.endRecording();
    final watermark = await watermarkPicture.toImage(
      watermarkWidth,
      watermarkHeight.toInt(),
    );

    // 合并原图和水印
    final finalHeight = container.height + watermarkHeight.toInt();
    final finalRecorder = ui.PictureRecorder();
    final finalCanvas = Canvas(finalRecorder);

    // 绘制原图
    finalCanvas.drawImage(container.watermarkImage, Offset.zero, Paint());

    // 绘制水印
    finalCanvas.drawImage(
      watermark,
      Offset(0, container.height.toDouble()),
      Paint(),
    );

    final finalPicture = finalRecorder.endRecording();
    var result = await finalPicture.toImage(container.width, finalHeight);

    // 添加白边（如果启用）
    if (config.whiteMarginEnabled) {
      final borderWidth = container.width * config.whiteMarginWidth / 100;
      result = await addBorder(result, borderWidth, config.backgroundColor);
    }

    // 添加阴影（如果启用）
    if (config.shadowEnabled) {
      result = await addShadow(result);
    }

    // 清理资源
    leftTop.dispose();
    leftBottom.dispose();
    rightTop.dispose();
    rightBottom.dispose();
    leftText.dispose();
    rightText.dispose();
    watermark.dispose();
    logo?.dispose();

    return result;
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
