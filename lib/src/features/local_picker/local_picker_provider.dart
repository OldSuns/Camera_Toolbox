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
  _ThumbnailResult(this.path, this.bytes);
}

/// The entry point for the isolate.
void _thumbnailGenerator(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) {
    if (message is _ThumbnailRequest) {
      try {
        final fileBytes = File(message.path).readAsBytesSync();
        final image = img.decodeImage(fileBytes);
        if (image != null) {
          final thumbnail = img.copyResize(image, width: message.width);
          final jpgBytes = Uint8List.fromList(img.encodeJpg(thumbnail));

          // Save to disk cache
          final cacheFile = File(message.cachePath);
          // Ensure the directory exists before writing.
          cacheFile.parent.createSync(recursive: true);
          cacheFile.writeAsBytesSync(jpgBytes);

          sendPort.send(_ThumbnailResult(message.path, jpgBytes));
        }
      } catch (e) {
        debugPrint('Error in isolate for ${message.path}: $e');
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

  LocalPickerProvider() {
    _initIsolate();
    _initCacheDir();
  }

  Future<void> _initCacheDir() async {
    final cache = await getApplicationCacheDirectory();
    _cacheDir = Directory(p.join(cache.path, 'thumbnails'));
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
  }

  File _getCacheFileForPath(String path) {
    final hash = md5.convert(utf8.encode(path)).toString();
    return File(p.join(_cacheDir!.path, '$hash.jpg'));
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
        _thumbnailCache[message.path] = message.bytes;
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
      await _regenerateThumbnails();
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
      return _thumbnailCache[path];
    }

    // 2. Check disk cache
    if (_cacheDir == null) await _initCacheDir();
    final cacheFile = _getCacheFileForPath(path);

    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      // Load into memory cache and return
      _thumbnailCache[path] = bytes;
      notifyListeners();
      return bytes;
    }

    // 3. Not found in any cache
    return null;
  }

  void invertSelection() {
    final allImagePaths = _imagePaths.toSet();
    final currentSelection = _selectedImagePaths.toSet();
    _selectedImagePaths.clear();
    _selectedImagePaths.addAll(allImagePaths.difference(currentSelection));
    notifyListeners();
  }

  void updateThumbnailSize(double size) async {
    final oldSize = _thumbnailSize;
    _thumbnailSize = size;
    notifyListeners();

    // If the size crosses the 200 threshold, regenerate thumbnails.
    if ((oldSize <= 200 && size > 200) || (oldSize > 200 && size <= 200)) {
      // When size threshold changes, clear cache and reset isolate to force regeneration.
      _thumbnailCache.clear();
      notifyListeners(); // Immediately reflect the cleared cache in the UI
      await _resetIsolate();
      await _regenerateThumbnails();
      notifyListeners();
    }
  }

  Future<void> _regenerateThumbnails() async {
    _sendPort ??= await _sendPortCompleter.future;
    if (_cacheDir == null) await _initCacheDir();

    final width = _thumbnailSize > 200 ? 600 : 300;
    for (final imagePath in _imagePaths) {
      if (!_thumbnailCache.containsKey(imagePath)) {
        final cacheFile = _getCacheFileForPath(imagePath);
        if (!await cacheFile.exists()) {
          _sendPort!.send(_ThumbnailRequest(imagePath, width, cacheFile.path));
        }
      }
    }
    // notifyListeners(); // This is now called by the calling method
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
}
