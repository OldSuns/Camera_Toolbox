export 'local_picker_models.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/conflict_action.dart';
import '../exif_reader/exif_data.dart';
import '../exif_reader/exif_service.dart';
import 'local_picker_models.dart';

const Set<String> _supportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
};

const Set<String> _supportedRawExtensions = {
  '.raw',
  '.crw',
  '.cr2',
  '.cr3',
  '.nef',
  '.nrw',
  '.arw',
  '.srf',
  '.sr2',
  '.dng',
  '.raf',
  '.orf',
  '.rw2',
  '.pef',
  '.ptx',
  '.srw',
  '.gpr',
  '.3fr',
  '.fff',
  '.dcr',
  '.kdc',
  '.mrw',
  '.mos',
  '.x3f',
};

class _ThumbnailRequest {
  final String path;
  final int targetDimension;
  final String cachePath;
  final String requestKey;
  final _ThumbnailRequestPriority priority;
  final int sequence;

  const _ThumbnailRequest(
    this.path,
    this.targetDimension,
    this.cachePath,
    this.requestKey, {
    required this.priority,
    required this.sequence,
  });
}

class _ThumbnailResult {
  final String requestKey;
  final Uint8List bytes;
  final String cacheKey;

  const _ThumbnailResult(this.requestKey, this.bytes, this.cacheKey);
}

enum _ThumbnailRequestPriority { immediate, visible }

class _ResolvedExportName {
  final String? imageFileName;
  final String? rawFileName;
  final bool wasRenamed;
  final bool imageSkipped;
  final bool rawSkipped;

  const _ResolvedExportName({
    required this.imageFileName,
    required this.rawFileName,
    required this.wasRenamed,
    this.imageSkipped = false,
    this.rawSkipped = false,
  });
}

void _thumbnailGenerator(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is _ThumbnailRequest) {
      await _processSingleThumbnail(message, sendPort);
    }
  });
}

Future<void> _processSingleThumbnail(
  _ThumbnailRequest message,
  SendPort sendPort,
) async {
  try {
    final file = File(message.path);
    final fileSize = await file.length();
    if (fileSize > 50 * 1024 * 1024) {
      sendPort.send(_ThumbnailResult(message.requestKey, Uint8List(0), ''));
      return;
    }

    final fileBytes = await file.readAsBytes();
    final image = img.decodeImage(fileBytes);
    if (image == null) {
      sendPort.send(_ThumbnailResult(message.requestKey, Uint8List(0), ''));
      return;
    }

    final thumbnail = img.copyResize(
      image,
      width: message.targetDimension,
      interpolation: img.Interpolation.nearest,
    );
    final jpgBytes = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));

    final cacheFile = File(message.cachePath);
    await cacheFile.parent.create(recursive: true);
    unawaited(cacheFile.writeAsBytes(jpgBytes));
    sendPort.send(
      _ThumbnailResult(
        message.requestKey,
        jpgBytes,
        p.basename(cacheFile.path),
      ),
    );
  } catch (error) {
    debugPrint('Error in thumbnail isolate for ${message.path}: $error');
    sendPort.send(_ThumbnailResult(message.requestKey, Uint8List(0), ''));
  }
}

class LocalPickerProvider with ChangeNotifier {
  LocalPickerProvider({
    int pageSize = 100,
    Future<Directory> Function()? cacheDirectoryProvider,
    Future<ExifData> Function(String path)? exifReader,
    Future<Uint8List> Function(File file)? thumbnailDiskReader,
    int? isolateCountOverride,
    int? maxConcurrentOverride,
  }) : _pageSize = pageSize,
       _cacheDirectoryProvider =
           cacheDirectoryProvider ?? getApplicationCacheDirectory,
       _exifReader = exifReader ?? ExifService.readExifFromFile,
       _thumbnailDiskReader =
           thumbnailDiskReader ?? _defaultThumbnailDiskReader,
       _isolateCountOverride = isolateCountOverride,
       _maxConcurrentOverride = maxConcurrentOverride {
    _initCpuBasedSettings();
    unawaited(_initCacheDir());
  }

  static Future<Uint8List> _defaultThumbnailDiskReader(File file) {
    return file.readAsBytes();
  }

  final int _pageSize;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final Future<ExifData> Function(String path) _exifReader;
  final Future<Uint8List> Function(File file) _thumbnailDiskReader;
  final int? _isolateCountOverride;
  final int? _maxConcurrentOverride;

  final List<LocalImageEntry> _allImageEntries = [];
  List<LocalImageEntry> get allImageEntries =>
      List.unmodifiable(_allImageEntries);

  final List<LocalImageEntry> _filteredImageEntries = [];
  List<LocalImageEntry> get filteredImageEntries =>
      List.unmodifiable(_filteredImageEntries);

  int _visibleCount = 0;
  List<LocalImageEntry> get visibleImageEntries =>
      _filteredImageEntries.take(_visibleCount).toList(growable: false);

  List<String> get imagePaths =>
      visibleImageEntries.map((entry) => entry.path).toList(growable: false);

  String? _currentDirectory;
  String? get currentDirectory => _currentDirectory;

  FolderScanScope _scanScope = FolderScanScope.currentOnly;
  FolderScanScope get scanScope => _scanScope;

  LocalPickerSortMode _sortMode = LocalPickerSortMode.modifiedNewest;
  LocalPickerSortMode get sortMode => _sortMode;

  LocalPickerFilterMode _filterMode = LocalPickerFilterMode.all;
  LocalPickerFilterMode get filterMode => _filterMode;

  final Set<String> _selectedImagePaths = {};
  Set<String> get selectedImagePaths => Set.unmodifiable(_selectedImagePaths);

  final Map<String, LocalImageEntry> _entriesByPath = {};

  bool _showCaptureInfo = false;
  bool get showCaptureInfo => _showCaptureInfo;
  int _messageSequence = 0;
  LocalPickerUserMessage? _pendingUserMessage;
  LocalPickerUserMessage? get pendingUserMessage => _pendingUserMessage;

  final Map<String, LocalImageMetadata> _metadataCache = {};
  Map<String, LocalImageMetadata> get metadataCache =>
      Map.unmodifiable(_metadataCache);
  final Set<String> _pendingMetadataPaths = {};
  Set<String> get pendingMetadataPaths =>
      Set.unmodifiable(_pendingMetadataPaths);

  int get totalImageCount => _allImageEntries.length;
  int get filteredImageCount => _filteredImageEntries.length;
  int get selectedCountInFiltered => _filteredImageEntries
      .where((entry) => _selectedImagePaths.contains(entry.path))
      .length;
  bool get hasMore => _visibleCount < _filteredImageEntries.length;

  double _thumbnailSize = 150.0;
  double get thumbnailSize => _thumbnailSize;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  double _exportProgress = 0.0;
  double get exportProgress => _exportProgress;

  int _currentImageIndex = 0;
  int get currentImageIndex => _currentImageIndex;

  LocalImageEntry? get currentImageEntry {
    if (_filteredImageEntries.isEmpty ||
        _currentImageIndex < 0 ||
        _currentImageIndex >= _filteredImageEntries.length) {
      return null;
    }
    return _filteredImageEntries[_currentImageIndex];
  }

  LocalImageMetadata? metadataForPath(String imagePath) {
    final cached = _metadataCache[imagePath];
    if (cached != null) {
      return cached;
    }

    final entry = _entriesByPath[imagePath];
    if (entry == null) {
      return null;
    }

    if (_pendingMetadataPaths.contains(imagePath)) {
      return LocalImageMetadata.fallback(
        entry.lastModified,
        loadState: MetadataLoadState.loading,
      );
    }

    return LocalImageMetadata.fallback(
      entry.lastModified,
      loadState: MetadataLoadState.idle,
    );
  }

  Map<String, Uint8List> get thumbnailCache => _thumbnailCache;
  final Map<String, Uint8List> _thumbnailCache = {};
  Directory? _cacheDir;
  final Set<String> _diskCacheIndex = {};
  final Set<String> _pendingDiskReads = {};
  int _cacheHitCount = 0;
  int _cacheMissCount = 0;
  int _diskReadCount = 0;

  final Map<String, FileImage> _imageProviderCache = {};
  final List<String> _imageProviderKeys = [];
  final Set<String> _preloadedImagePaths = {};
  final int _maxImageProviderCacheSize = 10;

  final List<Isolate?> _isolates = [];
  final List<SendPort?> _sendPorts = [];
  final List<ReceivePort> _receivePorts = [];

  int _processingCount = 0;
  late final int _maxConcurrent;
  late final int _isolateCount;
  final List<_ThumbnailRequest> _requestQueue = [];
  final Queue<int> _idleIsolateIndices = Queue<int>();
  final Set<String> _pendingGeneration = {};
  final Set<String> _queuedGeneration = {};
  final Set<String> _failedThumbnailPaths = {};
  int _nextThumbnailRequestSequence = 0;
  bool _isolatesInitialized = false;
  int _workerGeneration = 0;
  Timer? _thumbnailNotifyTimer;
  bool _disposed = false;

  void _initCpuBasedSettings() {
    final cpuCores = Platform.numberOfProcessors;
    final int resolvedIsolateCount =
        _isolateCountOverride ?? (cpuCores / 2).ceil().clamp(1, 4);
    final int resolvedMaxConcurrent =
        (_maxConcurrentOverride ?? resolvedIsolateCount).clamp(
          1,
          resolvedIsolateCount,
        );
    _isolateCount = resolvedIsolateCount;
    _maxConcurrent = resolvedMaxConcurrent;
  }

  Future<void> _initCacheDir() async {
    final cache = await _cacheDirectoryProvider();
    _cacheDir = Directory(p.join(cache.path, 'thumbnails'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
      return;
    }

    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        _diskCacheIndex.add(p.basename(entity.path));
      }
    }
  }

  File _getCacheFileForPath(String imagePath, int targetDimension) {
    final cacheKey = _getCacheKeyForPath(imagePath, targetDimension);
    return File(p.join(_cacheDir!.path, cacheKey));
  }

  String _getCacheKeyForPath(String imagePath, int targetDimension) {
    final hash = md5
        .convert(utf8.encode('$imagePath|$targetDimension'))
        .toString();
    return '${hash}_$targetDimension.jpg';
  }

  String _getThumbnailRequestKey(String imagePath, int targetDimension) {
    return '$imagePath::$targetDimension';
  }

  int normalizeThumbnailDimension(int targetDimension) {
    const buckets = [160, 240, 320, 480, 640];
    for (final bucket in buckets) {
      if (targetDimension <= bucket) {
        return bucket;
      }
    }
    return buckets.last;
  }

  String thumbnailRequestKey(String imagePath, int targetDimension) {
    return _getThumbnailRequestKey(
      imagePath,
      normalizeThumbnailDimension(targetDimension),
    );
  }

  int _preferredVisibleThumbnailDimension() {
    return normalizeThumbnailDimension((_thumbnailSize * 1.5).round());
  }

  Future<void> ensureIsolatesInitialized() async {
    if (_isolatesInitialized) {
      return;
    }

    final generation = _workerGeneration;
    for (var index = 0; index < _isolateCount; index++) {
      final receivePort = ReceivePort();

      _receivePorts.add(receivePort);
      _isolates.add(null);
      _sendPorts.add(null);

      final isolate = await Isolate.spawn(
        _thumbnailGenerator,
        receivePort.sendPort,
      );
      if (_disposed ||
          generation != _workerGeneration ||
          index >= _isolates.length) {
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      _isolates[index] = isolate;

      receivePort.listen((dynamic message) {
        if (message is SendPort) {
          _sendPorts[index] = message;
          _enqueueIdleIsolate(index);
          _processNextRequest();
          return;
        }

        if (message is! _ThumbnailResult) {
          return;
        }

        if (_processingCount > 0) {
          _processingCount--;
        }
        _enqueueIdleIsolate(index);
        _pendingGeneration.remove(message.requestKey);
        _queuedGeneration.remove(message.requestKey);
        if (message.requestKey.isNotEmpty) {
          if (message.bytes.isNotEmpty) {
            _failedThumbnailPaths.remove(message.requestKey);
            _thumbnailCache[message.requestKey] = message.bytes;
            if (message.cacheKey.isNotEmpty) {
              _diskCacheIndex.add(message.cacheKey);
            }
          } else {
            _failedThumbnailPaths.add(message.requestKey);
          }
        }
        _processNextRequest();
        _scheduleThumbnailNotify();
      });
    }

    if (!_disposed && generation == _workerGeneration) {
      _isolatesInitialized = true;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeThumbnailWorkers();
    super.dispose();
  }

  Future<void> selectFolder() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      return;
    }
    await loadDirectory(selectedDirectory);
  }

  Future<void> loadDirectory(String directoryPath) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _resetSessionState(clearDirectory: false);
      _currentDirectory = directoryPath;
      final entries = await _scanDirectory(
        directoryPath,
        recursive: _scanScope == FolderScanScope.recursive,
      );
      _allImageEntries
        ..clear()
        ..addAll(entries);
      _entriesByPath
        ..clear()
        ..addEntries(entries.map((entry) => MapEntry(entry.path, entry)));
      _rebuildAndWarmVisibleEntries(resetVisible: true);
    } catch (error) {
      debugPrint('Error loading local picker directory: $error');
      _emitUserMessage('加载目录失败: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _emitUserMessage(String message) {
    _pendingUserMessage = LocalPickerUserMessage(
      id: ++_messageSequence,
      message: message,
    );
    if (!_disposed) {
      notifyListeners();
    }
  }

  void clearPendingUserMessage(int id) {
    if (_pendingUserMessage?.id != id) {
      return;
    }
    _pendingUserMessage = null;
  }

  Future<void> _resetSessionState({bool clearDirectory = true}) async {
    _allImageEntries.clear();
    _filteredImageEntries.clear();
    _entriesByPath.clear();
    _selectedImagePaths.clear();
    _metadataCache.clear();
    _pendingMetadataPaths.clear();
    _visibleCount = 0;
    _currentImageIndex = 0;
    _exportProgress = 0.0;
    _isExporting = false;
    _requestQueue.clear();
    _pendingGeneration.clear();
    _queuedGeneration.clear();
    _failedThumbnailPaths.clear();
    _processingCount = 0;
    if (clearDirectory) {
      _currentDirectory = null;
    }
    await clearMemoryCache(notify: false);
    _resetThumbnailWorkers();
  }

  void _resetThumbnailWorkers() {
    _workerGeneration++;
    _disposeThumbnailWorkers();
    _isolatesInitialized = false;
  }

  void _disposeThumbnailWorkers() {
    _thumbnailNotifyTimer?.cancel();
    _thumbnailNotifyTimer = null;
    for (final receivePort in _receivePorts) {
      receivePort.close();
    }
    for (final isolate in _isolates) {
      isolate?.kill(priority: Isolate.immediate);
    }
    _idleIsolateIndices.clear();
    _receivePorts.clear();
    _isolates.clear();
    _sendPorts.clear();
  }

  Future<void> setScanScope(FolderScanScope scope) async {
    if (_scanScope == scope) {
      return;
    }
    _scanScope = scope;
    if (_currentDirectory == null) {
      notifyListeners();
      return;
    }
    await loadDirectory(_currentDirectory!);
  }

  void setSortMode(LocalPickerSortMode mode) {
    if (_sortMode == mode) {
      return;
    }
    _sortMode = mode;
    _rebuildAndWarmVisibleEntries(resetVisible: true);
    notifyListeners();
  }

  void setFilterMode(LocalPickerFilterMode mode) {
    if (_filterMode == mode) {
      return;
    }
    _filterMode = mode;
    _rebuildAndWarmVisibleEntries(resetVisible: true);
    notifyListeners();
  }

  void setShowCaptureInfo(bool value) {
    if (_showCaptureInfo == value) {
      return;
    }
    _showCaptureInfo = value;
    if (_showCaptureInfo) {
      _warmVisibleMetadata(startIndex: 0, count: _visibleCount);
      final currentPath = currentImageEntry?.path;
      if (currentPath != null) {
        unawaited(ensureMetadataLoaded(currentPath));
      }
    }
    notifyListeners();
  }

  void loadMoreImages() {
    if (!hasMore) {
      return;
    }
    final previousVisibleCount = _visibleCount;
    _visibleCount = (_visibleCount + _pageSize).clamp(
      0,
      _filteredImageEntries.length,
    );
    _warmVisibleRange(
      startIndex: previousVisibleCount,
      count: _visibleCount - previousVisibleCount,
    );
    notifyListeners();
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
    _selectedImagePaths.addAll(
      _filteredImageEntries.map((entry) => entry.path),
    );
    notifyListeners();
  }

  void deselectAll() {
    final filteredPaths = _filteredImageEntries
        .map((entry) => entry.path)
        .toSet();
    _selectedImagePaths.removeWhere(filteredPaths.contains);
    notifyListeners();
  }

  void invertSelection() {
    final filteredPaths = _filteredImageEntries
        .map((entry) => entry.path)
        .toSet();
    for (final path in filteredPaths) {
      if (_selectedImagePaths.contains(path)) {
        _selectedImagePaths.remove(path);
      } else {
        _selectedImagePaths.add(path);
      }
    }
    notifyListeners();
  }

  void updateThumbnailSize(double size) {
    final previousDimension = _preferredVisibleThumbnailDimension();
    _thumbnailSize = size;
    final currentDimension = _preferredVisibleThumbnailDimension();
    if (currentDimension != previousDimension) {
      _pruneQueuedThumbnailRequests(targetDimension: currentDimension);
      _warmVisibleThumbnails(startIndex: 0, count: _visibleCount);
    }
    notifyListeners();
  }

  void setCurrentImageIndex(int index) {
    if (_filteredImageEntries.isEmpty) {
      _currentImageIndex = 0;
      return;
    }
    final clamped = index.clamp(0, _filteredImageEntries.length - 1);
    if (_currentImageIndex == clamped) {
      return;
    }
    _currentImageIndex = clamped;
    if (_showCaptureInfo) {
      final currentPath = _filteredImageEntries[clamped].path;
      unawaited(ensureMetadataLoaded(currentPath));
    }
    notifyListeners();
  }

  void nextImage() {
    setCurrentImageIndex(_currentImageIndex + 1);
  }

  void previousImage() {
    setCurrentImageIndex(_currentImageIndex - 1);
  }

  bool hasRawForPath(String imagePath) {
    return _entriesByPath[imagePath]?.hasRaw ?? false;
  }

  String? rawPathForImage(String imagePath) {
    return _entriesByPath[imagePath]?.rawPath;
  }

  Future<void> clearMemoryCache({bool notify = true}) async {
    _thumbnailNotifyTimer?.cancel();
    _thumbnailNotifyTimer = null;
    _thumbnailCache.clear();
    _requestQueue.clear();
    _pendingDiskReads.clear();
    _pendingGeneration.clear();
    _queuedGeneration.clear();
    _failedThumbnailPaths.clear();
    _nextThumbnailRequestSequence = 0;
    _processingCount = 0;

    final providers = _imageProviderCache.values.toList(growable: false);
    _imageProviderCache.clear();
    _imageProviderKeys.clear();
    _preloadedImagePaths.clear();

    for (final provider in providers) {
      await provider.evict();
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> ensureMetadataLoaded(String imagePath) async {
    if (!_showCaptureInfo ||
        _metadataCache.containsKey(imagePath) ||
        _pendingMetadataPaths.contains(imagePath)) {
      return;
    }

    final entry = _entriesByPath[imagePath];
    if (entry == null) {
      return;
    }

    _pendingMetadataPaths.add(imagePath);
    notifyListeners();

    try {
      final metadata = await _loadMetadataForEntry(entry);
      if (_entriesByPath.containsKey(imagePath)) {
        _metadataCache[imagePath] = metadata;
      }
    } catch (error) {
      debugPrint('Failed to load metadata for $imagePath: $error');
      if (_entriesByPath.containsKey(imagePath)) {
        _metadataCache[imagePath] = LocalImageMetadata.fallback(
          entry.lastModified,
        );
      }
    } finally {
      _pendingMetadataPaths.remove(imagePath);
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<LocalImageMetadata> _loadMetadataForEntry(
    LocalImageEntry entry,
  ) async {
    if (!ExifService.isSupportedImage(entry.path)) {
      return LocalImageMetadata.fallback(entry.lastModified);
    }

    final exifData = await _exifReader(entry.path);
    final translated = exifData.translatedData;
    final captureTime = _parseCaptureTime(translated['拍摄时间']);

    if (!exifData.hasExif || captureTime == null) {
      return LocalImageMetadata.fallback(entry.lastModified);
    }

    return LocalImageMetadata(
      captureTime: captureTime,
      captureTimeSource: CaptureTimeSource.exif,
      loadState: MetadataLoadState.loaded,
      cameraModel: _nullIfBlank(translated['相机型号']),
      aperture: _nullIfBlank(translated['光圈值']),
      shutterSpeed:
          _nullIfBlank(translated['快门速度']) ?? _nullIfBlank(translated['曝光时间']),
      iso: _nullIfBlank(translated['ISO感光度']),
      focalLength: _nullIfBlank(translated['焦距']),
    );
  }

  void _warmVisibleMetadata({required int startIndex, required int count}) {
    if (!_showCaptureInfo || count <= 0 || _filteredImageEntries.isEmpty) {
      return;
    }

    final endExclusive = (startIndex + count).clamp(
      0,
      _filteredImageEntries.length,
    );
    for (var index = startIndex; index < endExclusive; index++) {
      final imagePath = _filteredImageEntries[index].path;
      unawaited(ensureMetadataLoaded(imagePath));
    }
  }

  void _warmMetadataForIndex(int index) {
    if (!_showCaptureInfo ||
        index < 0 ||
        index >= _filteredImageEntries.length) {
      return;
    }
    unawaited(ensureMetadataLoaded(_filteredImageEntries[index].path));
  }

  DateTime? _parseCaptureTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<Uint8List?> getThumbnail(
    String imagePath, {
    required int targetDimension,
  }) async {
    final normalizedDimension = normalizeThumbnailDimension(targetDimension);
    final requestKey = _getThumbnailRequestKey(imagePath, normalizedDimension);
    if (_thumbnailCache.containsKey(requestKey)) {
      _cacheHitCount++;
      return _thumbnailCache[requestKey];
    }

    if (_pendingDiskReads.contains(requestKey)) {
      return null;
    }

    if (_queuedGeneration.contains(requestKey)) {
      _promoteQueuedThumbnailRequest(
        requestKey,
        priority: _ThumbnailRequestPriority.immediate,
      );
      return null;
    }

    if (_pendingGeneration.contains(requestKey) ||
        _failedThumbnailPaths.contains(requestKey)) {
      return null;
    }

    if (_cacheDir == null) {
      await _initCacheDir();
    }

    final cacheKey = _getCacheKeyForPath(imagePath, normalizedDimension);
    if (!_diskCacheIndex.contains(cacheKey)) {
      _cacheMissCount++;
      _queueThumbnailGeneration(
        imagePath,
        normalizedDimension,
        priority: _ThumbnailRequestPriority.immediate,
      );
      return null;
    }

    unawaited(
      _loadFromDiskCache(
        imagePath,
        normalizedDimension,
        priority: _ThumbnailRequestPriority.immediate,
      ),
    );
    return null;
  }

  Future<void> _loadFromDiskCache(
    String imagePath,
    int targetDimension, {
    required _ThumbnailRequestPriority priority,
  }) async {
    final requestKey = _getThumbnailRequestKey(imagePath, targetDimension);
    if (_thumbnailCache.containsKey(requestKey) ||
        _pendingDiskReads.contains(requestKey)) {
      return;
    }

    final cacheFile = _getCacheFileForPath(imagePath, targetDimension);
    _pendingDiskReads.add(requestKey);
    _diskReadCount++;
    try {
      if (!await cacheFile.exists()) {
        _diskCacheIndex.remove(_getCacheKeyForPath(imagePath, targetDimension));
        _cacheMissCount++;
        _queueThumbnailGeneration(
          imagePath,
          targetDimension,
          priority: priority,
        );
        return;
      }

      final bytes = await _thumbnailDiskReader(cacheFile);
      if (bytes.isEmpty) {
        _diskCacheIndex.remove(_getCacheKeyForPath(imagePath, targetDimension));
        try {
          await cacheFile.delete();
        } catch (_) {}
        _cacheMissCount++;
        _queueThumbnailGeneration(
          imagePath,
          targetDimension,
          priority: priority,
        );
        return;
      }

      _thumbnailCache[requestKey] = bytes;
      _failedThumbnailPaths.remove(requestKey);
      _cacheHitCount++;
      _scheduleThumbnailNotify();
    } catch (error) {
      debugPrint('Error reading thumbnail cache for $imagePath: $error');
      _diskCacheIndex.remove(_getCacheKeyForPath(imagePath, targetDimension));
      try {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
      } catch (_) {}
      _cacheMissCount++;
      _queueThumbnailGeneration(imagePath, targetDimension, priority: priority);
    } finally {
      _pendingDiskReads.remove(requestKey);
    }
  }

  void _queueThumbnailGeneration(
    String imagePath,
    int targetDimension, {
    _ThumbnailRequestPriority priority = _ThumbnailRequestPriority.visible,
  }) {
    final requestKey = _getThumbnailRequestKey(imagePath, targetDimension);
    if (_pendingGeneration.contains(requestKey) ||
        _queuedGeneration.contains(requestKey) ||
        _failedThumbnailPaths.contains(requestKey) ||
        _cacheDir == null) {
      return;
    }
    if (_requestQueue.length > 50) {
      return;
    }

    final request = _ThumbnailRequest(
      imagePath,
      targetDimension,
      _getCacheFileForPath(imagePath, targetDimension).path,
      requestKey,
      priority: priority,
      sequence: _nextThumbnailRequestSequence++,
    );
    _queuedGeneration.add(requestKey);
    _requestQueue.add(request);
    _requestQueue.sort((first, second) {
      final priorityCompare = first.priority.index.compareTo(
        second.priority.index,
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return first.sequence.compareTo(second.sequence);
    });
    _processNextRequest();
  }

  void _processNextRequest() {
    if (_requestQueue.isEmpty || _processingCount >= _maxConcurrent) {
      return;
    }

    if (!_isolatesInitialized) {
      unawaited(ensureIsolatesInitialized().then((_) => _processNextRequest()));
      return;
    }

    if (_idleIsolateIndices.isEmpty) {
      return;
    }

    while (_requestQueue.isNotEmpty &&
        _processingCount < _maxConcurrent &&
        _idleIsolateIndices.isNotEmpty) {
      final isolateIndex = _idleIsolateIndices.removeFirst();
      final request = _requestQueue.removeAt(0);
      _queuedGeneration.remove(request.requestKey);
      _pendingGeneration.add(request.requestKey);
      _processingCount++;
      final sendPort = _sendPorts[isolateIndex];
      if (sendPort == null) {
        _pendingGeneration.remove(request.requestKey);
        _queuedGeneration.add(request.requestKey);
        _requestQueue.insert(0, request);
        _enqueueIdleIsolate(isolateIndex);
        if (_processingCount > 0) {
          _processingCount--;
        }
        return;
      }
      sendPort.send(request);
    }
  }

  void _warmVisibleThumbnails({required int startIndex, required int count}) {
    if (count <= 0 || _filteredImageEntries.isEmpty) {
      return;
    }

    final targetDimension = _preferredVisibleThumbnailDimension();
    final endExclusive = (startIndex + count).clamp(
      0,
      _filteredImageEntries.length,
    );
    for (var index = startIndex; index < endExclusive; index++) {
      final imagePath = _filteredImageEntries[index].path;
      final requestKey = _getThumbnailRequestKey(imagePath, targetDimension);
      if (_thumbnailCache.containsKey(requestKey) ||
          _pendingDiskReads.contains(requestKey) ||
          _pendingGeneration.contains(requestKey) ||
          _queuedGeneration.contains(requestKey) ||
          _failedThumbnailPaths.contains(requestKey)) {
        continue;
      }
      final cacheKey = _getCacheKeyForPath(imagePath, targetDimension);
      if (_diskCacheIndex.contains(cacheKey)) {
        unawaited(
          _loadFromDiskCache(
            imagePath,
            targetDimension,
            priority: _ThumbnailRequestPriority.visible,
          ),
        );
      } else {
        _queueThumbnailGeneration(
          imagePath,
          targetDimension,
          priority: _ThumbnailRequestPriority.visible,
        );
      }
    }
  }

  void _warmVisibleRange({required int startIndex, required int count}) {
    _warmVisibleThumbnails(startIndex: startIndex, count: count);
    if (_showCaptureInfo) {
      _warmVisibleMetadata(startIndex: startIndex, count: count);
    }
  }

  void _rebuildAndWarmVisibleEntries({required bool resetVisible}) {
    _rebuildVisibleEntries(resetVisible: resetVisible);
    _pruneQueuedThumbnailRequests(
      targetDimension: _preferredVisibleThumbnailDimension(),
    );
    _warmVisibleRange(startIndex: 0, count: _visibleCount);
  }

  void _scheduleThumbnailNotify() {
    if (_thumbnailNotifyTimer != null || _disposed) {
      return;
    }
    _thumbnailNotifyTimer = Timer(const Duration(milliseconds: 16), () {
      _thumbnailNotifyTimer = null;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  void _enqueueIdleIsolate(int index) {
    if (_idleIsolateIndices.contains(index)) {
      return;
    }
    _idleIsolateIndices.add(index);
  }

  void _pruneQueuedThumbnailRequests({required int targetDimension}) {
    if (_requestQueue.isEmpty) {
      return;
    }
    final visiblePaths = _filteredImageEntries
        .take(_visibleCount)
        .map((entry) => entry.path)
        .toSet();
    _requestQueue.removeWhere((request) {
      final shouldRemove =
          request.targetDimension != targetDimension ||
          !visiblePaths.contains(request.path);
      if (shouldRemove) {
        _queuedGeneration.remove(request.requestKey);
      }
      return shouldRemove;
    });
  }

  void _promoteQueuedThumbnailRequest(
    String requestKey, {
    required _ThumbnailRequestPriority priority,
  }) {
    final requestIndex = _requestQueue.indexWhere(
      (request) => request.requestKey == requestKey,
    );
    if (requestIndex == -1) {
      return;
    }

    final existingRequest = _requestQueue[requestIndex];
    if (existingRequest.priority.index <= priority.index) {
      return;
    }

    _requestQueue[requestIndex] = _ThumbnailRequest(
      existingRequest.path,
      existingRequest.targetDimension,
      existingRequest.cachePath,
      existingRequest.requestKey,
      priority: priority,
      sequence: existingRequest.sequence,
    );
    _requestQueue.sort((first, second) {
      final priorityCompare = first.priority.index.compareTo(
        second.priority.index,
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return first.sequence.compareTo(second.sequence);
    });
  }

  FileImage getImageProvider(String imagePath) {
    final cached = _imageProviderCache[imagePath];
    if (cached != null) {
      _imageProviderKeys.remove(imagePath);
      _imageProviderKeys.add(imagePath);
      return cached;
    }

    final provider = FileImage(File(imagePath));
    while (_imageProviderKeys.length >= _maxImageProviderCacheSize) {
      final oldestPath = _imageProviderKeys.removeAt(0);
      _preloadedImagePaths.remove(oldestPath);
      _imageProviderCache.remove(oldestPath);
    }
    _imageProviderCache[imagePath] = provider;
    _imageProviderKeys.add(imagePath);
    return provider;
  }

  void preloadAdjacentImages(BuildContext context) {
    if (_filteredImageEntries.isEmpty) {
      return;
    }
    for (final index in [_currentImageIndex - 1, _currentImageIndex + 1]) {
      _precacheImageAtIndex(context, index);
      _warmMetadataForIndex(index);
    }
  }

  void preloadCurrentImage(BuildContext context) {
    _precacheImageAtIndex(context, _currentImageIndex);
    _warmMetadataForIndex(_currentImageIndex);
  }

  void _precacheImageAtIndex(BuildContext context, int index) {
    if (index < 0 || index >= _filteredImageEntries.length) {
      return;
    }
    final imagePath = _filteredImageEntries[index].path;
    if (_preloadedImagePaths.contains(imagePath)) {
      return;
    }

    final provider = getImageProvider(imagePath);
    _preloadedImagePaths.add(imagePath);
    unawaited(
      precacheImage(provider, context, size: const Size(1920, 1080)).catchError(
        (error) {
          debugPrint('Failed to precache image $imagePath: $error');
        },
      ),
    );
  }

  Future<LocalPickerExportResult> exportSelectedToDirectory(
    LocalPickerExportOptions options,
  ) async {
    if (_selectedImagePaths.isEmpty) {
      return const LocalPickerExportResult(
        exportedImageCount: 0,
        exportedRawCount: 0,
        renamedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        issues: [],
      );
    }

    _isExporting = true;
    _exportProgress = 0;
    notifyListeners();

    final selectedEntries = _allImageEntries
        .where((entry) => _selectedImagePaths.contains(entry.path))
        .toList(growable: false);
    final targetDirectory = Directory(options.targetDirectory);
    final existingFileNames = <String>{};

    var exportedImageCount = 0;
    var exportedRawCount = 0;
    var renamedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    final issues = <LocalPickerExportIssue>[];

    try {
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      await for (final entity in targetDirectory.list(recursive: false)) {
        if (entity is File) {
          existingFileNames.add(p.basename(entity.path));
        }
      }

      for (var index = 0; index < selectedEntries.length; index++) {
        final entry = selectedEntries[index];
        var itemRenamed = false;
        String? imageTargetPath;
        String? rawTargetPath;
        try {
          final desiredImageTargetPath = p.join(
            options.targetDirectory,
            entry.fileName,
          );
          final desiredRawFileName = entry.rawPath == null
              ? null
              : '${p.basenameWithoutExtension(entry.fileName)}${p.extension(entry.rawPath!).toLowerCase()}';
          final resolved = _resolveExportNames(
            entry: entry,
            existingFileNames: existingFileNames,
            options: options,
          );

          imageTargetPath = resolved.imageFileName == null
              ? desiredImageTargetPath
              : p.join(options.targetDirectory, resolved.imageFileName!);
          rawTargetPath = resolved.rawFileName == null
              ? (desiredRawFileName == null
                    ? null
                    : p.join(options.targetDirectory, desiredRawFileName))
              : p.join(options.targetDirectory, resolved.rawFileName!);

          final imageSelfOverwrite =
              options.conflictAction == ConflictAction.overwrite &&
              _isSamePath(entry.path, imageTargetPath);
          final rawSelfOverwrite =
              options.includeRaw &&
              entry.rawPath != null &&
              rawTargetPath != null &&
              options.conflictAction == ConflictAction.overwrite &&
              _isSamePath(entry.rawPath!, rawTargetPath);

          if (imageSelfOverwrite || rawSelfOverwrite) {
            skippedCount += options.includeRaw && entry.rawPath != null ? 2 : 1;
            issues.add(
              LocalPickerExportIssue(
                sourcePath: entry.path,
                message: '目标目录与源目录相同，已阻止覆盖原文件',
                targetPath: imageTargetPath,
              ),
            );
            if (rawSelfOverwrite && entry.rawPath != null) {
              issues.add(
                LocalPickerExportIssue(
                  sourcePath: entry.rawPath!,
                  message: 'RAW 目标目录与源目录相同，已阻止覆盖原文件',
                  targetPath: rawTargetPath,
                  isRaw: true,
                ),
              );
            }
            _exportProgress = (index + 1) / selectedEntries.length;
            notifyListeners();
            continue;
          }

          if (resolved.imageSkipped || resolved.imageFileName == null) {
            skippedCount += options.includeRaw && entry.rawPath != null ? 2 : 1;
            issues.add(
              LocalPickerExportIssue(
                sourcePath: entry.path,
                message: '目标文件已存在，按策略跳过',
                targetPath: imageTargetPath,
              ),
            );
            if (options.includeRaw && entry.rawPath != null) {
              issues.add(
                LocalPickerExportIssue(
                  sourcePath: entry.rawPath!,
                  message: 'RAW 目标文件已存在，按策略跳过',
                  targetPath: rawTargetPath,
                  isRaw: true,
                ),
              );
            }
            _exportProgress = (index + 1) / selectedEntries.length;
            notifyListeners();
            continue;
          }

          await _copyWithConflictAction(
            sourcePath: entry.path,
            targetPath: imageTargetPath,
            action: options.conflictAction,
          );
          existingFileNames.add(resolved.imageFileName!);
          exportedImageCount++;
          itemRenamed = resolved.wasRenamed;

          if (options.includeRaw && entry.rawPath != null) {
            if (resolved.rawSkipped || resolved.rawFileName == null) {
              skippedCount++;
              issues.add(
                LocalPickerExportIssue(
                  sourcePath: entry.rawPath!,
                  message: 'RAW 目标文件已存在，按策略跳过',
                  targetPath: rawTargetPath,
                  isRaw: true,
                ),
              );
            } else {
              await _copyWithConflictAction(
                sourcePath: entry.rawPath!,
                targetPath: rawTargetPath!,
                action: options.conflictAction,
              );
              existingFileNames.add(resolved.rawFileName!);
              exportedRawCount++;
            }
          }

          if (itemRenamed) {
            renamedCount++;
          }
        } catch (error) {
          failedCount++;
          issues.add(
            LocalPickerExportIssue(
              sourcePath: entry.path,
              message: '导出失败: $error',
              targetPath: imageTargetPath,
            ),
          );
        } finally {
          _exportProgress = (index + 1) / selectedEntries.length;
          if ((index + 1) % 5 == 0 || index == selectedEntries.length - 1) {
            notifyListeners();
          }
        }
      }
    } catch (error) {
      failedCount = selectedEntries.length;
      issues.add(
        LocalPickerExportIssue(
          sourcePath: options.targetDirectory,
          message: '初始化导出目录失败: $error',
          targetPath: options.targetDirectory,
        ),
      );
      _emitUserMessage('导出失败: $error');
    } finally {
      _isExporting = false;
      notifyListeners();
    }

    return LocalPickerExportResult(
      exportedImageCount: exportedImageCount,
      exportedRawCount: exportedRawCount,
      renamedCount: renamedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      issues: issues,
    );
  }

  _ResolvedExportName _resolveExportNames({
    required LocalImageEntry entry,
    required Set<String> existingFileNames,
    required LocalPickerExportOptions options,
  }) {
    final desiredImageFileName = entry.fileName;
    final desiredRawFileName = entry.rawPath == null
        ? null
        : '${p.basenameWithoutExtension(entry.fileName)}${p.extension(entry.rawPath!).toLowerCase()}';

    switch (options.conflictAction) {
      case ConflictAction.overwrite:
        return _ResolvedExportName(
          imageFileName: desiredImageFileName,
          rawFileName: options.includeRaw ? desiredRawFileName : null,
          wasRenamed: false,
        );
      case ConflictAction.skip:
        final imageExists = existingFileNames.contains(desiredImageFileName);
        final rawExists =
            options.includeRaw &&
            desiredRawFileName != null &&
            existingFileNames.contains(desiredRawFileName);
        final skipPair = options.includeRaw && desiredRawFileName != null
            ? imageExists || rawExists
            : imageExists;
        return _ResolvedExportName(
          imageFileName: skipPair ? null : desiredImageFileName,
          rawFileName: skipPair || !options.includeRaw
              ? null
              : desiredRawFileName,
          wasRenamed: false,
          imageSkipped: skipPair,
          rawSkipped:
              skipPair && options.includeRaw && desiredRawFileName != null,
        );
      case ConflictAction.rename:
        final imageBase = p.basenameWithoutExtension(desiredImageFileName);
        final imageExtension = p.extension(desiredImageFileName).toLowerCase();
        final rawExtension = desiredRawFileName == null
            ? null
            : p.extension(desiredRawFileName).toLowerCase();
        var counter = 0;
        while (true) {
          final suffix = counter == 0 ? '' : '_$counter';
          final candidateImageFileName = '$imageBase$suffix$imageExtension';
          final candidateRawFileName =
              rawExtension == null || !options.includeRaw
              ? null
              : '$imageBase$suffix$rawExtension';
          final imageConflict = existingFileNames.contains(
            candidateImageFileName,
          );
          final rawConflict =
              candidateRawFileName != null &&
              existingFileNames.contains(candidateRawFileName);
          if (!imageConflict && !rawConflict) {
            return _ResolvedExportName(
              imageFileName: candidateImageFileName,
              rawFileName: candidateRawFileName,
              wasRenamed: counter > 0,
            );
          }
          counter++;
        }
    }
  }

  Future<void> _copyWithConflictAction({
    required String sourcePath,
    required String targetPath,
    required ConflictAction action,
  }) async {
    if (_isSamePath(sourcePath, targetPath)) {
      throw StateError('源文件与目标路径相同，已阻止覆盖原文件');
    }
    final targetFile = File(targetPath);
    if (action == ConflictAction.overwrite && await targetFile.exists()) {
      await targetFile.delete();
    }
    await File(sourcePath).copy(targetPath);
  }

  bool _isSamePath(String firstPath, String secondPath) {
    final first = p.normalize(firstPath);
    final second = p.normalize(secondPath);
    return Platform.isWindows
        ? first.toLowerCase() == second.toLowerCase()
        : first == second;
  }

  Future<List<LocalImageEntry>> _scanDirectory(
    String directoryPath, {
    required bool recursive,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return const [];
    }

    final imageFiles = <File>[];
    final rawFilesByDirectory = <String, Map<String, String>>{};

    await for (final entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final extension = p.extension(entity.path).toLowerCase();
      if (_supportedImageExtensions.contains(extension)) {
        imageFiles.add(entity);
        continue;
      }
      if (_supportedRawExtensions.contains(extension)) {
        rawFilesByDirectory
            .putIfAbsent(p.dirname(entity.path), () => {})
            .putIfAbsent(
              p.basenameWithoutExtension(entity.path).toLowerCase(),
              () => entity.path,
            );
      }
    }

    const concurrencyLimit = 20;
    final entries = <LocalImageEntry>[];
    for (var index = 0; index < imageFiles.length; index += concurrencyLimit) {
      final chunk = imageFiles.sublist(
        index,
        (index + concurrencyLimit).clamp(0, imageFiles.length),
      );
      final chunkEntries = await Future.wait(
        chunk.map((file) async {
          final rawPath =
              rawFilesByDirectory[p.dirname(file.path)]?[p
                  .basenameWithoutExtension(file.path)
                  .toLowerCase()];
          return LocalImageEntry(
            path: file.path,
            fileName: p.basename(file.path),
            directoryPath: p.dirname(file.path),
            size: await file.length(),
            lastModified: await file.lastModified(),
            rawPath: rawPath,
          );
        }),
      );
      entries.addAll(chunkEntries);
    }

    return _sortEntries(entries);
  }

  List<LocalImageEntry> _sortEntries(List<LocalImageEntry> entries) {
    final sorted = [...entries];
    switch (_sortMode) {
      case LocalPickerSortMode.nameAsc:
        sorted.sort((a, b) => a.fileName.compareTo(b.fileName));
        break;
      case LocalPickerSortMode.nameDesc:
        sorted.sort((a, b) => b.fileName.compareTo(a.fileName));
        break;
      case LocalPickerSortMode.modifiedNewest:
        sorted.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case LocalPickerSortMode.modifiedOldest:
        sorted.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
    }
    return sorted;
  }

  void _rebuildVisibleEntries({required bool resetVisible}) {
    final currentPath = currentImageEntry?.path;
    final filtered = _sortEntries(_applyFilter(_allImageEntries));
    _filteredImageEntries
      ..clear()
      ..addAll(filtered);

    if (resetVisible || _visibleCount == 0) {
      _visibleCount = _filteredImageEntries.length.clamp(0, _pageSize);
    } else {
      _visibleCount = _visibleCount.clamp(0, _filteredImageEntries.length);
    }

    if (_filteredImageEntries.isEmpty) {
      _currentImageIndex = 0;
      return;
    }

    if (currentPath != null) {
      final newIndex = _filteredImageEntries.indexWhere(
        (entry) => entry.path == currentPath,
      );
      if (newIndex != -1) {
        _currentImageIndex = newIndex;
        return;
      }
    }
    _currentImageIndex = _currentImageIndex.clamp(
      0,
      _filteredImageEntries.length - 1,
    );
  }

  List<LocalImageEntry> _applyFilter(List<LocalImageEntry> entries) {
    switch (_filterMode) {
      case LocalPickerFilterMode.all:
        return [...entries];
      case LocalPickerFilterMode.selected:
        return entries
            .where((entry) => _selectedImagePaths.contains(entry.path))
            .toList(growable: false);
      case LocalPickerFilterMode.withRaw:
        return entries.where((entry) => entry.hasRaw).toList(growable: false);
    }
  }

  Map<String, dynamic> getCacheStats() {
    final totalAccesses = _cacheHitCount + _cacheMissCount;
    final hitRate = totalAccesses == 0 ? 0.0 : _cacheHitCount / totalAccesses;
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
