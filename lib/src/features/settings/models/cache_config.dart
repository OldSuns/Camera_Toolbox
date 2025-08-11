import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存自动清理策略
enum CacheAutoClearStrategy {
  never,
  daily,
  weekly,
  monthly,
  fileCountBased,
  sizeBased,
}

extension CacheAutoClearStrategyExtension on CacheAutoClearStrategy {
  String get title {
    switch (this) {
      case CacheAutoClearStrategy.never:
        return '永不清理';
      case CacheAutoClearStrategy.daily:
        return '每日清理';
      case CacheAutoClearStrategy.weekly:
        return '每周清理';
      case CacheAutoClearStrategy.monthly:
        return '每月清理';
      case CacheAutoClearStrategy.fileCountBased:
        return '文件数量限制';
      case CacheAutoClearStrategy.sizeBased:
        return '存储大小限制';
    }
  }

  String get description {
    switch (this) {
      case CacheAutoClearStrategy.never:
        return '手动清理缓存';
      case CacheAutoClearStrategy.daily:
        return '每天自动清理过期缓存';
      case CacheAutoClearStrategy.weekly:
        return '每周自动清理过期缓存';
      case CacheAutoClearStrategy.monthly:
        return '每月自动清理过期缓存';
      case CacheAutoClearStrategy.fileCountBased:
        return '当缓存文件数量超过限制时自动清理';
      case CacheAutoClearStrategy.sizeBased:
        return '当缓存大小超过限制时自动清理';
    }
  }
}

/// 缓存配置
class CacheConfig {
  final CacheAutoClearStrategy autoClearStrategy;
  final int maxFileCount;
  final int maxSizeMB;
  final bool enableMemoryCache;
  final int memoryMaxSize;
  final DateTime? lastCleanTime;

  const CacheConfig({
    required this.autoClearStrategy,
    required this.maxFileCount,
    required this.maxSizeMB,
    required this.enableMemoryCache,
    required this.memoryMaxSize,
    this.lastCleanTime,
  });

  /// 创建默认配置
  factory CacheConfig.defaultConfig() {
    return const CacheConfig(
      autoClearStrategy: CacheAutoClearStrategy.fileCountBased,
      maxFileCount: 300,
      maxSizeMB: 100,
      enableMemoryCache: true,
      memoryMaxSize: 50,
    );
  }

  /// 从JSON创建配置
  factory CacheConfig.fromJson(Map<String, dynamic> json) {
    return CacheConfig(
      autoClearStrategy:
          CacheAutoClearStrategy.values[json['autoClearStrategy'] as int],
      maxFileCount: json['maxFileCount'] as int,
      maxSizeMB: json['maxSizeMB'] as int,
      enableMemoryCache: json['enableMemoryCache'] as bool,
      memoryMaxSize: json['memoryMaxSize'] as int,
      lastCleanTime: json['lastCleanTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastCleanTime'] as int)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'autoClearStrategy': autoClearStrategy.index,
      'maxFileCount': maxFileCount,
      'maxSizeMB': maxSizeMB,
      'enableMemoryCache': enableMemoryCache,
      'memoryMaxSize': memoryMaxSize,
      'lastCleanTime': lastCleanTime?.millisecondsSinceEpoch,
    };
  }

  /// 复制并更新配置
  CacheConfig copyWith({
    CacheAutoClearStrategy? autoClearStrategy,
    int? maxFileCount,
    int? maxSizeMB,
    bool? enableMemoryCache,
    int? memoryMaxSize,
    DateTime? lastCleanTime,
  }) {
    return CacheConfig(
      autoClearStrategy: autoClearStrategy ?? this.autoClearStrategy,
      maxFileCount: maxFileCount ?? this.maxFileCount,
      maxSizeMB: maxSizeMB ?? this.maxSizeMB,
      enableMemoryCache: enableMemoryCache ?? this.enableMemoryCache,
      memoryMaxSize: memoryMaxSize ?? this.memoryMaxSize,
      lastCleanTime: lastCleanTime ?? this.lastCleanTime,
    );
  }

  /// 保存到本地存储
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_config', jsonEncode(toJson()));
  }

  /// 从本地存储加载
  static Future<CacheConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configStr = prefs.getString('cache_config');
      if (configStr != null) {
        final configJson = jsonDecode(configStr) as Map<String, dynamic>;
        return CacheConfig.fromJson(configJson);
      }
    } catch (e) {
      // 如果加载失败，返回默认配置
    }
    return CacheConfig.defaultConfig();
  }
}
