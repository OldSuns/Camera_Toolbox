import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../photo_watermark_provider.dart';
import '../models/watermark_config.dart';
import '../design_tokens.dart';

/// 水印设置面板 - 优化版
class WatermarkSettings extends StatelessWidget {
  const WatermarkSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          children: [
            // 布局类型选择
            _buildLayoutTypeSection(context, provider),
            const SizedBox(height: DesignTokens.spacing16),

            // Logo设置
            _buildLogoSection(context, provider),
            const SizedBox(height: DesignTokens.spacing16),

            // 四角文字设置
            _buildTextContentSection(context, provider),
            const SizedBox(height: DesignTokens.spacing16),

            // 全局设置
            _buildGlobalSettingsSection(context, provider),
          ],
        );
      },
    );
  }

  /// 构建布局类型选择区域
  Widget _buildLayoutTypeSection(
    BuildContext context,
    PhotoWatermarkProvider provider,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        side: BorderSide(color: DesignTokens.borderColorLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('布局类型', style: DesignTokens.headingSmall),
            const SizedBox(height: DesignTokens.spacing12),
            DropdownButtonFormField<WatermarkLayoutType>(
              value: provider.config.layoutType,
              decoration: DesignTokens.inputDecoration(
                labelText: '选择布局',
                hintText: '选择水印布局类型',
              ),
              items: WatermarkLayoutType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName, style: DesignTokens.bodyMedium),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  provider.updateConfig(
                    provider.config.copyWith(layoutType: type),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建Logo设置区域
  Widget _buildLogoSection(
    BuildContext context,
    PhotoWatermarkProvider provider,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        side: BorderSide(color: DesignTokens.borderColorLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Logo设置', style: DesignTokens.headingSmall),
                Switch(
                  value: provider.config.logoEnabled,
                  onChanged: (_) => provider.toggleLogo(),
                ),
              ],
            ),
            if (provider.config.logoEnabled) ...[
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                'Logo位置',
                style: DesignTokens.labelMedium.copyWith(
                  color: DesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Wrap(
                spacing: DesignTokens.spacing8,
                runSpacing: DesignTokens.spacing8,
                children: [
                  _LogoPositionButton(
                    position: LogoPosition.leftTextLeft,
                    label: '左侧文字左侧',
                    icon: Icons.format_align_left,
                    isSelected:
                        provider.config.logoPosition ==
                        LogoPosition.leftTextLeft,
                    onTap: () =>
                        provider.setLogoPosition(LogoPosition.leftTextLeft),
                  ),
                  _LogoPositionButton(
                    position: LogoPosition.leftTextRight,
                    label: '左侧文字右侧',
                    icon: Icons.format_align_center,
                    isSelected:
                        provider.config.logoPosition ==
                        LogoPosition.leftTextRight,
                    onTap: () =>
                        provider.setLogoPosition(LogoPosition.leftTextRight),
                  ),
                  _LogoPositionButton(
                    position: LogoPosition.rightTextLeft,
                    label: '右侧文字左侧',
                    icon: Icons.format_align_center,
                    isSelected:
                        provider.config.logoPosition ==
                        LogoPosition.rightTextLeft,
                    onTap: () =>
                        provider.setLogoPosition(LogoPosition.rightTextLeft),
                  ),
                  _LogoPositionButton(
                    position: LogoPosition.rightTextRight,
                    label: '右侧文字右侧',
                    icon: Icons.format_align_right,
                    isSelected:
                        provider.config.logoPosition ==
                        LogoPosition.rightTextRight,
                    onTap: () =>
                        provider.setLogoPosition(LogoPosition.rightTextRight),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建文字内容设置区域
  Widget _buildTextContentSection(
    BuildContext context,
    PhotoWatermarkProvider provider,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        side: BorderSide(color: DesignTokens.borderColorLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文字内容', style: DesignTokens.headingSmall),
            const SizedBox(height: DesignTokens.spacing16),
            _ElementSelector(
              label: '左上角',
              position: 'leftTop',
              element: provider.config.leftTop,
              provider: provider,
            ),
            const SizedBox(height: DesignTokens.spacing12),
            _ElementSelector(
              label: '左下角',
              position: 'leftBottom',
              element: provider.config.leftBottom,
              provider: provider,
            ),
            const SizedBox(height: DesignTokens.spacing12),
            _ElementSelector(
              label: '右上角',
              position: 'rightTop',
              element: provider.config.rightTop,
              provider: provider,
            ),
            const SizedBox(height: DesignTokens.spacing12),
            _ElementSelector(
              label: '右下角',
              position: 'rightBottom',
              element: provider.config.rightBottom,
              provider: provider,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建全局设置区域
  Widget _buildGlobalSettingsSection(
    BuildContext context,
    PhotoWatermarkProvider provider,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        side: BorderSide(color: DesignTokens.borderColorLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全局设置', style: DesignTokens.headingSmall),
            const SizedBox(height: DesignTokens.spacing16),

            // 白边设置
            _buildSettingItem(
              title: '添加白边',
              trailing: Switch(
                value: provider.config.whiteMarginEnabled,
                onChanged: (_) => provider.toggleWhiteMargin(),
              ),
            ),
            if (provider.config.whiteMarginEnabled) ...[
              const SizedBox(height: DesignTokens.spacing12),
              Row(
                children: [
                  Text(
                    '边框宽度',
                    style: DesignTokens.bodyMedium.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: Slider(
                      value: provider.config.whiteMarginWidth,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      label:
                          '${provider.config.whiteMarginWidth.toStringAsFixed(1)}%',
                      onChanged: (value) {
                        provider.updateWhiteMarginWidth(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${provider.config.whiteMarginWidth.toStringAsFixed(1)}%',
                      style: DesignTokens.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: DesignTokens.spacing12),

            // 阴影设置
            _buildSettingItem(
              title: '添加阴影',
              trailing: Switch(
                value: provider.config.shadowEnabled,
                onChanged: (_) => provider.toggleShadow(),
              ),
            ),

            const SizedBox(height: DesignTokens.spacing12),

            // 背景模糊+白框 模糊背景边框大小调节
            if (provider.config.layoutType ==
                WatermarkLayoutType.backgroundBlurWithBorder) ...[
              Row(
                children: [
                  Text(
                    '背景边框大小',
                    style: DesignTokens.bodyMedium.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: Slider(
                      value:
                          (provider.config.extraSettings.containsKey(
                                    'backgroundBlurPaddingPercent',
                                  )
                                  ? provider
                                        .config
                                        .extraSettings['backgroundBlurPaddingPercent']
                                  : 0.18)
                              as double,
                      min: 0.05,
                      max: 0.3,
                      divisions: 15,
                      label:
                          '${(((provider.config.extraSettings['backgroundBlurPaddingPercent'] ?? 0.18) as double) * 100).toStringAsFixed(0)}%',
                      onChanged: (value) {
                        provider.updateBackgroundBlurPaddingPercent(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(((provider.config.extraSettings['backgroundBlurPaddingPercent'] ?? 0.18) as double) * 100).toStringAsFixed(0)}%',
                      style: DesignTokens.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),
            ],

            // 等效焦距
            _buildSettingItem(
              title: '使用等效焦距',
              subtitle: '35mm等效焦距',
              trailing: Switch(
                value: provider.config.useEquivalentFocalLength,
                onChanged: (_) => provider.toggleEquivalentFocalLength(),
              ),
            ),

            const SizedBox(height: DesignTokens.spacing16),

            // 输出质量
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输出质量',
                  style: DesignTokens.bodyMedium.copyWith(
                    color: DesignTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: provider.config.outputQuality.toDouble(),
                        min: 50,
                        max: 100,
                        divisions: 50,
                        label: '${provider.config.outputQuality}',
                        onChanged: (value) {
                          provider.updateOutputQuality(value.toInt());
                        },
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${provider.config.outputQuality}%',
                        style: DesignTokens.bodySmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设置项
  Widget _buildSettingItem({
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DesignTokens.bodyMedium),
              if (subtitle != null) ...[
                const SizedBox(height: DesignTokens.spacing4),
                Text(
                  subtitle,
                  style: DesignTokens.bodySmall.copyWith(
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

/// 元素选择器组件 - 优化版
class _ElementSelector extends StatelessWidget {
  final String label;
  final String position;
  final ElementConfig element;
  final PhotoWatermarkProvider provider;

  const _ElementSelector({
    required this.label,
    required this.position,
    required this.element,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: DesignTokens.bodyMedium.copyWith(
              color: DesignTokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        Expanded(
          child: SizedBox(
            height: DesignTokens.inputHeight,
            child: DropdownButtonFormField<WatermarkElementType>(
              value: element.type,
              decoration: DesignTokens.inputDecoration(),
              style: DesignTokens.bodyMedium.copyWith(
                color: DesignTokens.textPrimary,
              ),
              items: WatermarkElementType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName, style: DesignTokens.bodySmall),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  provider.updateElement(
                    position,
                    element.copyWith(type: type),
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        // 颜色选择器
        InkWell(
          onTap: () async {
            final color = await _showColorPicker(context, element.color);
            if (color != null) {
              provider.updateElement(position, element.copyWith(color: color));
            }
          },
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: element.color,
              border: Border.all(color: DesignTokens.borderColor),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        // 粗体切换
        IconButton(
          icon: Icon(
            Icons.format_bold,
            color: element.isBold
                ? DesignTokens.textPrimary
                : DesignTokens.textTertiary,
            size: 20,
          ),
          onPressed: () {
            provider.updateElement(
              position,
              element.copyWith(isBold: !element.isBold),
            );
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Future<Color?> _showColorPicker(
    BuildContext context,
    Color initialColor,
  ) async {
    Color pickedColor = initialColor;
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择颜色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: initialColor,
              onColorChanged: (color) {
                pickedColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: true,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop(pickedColor);
              },
            ),
          ],
        );
      },
    );
  }
}

/// Logo位置按钮组件 - 优化版
class _LogoPositionButton extends StatelessWidget {
  final LogoPosition position;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LogoPositionButton({
    required this.position,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: AnimatedContainer(
        duration: DesignTokens.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing12,
          vertical: DesignTokens.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : DesignTokens.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : DesignTokens.textSecondary,
            ),
            const SizedBox(height: DesignTokens.spacing4),
            Text(
              label,
              style: DesignTokens.labelSmall.copyWith(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : DesignTokens.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
