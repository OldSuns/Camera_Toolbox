import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_config.dart';

/// 主题状态管理
class ThemeProvider with ChangeNotifier {
  ThemeConfig _config = ThemeConfig.defaultConfig();
  bool _isLoading = true;

  ThemeConfig get config => _config;
  bool get isLoading => _isLoading;

  /// 初始化主题配置
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeJson = prefs.getString('theme_config');

      if (themeJson != null) {
        final json = jsonDecode(themeJson);
        _config = ThemeConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('加载主题配置失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新主题配置
  Future<void> updateTheme(ThemeConfig newConfig) async {
    if (_config == newConfig) return;

    _config = newConfig;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_config', jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('保存主题配置失败: $e');
    }
  }

  /// 获取当前主题模式
  ThemeMode get themeMode {
    switch (_config.mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 获取浅色主题
  ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _config.seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  /// 获取深色主题
  ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _config.seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  /// 重置为默认主题
  Future<void> resetToDefault() async {
    await updateTheme(ThemeConfig.defaultConfig());
  }
}
