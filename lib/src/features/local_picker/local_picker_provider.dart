import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Data class for thumbnail generation request
class _ThumbnailRequest {
  final String path;
  final int width;
  final String cachePath;
  _ThumbnailRequest(this.path, this.width, this.cachePath);
}

/// Data class for thumbnail generation result
class _ThumbnailResult {
  final String path;
  final Uint8List bytes;
  final String cacheKey;
  _ThumbnailResult(this.path, this.bytes, this.cacheKey);
}

/// 批量缩略图生成请求
class _BatchThumbnailRequest {
  final List<_ThumbnailRequest> requests;
  _BatchThumbnailRequest(this.requests);
}

/// The entry point for the isolate.
void _thumbnailGenerator(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is _ThumbnailRequest) {
      await _processSingleThumbnail(message, sendPort);
    } else if (message is _BatchThumbnailRequest) {
      // 批量处理缩略图，减少Isolate通信开销
      for (final request in message.requests) {
        await _processSingleThumbnail(request, sendPort);
      }
    }
  });
}

/// 处理单个缩略图生成
Future<void> _processSingleThumbnail(
  _ThumbnailRequest message,
  SendPort sendPort,
) async {
  try {
    final fileBytes = await File(message.path).readAsBytes();
    final image = img.decodeImage(fileBytes);
    if (image != null) {
      // 使用线性插值算法，平衡质量和速度
      final thumbnail = img.copyResize(
        image,
        width: message.width,
        interpolation: img.Interpolation.linear,
      );

      // 保持80%质量
      final jpgBytes = Uint8List.fromList(
        img.encodeJpg(thumbnail, quality: 80),
      );

      // 异步写入磁盘，不阻塞处理
      final cacheFile = File(message.cachePath);
      unawaited(cacheFile.writeAsBytes(jpgBytes));
      final cacheKey = p.basename(cacheFile.path);
      sendPort.send(_ThumbnailResult(message.path, jpgBytes, cacheKey));
    }
  } catch (e) {
    debugPrint('Error in isolate for ${message.path}: $e');
    sendPort.send(_ThumbnailResult(message.path, Uint8List(0), ''));
  }
}

/// 不等待异步操作完成的辅助函数
void unawaited(Future<void> future) {
  // 故意不等待，让操作在后台进行
}

class LocalPickerProvider with ChangeNotifier {
  final List<String> _imagePaths = [];
  List<String> get imagePaths => _imagePaths;
  String? _currentDirectory;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  final int _pageSize = 100;

  Map<String, Uint8List> get thumbnailCache => _thumbnailCache;
  final Map<String, Uint8List> _thumbnailCache = {};
  Directory? _cacheDir;
  final Set<String> _diskCacheIndex = {};
  int _cacheHitCount = 0;
  int _cacheMissCount = 0;
  int _diskReadCount = 0;

  final Set<String> _selectedImagePaths = {};
  Set<String> get selectedImagePaths => _selectedImagePaths;
  int _totalImageCount = 0;
  int get totalImageCount => _totalImageCount;

  final Map<String, bool> _rawFileStatus = {};
  Map<String, bool> get rawFileStatus => _rawFileStatus;

  double _thumbnailSize = 150.0;
  double get thumbnailSize => _thumbnailSize;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _currentImageIndex = 0;
  int get currentImageIndex => _currentImageIndex;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  double _exportProgress = 0.0;
  double get exportProgress => _exportProgress;

  // 多Isolate池优化 - 根据CPU核心数动态调整
  final List<Isolate?> _isolates = [];
  final List<SendPort?> _sendPorts = [];
  final List<ReceivePort> _receivePorts = [];
  final List<Completer<SendPort>> _sendPortCompleters = [];

  int _processingCount = 0;
  late final int _maxConcurrent; // 根据CPU核心数动态设置
  late final int _isolateCount; // 根据CPU核心数动态设置
  final List<_ThumbnailRequest> _requestQueue = [];
  final Set<String> _pendingGeneration = {};
  int _currentIsolateIndex = 0; // 轮询使用Isolate

  // 批量处理优化
  final int _batchSize = 3; // 减少批量大小，提高响应性
  Timer? _batchTimer;

  // 延迟初始化标志位
  bool _isolatesInitialized = false;

  LocalPickerProvider() {
    _initCpuBasedSettings();
    _initCacheDir();
  }

  /// 根据CPU核心数初始化设置
  void _initCpuBasedSettings() {
    final cpuCores = Platform.numberOfProcessors;

    // Isolate数量 = CPU核心数 / 2，最少1个，最多6个
    _isolateCount = (cpuCores / 2).ceil().clamp(1, 6);

    // 最大并发数 = CPU核心数 - 1，最少2个，最多12个
    _maxConcurrent = (cpuCores - 1).clamp(2, 12);

    debugPrint(
      'CPU核心数: $cpuCores, Isolate数量: $_isolateCount, 最大并发数: $_maxConcurrent',
    );
  }

  Future<void> _initCacheDir() async {
    final cache = await getApplicationCacheDirectory();
    _cacheDir = Directory(p.join(cache.path, 'thumbnails'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    } else {
      // Pre-populate the disk cache index
      final files = _cacheDir!.list();
      await for (final file in files) {
        if (file is File) {
          _diskCacheIndex.add(p.basename(file.path));
        }
      }
    }
  }

  File _getCacheFileForPath(String path) {
    final hash = md5.convert(utf8.encode(path)).toString();
    return File(p.join(_cacheDir!.path, '$hash.jpg'));
  }

  String _getCacheKeyForPath(String path) {
    return '${md5.convert(utf8.encode(path)).toString()}.jpg';
  }

  /// 确保Isolate已初始化（延迟初始化）
  Future<void> ensureIsolatesInitialized() async {
    if (_isolatesInitialized) return;
    await _initIsolates();
    _isolatesInitialized = true;
  }

  /// 初始化多个Isolate
  Future<void> _initIsolates() async {
    for (int i = 0; i < _isolateCount; i++) {
      final receivePort = ReceivePort();
      final completer = Completer<SendPort>();

      _receivePorts.add(receivePort);
      _sendPortCompleters.add(completer);
      _isolates.add(null);
      _sendPorts.add(null);

      final isolate = await Isolate.spawn(
        _thumbnailGenerator,
        receivePort.sendPort,
      );
      _isolates[i] = isolate;

      receivePort.listen((dynamic message) {
        if (message is SendPort) {
          _sendPorts[i] = message;
          if (!_sendPortCompleters[i].isCompleted) {
            _sendPortCompleters[i].complete(message);
          }
        } else if (message is _ThumbnailResult) {
          _processingCount--;
          _pendingGeneration.remove(message.path);

          if (message.bytes.isNotEmpty) {
            _thumbnailCache[message.path] = message.bytes;
            if (message.cacheKey.isNotEmpty) {
              _diskCacheIndex.add(message.cacheKey);
            }
          }
          _processNextRequest();
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    for (final isolate in _isolates) {
      isolate?.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
    super.dispose();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setCurrentImageIndex(int index) {
    _currentImageIndex = index;
    checkRawFileForCurrentImage();
    notifyListeners();
  }

  void nextImage() {
    if (_currentImageIndex < _imagePaths.length - 1) {
      _currentImageIndex++;
      checkRawFileForCurrentImage();
      notifyListeners();
    }
  }

  void previousImage() {
    if (_currentImageIndex > 0) {
      _currentImageIndex--;
      checkRawFileForCurrentImage();
      notifyListeners();
    }
  }

  void precacheAdjacentImages(
    BuildContext context, {
    bool isScrolling = false,
  }) {
    if (_imagePaths.isEmpty) return;

    final precacheCount = isScrolling ? 3 : 6;

    for (int i = 1; i <= precacheCount; i++) {
      final nextIndex = _currentImageIndex + i;
      if (nextIndex < _imagePaths.length) {
        precacheImage(
          FileImage(File(_imagePaths[nextIndex])),
          context,
          onError: (exception, stackTrace) {
            debugPrint(
              'Failed to precache image at index $nextIndex: $exception',
            );
          },
        );
      }
    }
  }

  Future<void> selectFolder() async {
    setLoading(true);

    // 立即清理状态，不等待Isolate操作
    _imagePaths.clear();
    _selectedImagePaths.clear();
    _thumbnailCache.clear();
    _currentDirectory = null;
    _hasMore = true;
    _totalImageCount = 0;
    notifyListeners();

    // 后台异步重置和初始化Isolate，不阻塞UI
    unawaited(_resetIsolatesAsync());

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        _currentDirectory = selectedDirectory;
        _calculateTotalImageCount();
        await _loadMoreImages();
      }
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    } finally {
      setLoading(false);
    }
  }

  /// 异步重置Isolate，不阻塞UI
  Future<void> _resetIsolatesAsync() async {
    for (final isolate in _isolates) {
      isolate?.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
    _sendPorts.clear();
    _receivePorts.clear();
    _sendPortCompleters.clear();
    _isolatesInitialized = false;
    // 在后台异步初始化，不阻塞UI - 使用unawaited
    unawaited(ensureIsolatesInitialized());
  }

  Future<void> loadMoreImages() async {
    if (isLoading || !_hasMore || _currentDirectory == null) return;
    setLoading(true);
    try {
      await _loadMoreImages();
    } finally {
      setLoading(false);
    }
  }

  Future<void> _loadMoreImages() async {
    if (_currentDirectory == null) return;
    try {
      final dir = Directory(_currentDirectory!);
      final files = await dir
          .list()
          .where((entity) {
            if (entity is! File) return false;
            final extension = p.extension(entity.path).toLowerCase();
            return ['.jpg', '.jpeg', '.png', '.heic'].contains(extension);
          })
          .skip(_imagePaths.length)
          .take(_pageSize)
          .map((entity) => entity.path)
          .toList();

      if (files.length < _pageSize) {
        _hasMore = false;
      }

      _imagePaths.addAll(files);
      await _regenerateThumbnails();
      _prewarmCache(files);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading more images: $e');
      _hasMore = false;
      notifyListeners();
    }
  }

  void toggleSelection(String imagePath) {
    if (_selectedImagePaths.contains(imagePath)) {
      _selectedImagePaths.remove(imagePath);
    } else {
      _selectedImagePaths.add(imagePath);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedImagePaths.addAll(_imagePaths);
    notifyListeners();
  }

  void deselectAll() {
    _selectedImagePaths.clear();
    notifyListeners();
  }

  Future<Uint8List?> getThumbnail(String path) async {
    // 1. Check memory cache
    if (_thumbnailCache.containsKey(path)) {
      _cacheHitCount++;
      return _thumbnailCache[path];
    }

    // 2. Check if currently being generated
    if (_pendingGeneration.contains(path)) {
      return null;
    }

    // 3. Check disk cache index (no I/O)
    final cacheKey = _getCacheKeyForPath(path);
    if (!_diskCacheIndex.contains(cacheKey)) {
      _cacheMissCount++;
      _queueThumbnailGeneration(path);
      return null;
    }

    // 4. 异步读取磁盘缓存
    _loadFromDiskCache(path);
    return null;
  }

  /// 异步加载磁盘缓存
  Future<void> _loadFromDiskCache(String path) async {
    final cacheFile = _getCacheFileForPath(path);
    _diskReadCount++;
    try {
      final bytes = await cacheFile.readAsBytes();
      if (bytes.isEmpty) {
        final cacheKey = _getCacheKeyForPath(path);
        _diskCacheIndex.remove(cacheKey);
        await cacheFile.delete();
        _cacheMissCount++;
        return;
      }
      _thumbnailCache[path] = bytes;
      _cacheHitCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reading cache file for $path: $e. Deleting.');
      final cacheKey = _getCacheKeyForPath(path);
      _diskCacheIndex.remove(cacheKey);
      await cacheFile.delete();
      _cacheMissCount++;
    }
  }

  /// 队列缩略图生成请求
  void _queueThumbnailGeneration(String path) {
    if (_pendingGeneration.contains(path)) return;

    final cacheFile = _getCacheFileForPath(path);
    final request = _ThumbnailRequest(path, 300, cacheFile.path);
    _requestQueue.add(request);
    _processNextRequest();
  }

  Future<void> _prewarmCache(List<String> pathsToPrewarm) async {
    for (final path in pathsToPrewarm) {
      if (!_thumbnailCache.containsKey(path)) {
        final cacheKey = _getCacheKeyForPath(path);
        if (_diskCacheIndex.contains(cacheKey)) {
          final cacheFile = _getCacheFileForPath(path);
          try {
            final bytes = await cacheFile.readAsBytes();
            if (bytes.isNotEmpty) {
              _thumbnailCache[path] = bytes;
            }
          } catch (e) {
            // Ignore errors
          }
        }
      }
      await Future.delayed(Duration.zero);
    }
  }

  void invertSelection() {
    final allImagePaths = _imagePaths.toSet();
    final currentSelection = _selectedImagePaths.toSet();
    _selectedImagePaths.clear();
    _selectedImagePaths.addAll(allImagePaths.difference(currentSelection));
    notifyListeners();
  }

  void updateThumbnailSize(double size) {
    _thumbnailSize = size;
    notifyListeners();
  }

  Future<void> _regenerateThumbnails() async {
    if (_cacheDir == null) await _initCacheDir();

    for (int i = 0; i < _imagePaths.length; i++) {
      final imagePath = _imagePaths[i];
      if (!_thumbnailCache.containsKey(imagePath) &&
          !_pendingGeneration.contains(imagePath)) {
        final cacheKey = _getCacheKeyForPath(imagePath);
        if (!_diskCacheIndex.contains(cacheKey)) {
          _queueThumbnailGeneration(imagePath);
        } else {
          _loadFromDiskCache(imagePath);
        }
      }
    }
  }

  /// 优化的请求处理：支持批量处理和多Isolate
  void _processNextRequest() {
    if (_requestQueue.isEmpty || _processingCount >= _maxConcurrent) {
      return;
    }

    // 确保Isolate已初始化，如果没有则异步初始化
    if (!_isolatesInitialized) {
      unawaited(ensureIsolatesInitialized().then((_) => _processNextRequest()));
      return;
    }

    // 批量处理优化：收集多个请求一起发送
    final batchRequests = <_ThumbnailRequest>[];
    while (batchRequests.length < _batchSize &&
        _requestQueue.isNotEmpty &&
        _processingCount < _maxConcurrent) {
      final request = _requestQueue.removeAt(0);
      batchRequests.add(request);
      _pendingGeneration.add(request.path);
      _processingCount++;
    }

    if (batchRequests.isNotEmpty) {
      // 轮询选择Isolate
      final isolateIndex = _currentIsolateIndex % _isolateCount;
      _currentIsolateIndex++;

      // 等待SendPort准备好
      _sendPortCompleters[isolateIndex].future.then((sendPort) {
        if (batchRequests.length == 1) {
          // 单个请求直接发送
          sendPort.send(batchRequests.first);
        } else {
          // 多个请求批量发送
          sendPort.send(_BatchThumbnailRequest(batchRequests));
        }
      });
    }
  }

  Future<void> exportSelected(BuildContext context) async {
    if (_selectedImagePaths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有选择任何图片')));
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      String? targetDirectory = await FilePicker.platform.getDirectoryPath();
      if (targetDirectory != null) {
        _isExporting = true;
        _exportProgress = 0.0;
        notifyListeners();

        int i = 0;
        for (var imagePath in _selectedImagePaths) {
          final imageFile = File(imagePath);
          final newPath = p.join(targetDirectory, p.basename(imageFile.path));
          await imageFile.copy(newPath);
          i++;
          _exportProgress = i / _selectedImagePaths.length;
          if (i % 5 == 0 || i == _selectedImagePaths.length) {
            notifyListeners();
          }
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('成功导出 ${_selectedImagePaths.length} 张图片')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> checkRawFileForCurrentImage() async {
    if (_imagePaths.isEmpty) return;
    final currentImagePath = _imagePaths[_currentImageIndex];
    if (_rawFileStatus.containsKey(currentImagePath)) return;

    const rawExtensions = [
      '.CR2',
      '.CR3',
      '.NEF',
      '.ARW',
      '.DNG',
      '.RAF',
      '.RW2',
      '.ORF',
      '.PEF',
      '.SRW',
      '.GPR',
      '.3FR',
      '.FFF',
      '.DCR',
      '.KDC',
      '.MRW',
      '.MOS',
      '.X3F',
    ];
    final fileDirectory = p.dirname(currentImagePath);
    final fileNameWithoutExtension = p.basenameWithoutExtension(
      currentImagePath,
    );

    for (final ext in rawExtensions) {
      final rawFilePath = p.join(
        fileDirectory,
        '$fileNameWithoutExtension$ext',
      );
      if (await File(rawFilePath).exists()) {
        _rawFileStatus[currentImagePath] = true;
        notifyListeners();
        return;
      }
    }
    _rawFileStatus[currentImagePath] = false;
    notifyListeners();
  }

  Future<void> _calculateTotalImageCount() async {
    if (_currentDirectory == null) return;
    try {
      final dir = Directory(_currentDirectory!);
      final count = await dir.list().where((entity) {
        if (entity is! File) return false;
        final extension = p.extension(entity.path).toLowerCase();
        return ['.jpg', '.jpeg', '.png', '.heic'].contains(extension);
      }).length;
      _totalImageCount = count;
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating total image count: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final cache = await getApplicationCacheDirectory();
      final cacheDir = Directory(p.join(cache.path, 'thumbnails'));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('Thumbnail cache cleared.');
      }
    } catch (e) {
      debugPrint('Error clearing thumbnail cache: $e');
    }
  }

  static Future<void> clearCacheIfNeeded({int threshold = 200}) async {
    try {
      final cache = await getApplicationCacheDirectory();
      final cacheDir = Directory(p.join(cache.path, 'thumbnails'));
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        if (files.length >= threshold) {
          await clearCache();
          debugPrint(
            'Cache limit reached. Cleared ${files.length} thumbnails.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking or clearing thumbnail cache: $e');
    }
  }

  Map<String, dynamic> getCacheStats() {
    final hitRate = (_cacheHitCount + _cacheMissCount) == 0
        ? 0
        : _cacheHitCount / (_cacheHitCount + _cacheMissCount);
    return {
      'hitCount': _cacheHitCount,
      'missCount': _cacheMissCount,
      'hitRate': hitRate,
      'diskReads': _diskReadCount,
      'memoryCacheSize': _thumbnailCache.length,
      'diskCacheSize': _diskCacheIndex.length,
    };
  }

  void resetCacheStats() {
    _cacheHitCount = 0;
    _cacheMissCount = 0;
    _diskReadCount = 0;
    notifyListeners();
  }
}
