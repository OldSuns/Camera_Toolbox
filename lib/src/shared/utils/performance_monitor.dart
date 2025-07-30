import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 性能监控工具类
class PerformanceMonitor {
  // 单例模式
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // 性能指标
  int _thumbnailGenerationCount = 0;
  int _thumbnailGenerationTime = 0; // 毫秒
  int _diskReadCount = 0;
  int _diskWriteCount = 0;
  int _diskWriteBytes = 0;
  int _memoryCacheHitCount = 0;
  int _memoryCacheMissCount = 0;
  int _diskCacheHitCount = 0;
  int _diskCacheMissCount = 0;
  int _uiResponseTime = 0; // 毫秒
  int _uiResponseCount = 0;
  int _frameDropCount = 0;
  int _totalFrameCount = 0;

  // 时间戳记录
  final Map<String, DateTime> _timestamps = {};

  // 性能数据文件
  File? _performanceDataFile;

  /// 初始化性能监控
  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final performanceDir = Directory(p.join(directory.path, 'performance'));
      if (!await performanceDir.exists()) {
        await performanceDir.create(recursive: true);
      }
      _performanceDataFile = File(
        p.join(performanceDir.path, 'performance_data.csv'),
      );

      // 如果文件不存在，创建并写入表头
      if (!await _performanceDataFile!.exists()) {
        await _performanceDataFile!.writeAsString(
          'timestamp,metric,value\n',
          mode: FileMode.writeOnly,
        );
      }
    } catch (e) {
      debugPrint('PerformanceMonitor init error: $e');
    }
  }

  /// 记录时间戳
  void recordTimestamp(String name) {
    _timestamps[name] = DateTime.now();
  }

  /// 计算两个时间戳之间的时间差
  int calculateDuration(String startName, String endName) {
    final start = _timestamps[startName];
    final end = _timestamps[endName];
    if (start == null || end == null) return 0;
    return end.difference(start).inMilliseconds;
  }

  /// 记录缩略图生成
  void recordThumbnailGeneration(int count, int timeMs) {
    _thumbnailGenerationCount += count;
    _thumbnailGenerationTime += timeMs;
    _logPerformanceData('thumbnail_generation_time', timeMs);
  }

  /// 记录磁盘读取
  void recordDiskRead(int count) {
    _diskReadCount += count;
    _logPerformanceData('disk_read_count', count);
  }

  /// 记录磁盘写入
  void recordDiskWrite(int count, int bytes) {
    _diskWriteCount += count;
    _diskWriteBytes += bytes;
    _logPerformanceData('disk_write_count', count);
    _logPerformanceData('disk_write_bytes', bytes);
  }

  /// 记录内存缓存命中
  void recordMemoryCacheHit(int count) {
    _memoryCacheHitCount += count;
  }

  /// 记录内存缓存未命中
  void recordMemoryCacheMiss(int count) {
    _memoryCacheMissCount += count;
  }

  /// 记录磁盘缓存命中
  void recordDiskCacheHit(int count) {
    _diskCacheHitCount += count;
  }

  /// 记录磁盘缓存未命中
  void recordDiskCacheMiss(int count) {
    _diskCacheMissCount += count;
  }

  /// 记录UI响应时间
  void recordUIResponseTime(int timeMs) {
    _uiResponseTime += timeMs;
    _uiResponseCount++;
    _logPerformanceData('ui_response_time', timeMs);
  }

  /// 记录帧率信息
  void recordFrameInfo(int totalFrames, int droppedFrames) {
    _totalFrameCount += totalFrames;
    _frameDropCount += droppedFrames;
  }

  /// 获取缩略图生成统计
  Map<String, dynamic> getThumbnailGenerationStats() {
    return {
      'count': _thumbnailGenerationCount,
      'totalTimeMs': _thumbnailGenerationTime,
      'averageTimeMs': _thumbnailGenerationCount > 0
          ? (_thumbnailGenerationTime / _thumbnailGenerationCount).round()
          : 0,
    };
  }

  /// 获取磁盘I/O统计
  Map<String, dynamic> getDiskIOStats() {
    return {
      'readCount': _diskReadCount,
      'writeCount': _diskWriteCount,
      'writeBytes': _diskWriteBytes,
      'totalOperations': _diskReadCount + _diskWriteCount,
    };
  }

  /// 获取缓存命中率统计
  Map<String, dynamic> getCacheHitStats() {
    final totalMemoryAccess = _memoryCacheHitCount + _memoryCacheMissCount;
    final totalDiskAccess = _diskCacheHitCount + _diskCacheMissCount;
    final totalAccess = totalMemoryAccess + totalDiskAccess;

    final memoryHitRate = totalMemoryAccess > 0
        ? _memoryCacheHitCount / totalMemoryAccess
        : 0.0;

    final diskHitRate = totalDiskAccess > 0
        ? _diskCacheHitCount / totalDiskAccess
        : 0.0;

    final overallHitRate = totalAccess > 0
        ? (_memoryCacheHitCount + _diskCacheHitCount) / totalAccess
        : 0.0;

    return {
      'memoryHitCount': _memoryCacheHitCount,
      'memoryMissCount': _memoryCacheMissCount,
      'memoryHitRate': memoryHitRate,
      'diskHitCount': _diskCacheHitCount,
      'diskMissCount': _diskCacheMissCount,
      'diskHitRate': diskHitRate,
      'overallHitCount': _memoryCacheHitCount + _diskCacheHitCount,
      'overallMissCount': _memoryCacheMissCount + _diskCacheMissCount,
      'overallHitRate': overallHitRate,
    };
  }

  /// 获取UI响应统计
  Map<String, dynamic> getUIResponseStats() {
    return {
      'totalTimeMs': _uiResponseTime,
      'count': _uiResponseCount,
      'averageTimeMs': _uiResponseCount > 0
          ? (_uiResponseTime / _uiResponseCount).round()
          : 0,
    };
  }

  /// 获取帧率统计
  Map<String, dynamic> getFrameStats() {
    final frameRate = _totalFrameCount > 0
        ? (_totalFrameCount - _frameDropCount) / _totalFrameCount
        : 0.0;

    return {
      'totalFrames': _totalFrameCount,
      'droppedFrames': _frameDropCount,
      'frameRate': frameRate,
    };
  }

  /// 获取所有性能统计
  Map<String, dynamic> getAllStats() {
    return {
      'thumbnailGeneration': getThumbnailGenerationStats(),
      'diskIO': getDiskIOStats(),
      'cacheHit': getCacheHitStats(),
      'uiResponse': getUIResponseStats(),
      'frame': getFrameStats(),
    };
  }

  /// 重置所有统计
  void resetStats() {
    _thumbnailGenerationCount = 0;
    _thumbnailGenerationTime = 0;
    _diskReadCount = 0;
    _diskWriteCount = 0;
    _diskWriteBytes = 0;
    _memoryCacheHitCount = 0;
    _memoryCacheMissCount = 0;
    _diskCacheHitCount = 0;
    _diskCacheMissCount = 0;
    _uiResponseTime = 0;
    _uiResponseCount = 0;
    _frameDropCount = 0;
    _totalFrameCount = 0;
    _timestamps.clear();
  }

  /// 记录性能数据到文件
  Future<void> _logPerformanceData(String metric, int value) async {
    if (_performanceDataFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final line = '$timestamp,$metric,$value\n';
      await _performanceDataFile!.writeAsString(line, mode: FileMode.append);
    } catch (e) {
      debugPrint('Error logging performance data: $e');
    }
  }

  /// 生成性能报告
  Future<String> generateReport() async {
    final stats = getAllStats();
    final buffer = StringBuffer();

    buffer.writeln('=== 性能监控报告 ===');
    buffer.writeln('生成时间: ${DateTime.now()}');
    buffer.writeln();

    // 缩略图生成统计
    final thumbnailStats = stats['thumbnailGeneration'] as Map<String, dynamic>;
    buffer.writeln('--- 缩略图生成统计 ---');
    buffer.writeln('生成数量: ${thumbnailStats['count']}');
    buffer.writeln('总耗时: ${thumbnailStats['totalTimeMs']} ms');
    buffer.writeln('平均耗时: ${thumbnailStats['averageTimeMs']} ms');
    buffer.writeln();

    // 磁盘I/O统计
    final diskStats = stats['diskIO'] as Map<String, dynamic>;
    buffer.writeln('--- 磁盘I/O统计 ---');
    buffer.writeln('读取次数: ${diskStats['readCount']}');
    buffer.writeln('写入次数: ${diskStats['writeCount']}');
    buffer.writeln('写入字节数: ${diskStats['writeBytes']} bytes');
    buffer.writeln('总操作次数: ${diskStats['totalOperations']}');
    buffer.writeln();

    // 缓存命中率统计
    final cacheStats = stats['cacheHit'] as Map<String, dynamic>;
    buffer.writeln('--- 缓存命中率统计 ---');
    buffer.writeln('内存缓存命中次数: ${cacheStats['memoryHitCount']}');
    buffer.writeln('内存缓存未命中次数: ${cacheStats['memoryMissCount']}');
    buffer.writeln(
      '内存缓存命中率: ${(cacheStats['memoryHitRate'] * 100).toStringAsFixed(2)}%',
    );
    buffer.writeln('磁盘缓存命中次数: ${cacheStats['diskHitCount']}');
    buffer.writeln('磁盘缓存未命中次数: ${cacheStats['diskMissCount']}');
    buffer.writeln(
      '磁盘缓存命中率: ${(cacheStats['diskHitRate'] * 100).toStringAsFixed(2)}%',
    );
    buffer.writeln('总体缓存命中次数: ${cacheStats['overallHitCount']}');
    buffer.writeln('总体缓存未命中次数: ${cacheStats['overallMissCount']}');
    buffer.writeln(
      '总体缓存命中率: ${(cacheStats['overallHitRate'] * 100).toStringAsFixed(2)}%',
    );
    buffer.writeln();

    // UI响应统计
    final uiStats = stats['uiResponse'] as Map<String, dynamic>;
    buffer.writeln('--- UI响应统计 ---');
    buffer.writeln('响应次数: ${uiStats['count']}');
    buffer.writeln('总响应时间: ${uiStats['totalTimeMs']} ms');
    buffer.writeln('平均响应时间: ${uiStats['averageTimeMs']} ms');
    buffer.writeln();

    // 帧率统计
    final frameStats = stats['frame'] as Map<String, dynamic>;
    buffer.writeln('--- 帧率统计 ---');
    buffer.writeln('总帧数: ${frameStats['totalFrames']}');
    buffer.writeln('丢帧数: ${frameStats['droppedFrames']}');
    buffer.writeln(
      '帧率: ${(frameStats['frameRate'] * 100).toStringAsFixed(2)}%',
    );

    return buffer.toString();
  }

  /// 保存性能报告到文件
  Future<void> saveReportToFile() async {
    try {
      final report = await generateReport();
      final directory = await getApplicationDocumentsDirectory();
      final reportFile = File(p.join(directory.path, 'performance_report.txt'));
      await reportFile.writeAsString(report);
      debugPrint('Performance report saved to: ${reportFile.path}');
    } catch (e) {
      debugPrint('Error saving performance report: $e');
    }
  }
}

/// 性能计时器辅助类
class PerformanceTimer {
  final String _name;
  final PerformanceMonitor _monitor;
  final DateTime _startTime;

  PerformanceTimer(this._name, this._monitor) : _startTime = DateTime.now();

  /// 停止计时并记录结果
  void stop() {
    final duration = DateTime.now().difference(_startTime).inMilliseconds;
    switch (_name) {
      case 'thumbnail_generation':
        _monitor.recordThumbnailGeneration(1, duration);
        break;
      case 'ui_response':
        _monitor.recordUIResponseTime(duration);
        break;
    }
  }
}

/// 帧率监控辅助类
class FrameRateMonitor {
  int _frameCount = 0;
  int _dropFrameCount = 0;
  DateTime _lastTime = DateTime.now();
  final PerformanceMonitor _monitor;

  FrameRateMonitor(this._monitor);

  /// 记录帧
  void recordFrame() {
    _frameCount++;
    _checkFrameRate();
  }

  /// 记录丢帧
  void recordDroppedFrame() {
    _dropFrameCount++;
    _checkFrameRate();
  }

  /// 检查并记录帧率
  void _checkFrameRate() {
    final now = DateTime.now();
    final duration = now.difference(_lastTime);
    if (duration.inSeconds >= 1) {
      _monitor.recordFrameInfo(_frameCount, _dropFrameCount);
      _frameCount = 0;
      _dropFrameCount = 0;
      _lastTime = now;
    }
  }
}
