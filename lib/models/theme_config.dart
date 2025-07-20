import 'package:flutter/material.dart';

/// 主题模式枚举
enum AppThemeMode { light, dark, system }

extension AppThemeModeExtension on AppThemeMode {
  String get title {
    switch (this) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}

/// 主题配置数据模型
class ThemeConfig {
  final AppThemeMode mode;
  final Color seedColor;

  const ThemeConfig({required this.mode, required this.seedColor});

  /// 创建默认主题配置
  factory ThemeConfig.defaultConfig() {
    return const ThemeConfig(mode: AppThemeMode.system, seedColor: Colors.blue);
  }

  /// 从JSON创建主题配置
  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      mode: AppThemeMode.values[json['mode'] as int],
      seedColor: Color(json['seedColor'] as int),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'mode': mode.index, 'seedColor': seedColor.toARGB32()};
  }

  /// 复制并更新配置
  ThemeConfig copyWith({AppThemeMode? mode, Color? seedColor}) {
    return ThemeConfig(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}
