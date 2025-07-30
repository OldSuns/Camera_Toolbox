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

/// The entry point for the isolate.
void _thumbnailGenerator(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is _ThumbnailRequest) {
      try {
        final fileBytes = await File(message.path).readAsBytes();
        final image = img.decodeImage(fileBytes);
        if (image != null) {
          final thumbnail = img.copyResize(image, width: message.width);
          final jpgBytes = Uint8List.fromList(
            img.encodeJpg(thumbnail, quality: 80),
          );

          // Save to disk cache
          final cacheFile = File(message.cachePath);
          // The directory is already created on startup.
          await cacheFile.writeAsBytes(jpgBytes);
          final cacheKey = p.basename(cacheFile.path);
          sendPort.send(_ThumbnailResult(message.path, jpgBytes, cacheKey));
        }
      } catch (e) {
        // Send null back to indicate failure
        debugPrint('Error in isolate for ${message.path}: $e');
        sendPort.send(_ThumbnailResult(message.path, Uint8List(0), ''));
      }
    }
  });
}

class LocalPickerProvider with ChangeNotifier {
  final List<String> _imagePaths = [];
  List<String> get imagePaths => _imagePaths;
  String? _currentDirectory;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  final int _pageSize = 50;

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

  Isolate? _isolate;
  SendPort? _sendPort;
  final _receivePort = ReceivePort();
  Completer<SendPort> _sendPortCompleter = Completer<SendPort>();

  int _processingCount = 0;
  final int _maxConcurrent = 6;
  final List<_ThumbnailRequest> _requestQueue = [];
  final Set<String> _pendingGeneration = {};

  LocalPickerProvider() {
    _initIsolate();
    _initCacheDir();
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

  void _initIsolate() async {
    _isolate = await Isolate.spawn(_thumbnailGenerator, _receivePort.sendPort);
    _receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        if (!_sendPortCompleter.isCompleted) {
          _sendPortCompleter.complete(message);
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
        // Even if it failed, we process the next one
        _processNextRequest();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    super.dispose();
  }

  Future<void> _resetIsolate() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _sendPortCompleter = Completer<SendPort>();
    _isolate = await Isolate.spawn(_thumbnailGenerator, _receivePort.sendPort);
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

  void precacheAdjacentImages(BuildContext context) {
    if (_imagePaths.isEmpty) return;

    // Precache the next 3 images to improve performance.
    for (int i = 1; i <= 3; i++) {
      final nextIndex = _currentImageIndex + i;
      if (nextIndex < _imagePaths.length) {
        precacheImage(FileImage(File(_imagePaths[nextIndex])), context);
      }
    }
  }

  Future<void> selectFolder() async {
    setLoading(true);
    await _resetIsolate();
    _imagePaths.clear();
    _selectedImagePaths.clear();
    _thumbnailCache.clear();
    _currentDirectory = null;
    _hasMore = true;
    _totalImageCount = 0;
    notifyListeners(); // Update UI to clear old images

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        _currentDirectory = selectedDirectory;
        // Don't await this, let it run in the background
        _calculateTotalImageCount();
        await _loadMoreImages();
      }
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    } finally {
      setLoading(false);
    }
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
      // First, trigger generation for thumbnails that don't exist at all.
      await _regenerateThumbnails();
      // Then, pre-warm the memory cache with thumbnails that are already on disk.
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
    // This should select all images in the folder, not just loaded ones.
    // For now, the simplest implementation is to just select all loaded.
    // A more complex implementation would require loading all paths first.
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
      return null; // Will be updated later
    }

    // 3. Check disk cache index (no I/O)
    final cacheKey = _getCacheKeyForPath(path);
    if (!_diskCacheIndex.contains(cacheKey)) {
      _cacheMissCount++;
      return null;
    }

    // 4. Read from disk (I/O)
    final cacheFile = _getCacheFileForPath(path);
    _diskReadCount++;
    try {
      final bytes = await cacheFile.readAsBytes();
      if (bytes.isEmpty) {
        // File is empty/corrupt, remove from index and delete
        _diskCacheIndex.remove(cacheKey);
        await cacheFile.delete();
        _cacheMissCount++;
        return null;
      }
      // Load into memory cache and return
      _thumbnailCache[path] = bytes;
      _cacheHitCount++;
      return bytes;
    } catch (e) {
      debugPrint('Error reading cache file for $path: $e. Deleting.');
      _diskCacheIndex.remove(cacheKey);
      await cacheFile.delete();
      _cacheMissCount++;
      return null;
    }
  }

  Future<void> _prewarmCache(List<String> pathsToPrewarm) async {
    // This runs in the background, not awaited, to not block the UI.
    for (final path in pathsToPrewarm) {
      if (!_thumbnailCache.containsKey(path)) {
        final cacheKey = _getCacheKeyForPath(path);
        if (_diskCacheIndex.contains(cacheKey)) {
          final cacheFile = _getCacheFileForPath(path);
          try {
            final bytes = await cacheFile.readAsBytes();
            if (bytes.isNotEmpty) {
              _thumbnailCache[path] = bytes;
              // Optional: notifyListeners() here if you want to see pre-warmed images appear live.
              // But it might cause too many rebuilds.
            }
          } catch (e) {
            // Ignore errors, the file might be corrupt.
          }
        }
      }
      // Yield to the event loop to keep the UI responsive.
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
    _sendPort ??= await _sendPortCompleter.future;
    if (_cacheDir == null) await _initCacheDir();

    const width = 300;
    for (final imagePath in _imagePaths) {
      if (!_thumbnailCache.containsKey(imagePath) &&
          !_pendingGeneration.contains(imagePath)) {
        final cacheKey = _getCacheKeyForPath(imagePath);
        if (!_diskCacheIndex.contains(cacheKey)) {
          final cacheFile = _getCacheFileForPath(imagePath);
          _requestQueue.add(
            _ThumbnailRequest(imagePath, width, cacheFile.path),
          );
        }
      }
    }
    _processNextRequest();
  }

  void _processNextRequest() {
    if (_requestQueue.isEmpty || _processingCount >= _maxConcurrent) {
      return;
    }

    while (_processingCount < _maxConcurrent && _requestQueue.isNotEmpty) {
      final request = _requestQueue.removeAt(0);
      _pendingGeneration.add(request.path);
      _processingCount++;
      _sendPort!.send(request);
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
          // Only notify listeners for progress, not for every file
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
      // Canon
      '.CR2', '.CR3',
      // Nikon
      '.NEF',
      // Sony
      '.ARW',
      // Adobe
      '.DNG',
      // Fujifilm
      '.RAF',
      // Panasonic
      '.RW2',
      // Olympus
      '.ORF',
      // Pentax
      '.PEF',
      // Samsung
      '.SRW',
      // GoPro
      '.GPR',
      // Hasselblad
      '.3FR', '.FFF',
      // Kodak
      '.DCR', '.KDC',
      // Minolta
      '.MRW',
      // Leaf
      '.MOS',
      // Sigma
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
