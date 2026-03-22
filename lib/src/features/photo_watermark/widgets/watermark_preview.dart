import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../photo_watermark_provider.dart';
import '../design_tokens.dart';

/// 水印预览组件 - 优化版，带棋盘背景
class WatermarkPreview extends StatelessWidget {
  const WatermarkPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final previewImage = context.select<PhotoWatermarkProvider, ui.Image?>(
      (provider) => provider.previewImage,
    );

    if (previewImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (previewImage.width <= 0 || previewImage.height <= 0) {
      return const Center(child: Text('图像尺寸无效'));
    }

    return RepaintBoundary(
      child: Container(
        color: DesignTokens.backgroundPrimary,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = previewImage.width.toDouble();
              final imageHeight = previewImage.height.toDouble();
              final containerWidth = constraints.maxWidth;
              final containerHeight = constraints.maxHeight;

              final scaleX = containerWidth / imageWidth;
              final scaleY = containerHeight / imageHeight;
              final scale = math.min(scaleX, scaleY) * 0.95;

              final scaledWidth = imageWidth * scale;
              final scaledHeight = imageHeight * scale;

              if (scaledWidth <= 0 || scaledHeight <= 0) {
                return const Center(child: Text('缩放后尺寸无效'));
              }

              return InteractiveViewer(
                minScale: 0.1,
                maxScale: 5.0,
                child: Container(
                  width: scaledWidth,
                  height: scaledHeight,
                  decoration: BoxDecoration(
                    boxShadow: DesignTokens.shadowLarge,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _CheckerboardPainter()),
                      ),
                      CustomPaint(
                        size: Size(scaledWidth, scaledHeight),
                        painter: _ImagePainter(previewImage),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 棋盘背景绘制器
class _CheckerboardPainter extends CustomPainter {
  static const double tileSize = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rows = (size.height / tileSize).ceil();
    final cols = (size.width / tileSize).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final isEven = (row + col) % 2 == 0;
        paint.color = isEven
            ? DesignTokens.checkerboardLight
            : DesignTokens.checkerboardDark;

        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );

        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}

/// 图像绘制器 - 优化版
class _ImagePainter extends CustomPainter {
  final ui.Image image;

  _ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // 检查图像是否有效
    if (image.width <= 0 || image.height <= 0) {
      return;
    }

    // 检查目标尺寸是否有效
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    // 检查图像是否已释放
    try {
      // 尝试访问图像属性以检查是否有效
      final width = image.width;
      final height = image.height;

      // 确保宽度和高度是有效的正数
      if (width <= 0 || height <= 0) {
        return;
      }

      // 添加额外的检查以确保矩形有效
      final srcRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

      // 检查矩形是否有效
      if (srcRect.isEmpty || dstRect.isEmpty) {
        return;
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
        return;
      }

      // 额外检查：确保源矩形和目标矩形都有正的宽度和高度
      if (srcRect.width <= 0 ||
          srcRect.height <= 0 ||
          dstRect.width <= 0 ||
          dstRect.height <= 0) {
        return;
      }

      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      // 在绘制前再次验证图像是否仍然有效
      if (image.width > 0 && image.height > 0) {
        canvas.drawImageRect(image, srcRect, dstRect, paint);
      }
    } catch (e) {
      // 图像已释放或无效，直接返回
      debugPrint('绘制图像时出错: $e');
      return;
    }
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is _ImagePainter && other.image == image;
  }

  @override
  int get hashCode => image.hashCode;
}
