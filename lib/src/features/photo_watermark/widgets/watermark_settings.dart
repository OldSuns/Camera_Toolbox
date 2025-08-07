import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../photo_watermark_provider.dart';
import '../models/watermark_config.dart';

/// 水印设置面板
class WatermarkSettings extends StatelessWidget {
  const WatermarkSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Logo设置
            _buildSection(
              title: 'Logo设置',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('显示Logo'),
                    value: provider.config.logoEnabled,
                    onChanged: (_) => provider.toggleLogo(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (provider.config.logoEnabled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Logo位置:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LogoPositionButton(
                          position: LogoPosition.leftTextLeft,
                          label: '左侧文字左侧',
                          icon: Icons.format_align_left,
                          isSelected:
                              provider.config.logoPosition ==
                              LogoPosition.leftTextLeft,
                          onTap: () => provider.setLogoPosition(
                            LogoPosition.leftTextLeft,
                          ),
                        ),
                        _LogoPositionButton(
                          position: LogoPosition.leftTextRight,
                          label: '左侧文字右侧',
                          icon: Icons.format_align_center,
                          isSelected:
                              provider.config.logoPosition ==
                              LogoPosition.leftTextRight,
                          onTap: () => provider.setLogoPosition(
                            LogoPosition.leftTextRight,
                          ),
                        ),
                        _LogoPositionButton(
                          position: LogoPosition.rightTextLeft,
                          label: '右侧文字左侧',
                          icon: Icons.format_align_center,
                          isSelected:
                              provider.config.logoPosition ==
                              LogoPosition.rightTextLeft,
                          onTap: () => provider.setLogoPosition(
                            LogoPosition.rightTextLeft,
                          ),
                        ),
                        _LogoPositionButton(
                          position: LogoPosition.rightTextRight,
                          label: '右侧文字右侧',
                          icon: Icons.format_align_right,
                          isSelected:
                              provider.config.logoPosition ==
                              LogoPosition.rightTextRight,
                          onTap: () => provider.setLogoPosition(
                            LogoPosition.rightTextRight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 四角文字设置
            _buildSection(
              title: '文字内容',
              child: Column(
                children: [
                  _ElementSelector(
                    label: '左上角',
                    position: 'leftTop',
                    element: provider.config.leftTop,
                    provider: provider,
                  ),
                  const SizedBox(height: 12),
                  _ElementSelector(
                    label: '左下角',
                    position: 'leftBottom',
                    element: provider.config.leftBottom,
                    provider: provider,
                  ),
                  const SizedBox(height: 12),
                  _ElementSelector(
                    label: '右上角',
                    position: 'rightTop',
                    element: provider.config.rightTop,
                    provider: provider,
                  ),
                  const SizedBox(height: 12),
                  _ElementSelector(
                    label: '右下角',
                    position: 'rightBottom',
                    element: provider.config.rightBottom,
                    provider: provider,
                  ),
                ],
              ),
            ),

            // 全局设置
            _buildSection(
              title: '全局设置',
              child: Column(
                children: [
                  // 白边设置
                  SwitchListTile(
                    title: const Text('添加白边'),
                    value: provider.config.whiteMarginEnabled,
                    onChanged: (_) => provider.toggleWhiteMargin(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (provider.config.whiteMarginEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('边框宽度:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: provider.config.whiteMarginWidth,
                            min: 0.5,
                            max: 3.0,
                            divisions: 5, // 从0.5到3.0有5个分割点
                            label:
                                '${provider.config.whiteMarginWidth.toStringAsFixed(1)}%',
                            onChanged: (value) {
                              provider.updateWhiteMarginWidth(value);
                            },
                          ),
                        ),
                        Text(
                          '${provider.config.whiteMarginWidth.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ],

                  // 阴影设置
                  SwitchListTile(
                    title: const Text('添加阴影'),
                    value: provider.config.shadowEnabled,
                    onChanged: (_) => provider.toggleShadow(),
                    contentPadding: EdgeInsets.zero,
                  ),

                  // 等效焦距
                  SwitchListTile(
                    title: const Text('使用等效焦距'),
                    subtitle: const Text('35mm等效焦距'),
                    value: provider.config.useEquivalentFocalLength,
                    onChanged: (_) => provider.toggleEquivalentFocalLength(),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 12),

                  // 输出质量
                  Row(
                    children: [
                      const Text('输出质量:'),
                      const SizedBox(width: 8),
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
                      Text('${provider.config.outputQuality}%'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 元素选择器组件
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
        SizedBox(width: 60, child: Text(label)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<WatermarkElementType>(
            value: element.type,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              isDense: true,
            ),
            items: WatermarkElementType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (type) {
              if (type != null) {
                provider.updateElement(position, element.copyWith(type: type));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // 颜色选择器
        InkWell(
          onTap: () async {
            final color = await _showColorPicker(context, element.color);
            if (color != null) {
              provider.updateElement(position, element.copyWith(color: color));
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: element.color,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 粗体切换
        IconButton(
          icon: Icon(
            Icons.format_bold,
            color: element.isBold ? Colors.black : Colors.grey,
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
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择颜色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 预设颜色
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        Colors.black,
                        Colors.white,
                        Colors.grey,
                        const Color(0xFF212121),
                        const Color(0xFF757575),
                        const Color(0xFFD32F2F),
                        const Color(0xFFD4D1CC),
                        const Color(0xFF9E9E9E),
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                      ].map((color) {
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop(color);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(
                                color: Colors.grey,
                                width: color == Colors.white ? 1 : 0,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}

/// Logo位置按钮组件
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
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
