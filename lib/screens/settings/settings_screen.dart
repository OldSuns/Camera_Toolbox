import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_config.dart';
import '../../providers/theme_provider.dart';
import 'theme_settings_dialog.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题设置'),
            subtitle: Text(_getThemeDescription(themeProvider.config)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ThemeSettingsDialog(),
              );
            },
          ),
          // 已删除：语言设置、隐私设置、帮助与反馈选项
        ],
      ),
    );
  }

  String _getThemeDescription(ThemeConfig config) {
    final modeText = config.mode.title;
    final colorName = _getColorName(config.seedColor);
    return '$modeText · $colorName';
  }

  String _getColorName(Color color) {
    if (color == Colors.blue) return '蓝色';
    if (color == Colors.red) return '红色';
    if (color == Colors.green) return '绿色';
    if (color == Colors.orange) return '橙色';
    if (color == Colors.purple) return '紫色';
    if (color == Colors.pink) return '粉色';
    if (color == Colors.teal) return '青色';
    if (color == Colors.indigo) return '靛蓝';
    if (color == Colors.brown) return '棕色';
    if (color == Colors.cyan) return '青色';
    return '自定义';
  }
}
