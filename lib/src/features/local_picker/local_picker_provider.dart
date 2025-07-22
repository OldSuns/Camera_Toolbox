import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Data class for thumbnail generation request
class _ThumbnailRequest {
  final String path;
  final int width;
  _ThumbnailRequest(this.path, this.width);
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
        // Use the 'image' package for robust decoding in a background isolate.
        final image = img.decodeImage(fileBytes);
        if (image != null) {
          final thumbnail = img.copyResize(image, width: message.width);
          final jpgBytes = img.encodeJpg(thumbnail);
          sendPort.send(
            _ThumbnailResult(message.path, Uint8List.fromList(jpgBytes)),
          );
        }
      } catch (e) {
        debugPrint('Error in isolate for ${message.path}: $e');
      }
    }
  });
}

class LocalPickerProvider with ChangeNotifier {
  List<File> _images = [];
  List<File> get images => _images;

  final Map<String, Uint8List> _thumbnailCache = {};
  final Set<File> _selectedImages = {};
  Set<File> get selectedImages => _selectedImages;

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
    if (_currentImageIndex < _images.length - 1) {
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

  Future<void> selectFolder() async {
    setLoading(true);
    await _resetIsolate();
    _images.clear();
    _selectedImages.clear();
    _thumbnailCache.clear();
    notifyListeners();

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final dir = Directory(selectedDirectory);
      final List<File> imageFiles = [];
      final completer = Completer<void>();

      dir.list().listen(
        (fileSystemEntity) {
          if (fileSystemEntity is File) {
            final extension = p.extension(fileSystemEntity.path).toLowerCase();
            if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
              imageFiles.add(fileSystemEntity);
            }
          }
        },
        onDone: () {
          _images = imageFiles;
          completer.complete();
        },
        onError: (e) {
          debugPrint('Error listing files: $e');
          completer.completeError(e);
        },
      );

      await completer.future;
      _regenerateThumbnails();
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    } finally {
      setLoading(false);
    }
  }

  void toggleSelection(File image) {
    if (_selectedImages.contains(image)) {
      _selectedImages.remove(image);
    } else {
      _selectedImages.add(image);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedImages.addAll(_images);
    notifyListeners();
  }

  void deselectAll() {
    _selectedImages.clear();
    notifyListeners();
  }

  Uint8List? getThumbnail(String path) {
    return _thumbnailCache[path];
  }

  void invertSelection() {
    final allImages = _images.toSet();
    final currentSelection = _selectedImages.toSet();
    _selectedImages.clear();
    _selectedImages.addAll(allImages.difference(currentSelection));
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
      _regenerateThumbnails();
    }
  }

  Future<void> _regenerateThumbnails() async {
    _sendPort ??= await _sendPortCompleter.future;

    final width = _thumbnailSize > 200 ? 600 : 300;
    for (final image in _images) {
      if (!_thumbnailCache.containsKey(image.path)) {
        _sendPort!.send(_ThumbnailRequest(image.path, width));
      }
    }
    notifyListeners();
  }

  Future<void> exportSelected(BuildContext context) async {
    if (_selectedImages.isEmpty) {
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
        for (var imageFile in _selectedImages) {
          final newPath = p.join(targetDirectory, p.basename(imageFile.path));
          await imageFile.copy(newPath);
          i++;
          _exportProgress = i / _selectedImages.length;
          // Only notify listeners for progress, not for every file
          if (i % 5 == 0 || i == _selectedImages.length) {
            notifyListeners();
          }
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('成功导出 ${_selectedImages.length} 张图片')),
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
    if (_images.isEmpty) return;
    final currentImage = _images[_currentImageIndex];
    if (_rawFileStatus.containsKey(currentImage.path)) return;

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
    final fileDirectory = p.dirname(currentImage.path);
    final fileNameWithoutExtension = p.basenameWithoutExtension(
      currentImage.path,
    );

    for (final ext in rawExtensions) {
      final rawFilePath = p.join(
        fileDirectory,
        '$fileNameWithoutExtension$ext',
      );
      if (await File(rawFilePath).exists()) {
        _rawFileStatus[currentImage.path] = true;
        notifyListeners();
        return;
      }
    }
    _rawFileStatus[currentImage.path] = false;
    notifyListeners();
  }
}
