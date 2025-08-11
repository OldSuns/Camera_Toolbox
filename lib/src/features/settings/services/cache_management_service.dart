import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/cache_config.dart';

/// 缓存统计信息
class CacheStats {
  final int totalFiles;
  final int totalSizeMB;
  final int memoryCacheSize;
  final double hitRate;
  final int diskReads;
  final DateTime? lastCleanTime;

  const CacheStats({
    required this.totalFiles,
    required this.totalSizeMB,
    required this.memoryCacheSize,
    required this.hitRate,
    required this.diskReads,
    this.lastCleanTime,
  });
}

/// 缓存管理服务
class CacheManagementService {
  static final CacheManagementService _instance =
      CacheManagementService._internal();
  factory CacheManagementService() => _instance;
  CacheManagementService._internal();

  CacheConfig _config = CacheConfig.defaultConfig();
  CacheConfig get config => _config;

  /// 初始化服务
  Future<void> initialize() async {
    _config = await CacheConfig.load();
    await _checkAndCleanIfNeeded();
  }

  /// 更新配置
  Future<void> updateConfig(CacheConfig newConfig) async {
    _config = newConfig;
    await _config.save();
    await _checkAndCleanIfNeeded();
  }

  /// 获取缓存统计信息
  Future<CacheStats> getCacheStats([
    Map<String, dynamic>? localPickerStats,
  ]) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return const CacheStats(
          totalFiles: 0,
          totalSizeMB: 0,
          memoryCacheSize: 0,
          hitRate: 0.0,
          diskReads: 0,
        );
      }

      // 计算磁盘缓存大小
      final files = await cacheDir.list().toList();
      int totalSize = 0;
      int fileCount = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }

      // 使用传入的 LocalPickerProvider 统计数据
      final memoryStats = localPickerStats ?? {};

      return CacheStats(
        totalFiles: fileCount,
        totalSizeMB: (totalSize / (1024 * 1024)).round(),
        memoryCacheSize: memoryStats['memoryCacheSize'] ?? 0,
        hitRate: (memoryStats['hitRate'] ?? 0.0).toDouble(),
        diskReads: memoryStats['diskReads'] ?? 0,
        lastCleanTime: _config.lastCleanTime,
      );
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return const CacheStats(
        totalFiles: 0,
        totalSizeMB: 0,
        memoryCacheSize: 0,
        hitRate: 0.0,
        diskReads: 0,
      );
    }
  }

  /// 手动清理缓存
  Future<bool> clearCache({
    bool clearMemory = true,
    bool clearDisk = true,
  }) async {
    try {
      if (clearDisk) {
        await _clearDiskCache();
      }

      if (clearMemory) {
        // 清理内存缓存需要通过 LocalPickerProvider 实例
        // 这里我们只能标记需要清理，实际清理由 provider 处理
      }

      // 更新最后清理时间
      final newConfig = _config.copyWith(lastCleanTime: DateTime.now());
      await updateConfig(newConfig);

      return true;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }

  /// 清理磁盘缓存
  Future<void> _clearDiskCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('Thumbnail cache cleared.');
      }
    } catch (e) {
      debugPrint('Error clearing thumbnail cache: $e');
    }
  }

  /// 根据配置检查并清理缓存（如果需要）
  Future<void> clearCacheIfNeeded() async {
    switch (_config.autoClearStrategy) {
      case CacheAutoClearStrategy.never:
        return;

      case CacheAutoClearStrategy.fileCountBased:
        await _clearCacheIfNeededByCount();
        break;

      case CacheAutoClearStrategy.sizeBased:
        await _clearCacheIfNeededBySize();
        break;

      case CacheAutoClearStrategy.daily:
      case CacheAutoClearStrategy.weekly:
      case CacheAutoClearStrategy.monthly:
        // 这些策略由定时检查处理
        break;
    }
  }

  /// 根据文件数量限制清理缓存
  Future<void> _clearCacheIfNeededByCount() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        final fileCount = files.whereType<File>().length;
        if (fileCount >= _config.maxFileCount) {
          await _clearDiskCache();
          debugPrint(
            'Cache file limit reached. Cleared $fileCount thumbnails.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking or clearing thumbnail cache by count: $e');
    }
  }

  /// 根据大小限制清理缓存
  Future<void> _clearCacheIfNeededBySize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        int totalSize = 0;

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            totalSize += stat.size;
          }
        }

        final totalSizeMB = totalSize / (1024 * 1024);
        if (totalSizeMB >= _config.maxSizeMB) {
          await _clearDiskCache();
          debugPrint(
            'Cache size limit reached. Cleared ${totalSizeMB.toStringAsFixed(1)}MB.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking or clearing thumbnail cache by size: $e');
    }
  }

  /// 检查是否需要自动清理
  Future<void> _checkAndCleanIfNeeded() async {
    switch (_config.autoClearStrategy) {
      case CacheAutoClearStrategy.never:
        return;

      case CacheAutoClearStrategy.daily:
        if (_shouldCleanByTime(Duration(days: 1))) {
          await clearCache();
        }
        break;

      case CacheAutoClearStrategy.weekly:
        if (_shouldCleanByTime(Duration(days: 7))) {
          await clearCache();
        }
        break;

      case CacheAutoClearStrategy.monthly:
        if (_shouldCleanByTime(Duration(days: 30))) {
          await clearCache();
        }
        break;

      case CacheAutoClearStrategy.fileCountBased:
        await _cleanIfFileCountExceeded();
        break;

      case CacheAutoClearStrategy.sizeBased:
        await _cleanIfSizeExceeded();
        break;
    }
  }

  /// 根据时间判断是否需要清理
  bool _shouldCleanByTime(Duration interval) {
    if (_config.lastCleanTime == null) return true;
    return DateTime.now().difference(_config.lastCleanTime!) > interval;
  }

  /// 如果文件数量超过限制则清理
  Future<void> _cleanIfFileCountExceeded() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final files = await cacheDir.list().toList();
      final fileCount = files.whereType<File>().length;

      if (fileCount > _config.maxFileCount) {
        await clearCache();
      }
    } catch (e) {
      debugPrint('Error checking file count: $e');
    }
  }

  /// 如果大小超过限制则清理
  Future<void> _cleanIfSizeExceeded() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final files = await cacheDir.list().toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      final totalSizeMB = totalSize / (1024 * 1024);
      if (totalSizeMB > _config.maxSizeMB) {
        await clearCache();
      }
    } catch (e) {
      debugPrint('Error checking cache size: $e');
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final cache = await getApplicationCacheDirectory();
    return Directory(p.join(cache.path, 'thumbnails'));
  }

  /// 清理旧文件（按最后访问时间）
  Future<void> cleanOldFiles({int keepRecentCount = 50}) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final files = await cacheDir
          .list()
          .where((f) => f is File)
          .cast<File>()
          .toList();
      if (files.length <= keepRecentCount) return;

      // 按修改时间排序，保留最新的文件
      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime); // 降序，最新的在前
      });

      // 删除旧文件
      final filesToDelete = files.skip(keepRecentCount);
      for (final file in filesToDelete) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Error deleting file ${file.path}: $e');
        }
      }

      // 更新最后清理时间
      final newConfig = _config.copyWith(lastCleanTime: DateTime.now());
      await updateConfig(newConfig);
    } catch (e) {
      debugPrint('Error cleaning old files: $e');
    }
  }

  /// 获取缓存使用建议
  String getCacheUsageRecommendation(CacheStats stats) {
    // 优先检查是否未使用缓存
    if (stats.memoryCacheSize == 0 && stats.hitRate == 0.0) {
      return '当前未使用缓存';
    } else if (stats.totalSizeMB > 200) {
      return '缓存较大，建议清理以释放存储空间';
    } else if (stats.totalFiles > 500) {
      return '缓存文件较多，建议设置自动清理';
    } else if (stats.hitRate >= 0.01 && stats.hitRate <= 0.3) {
      return '缓存命中率较低，可能需要调整策略';
    } else if (stats.totalSizeMB < 10) {
      return '缓存使用正常';
    } else {
      return '缓存运行良好';
    }
  }
}
