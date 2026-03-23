import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:simple_native_image_compress/simple_native_image_compress.dart';
import 'package:gal/gal.dart';
import '../../shared/services/image_picker_service.dart';

/// 图像文件模型
class ImageFile {
  static const Object _noChange = Object();

  final String name;
  final String filePath;
  final int sizeInBytes;
  final int width;
  final int height;
  double progress;
  bool isCompressing;
  bool isCompleted;
  String? compressedFilePath;
  int? compressedSizeInBytes;
  String? status;
  String? errorMessage;

  ImageFile({
    required this.name,
    required this.filePath,
    required this.sizeInBytes,
    required this.width,
    required this.height,
    this.progress = 0.0,
    this.isCompressing = false,
    this.isCompleted = false,
    this.compressedFilePath,
    this.compressedSizeInBytes,
    this.status,
    this.errorMessage,
  });

  String get size => '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  String get resolution => '${width}x$height';

  String get compressionSavings {
    if (compressedSizeInBytes != null) {
      final savings =
          ((sizeInBytes - compressedSizeInBytes!) / sizeInBytes * 100);
      return '${savings.toStringAsFixed(1)}%';
    }
    return '0%';
  }

  ImageFile copyWith({
    String? name,
    String? filePath,
    int? sizeInBytes,
    int? width,
    int? height,
    double? progress,
    bool? isCompressing,
    bool? isCompleted,
    Object? compressedFilePath = _noChange,
    Object? compressedSizeInBytes = _noChange,
    Object? status = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return ImageFile(
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      progress: progress ?? this.progress,
      isCompressing: isCompressing ?? this.isCompressing,
      isCompleted: isCompleted ?? this.isCompleted,
      compressedFilePath: identical(compressedFilePath, _noChange)
          ? this.compressedFilePath
          : compressedFilePath as String?,
      compressedSizeInBytes: identical(compressedSizeInBytes, _noChange)
          ? this.compressedSizeInBytes
          : compressedSizeInBytes as int?,
      status: identical(status, _noChange) ? this.status : status as String?,
      errorMessage: identical(errorMessage, _noChange)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// 压缩配置
class CompressionConfig {
  final double quality;
  final int? maxWidth;
  final int? maxHeight;
  final bool outputToOriginalDir;
  final String? outputDirectory;
  final bool overwriteOriginal;

  CompressionConfig({
    required this.quality,
    this.maxWidth,
    this.maxHeight,
    required this.outputToOriginalDir,
    this.outputDirectory,
    this.overwriteOriginal = false,
  });
}

/// 压缩进度数据
class CompressionProgress {
  final String fileName;
  final double progress;
  final bool isCompleted;
  final String? errorMessage;

  CompressionProgress({
    required this.fileName,
    required this.progress,
    required this.isCompleted,
    this.errorMessage,
  });
}

/// Isolate 压缩任务数据
class _CompressionTask {
  final String filePath;
  final String fileName;
  final CompressionConfig config;
  final int originalWidth;
  final int originalHeight;

  _CompressionTask({
    required this.filePath,
    required this.fileName,
    required this.config,
    required this.originalWidth,
    required this.originalHeight,
  });
}

/// Isolate 压缩结果
class _CompressionResult {
  final String filePath;
  final String fileName;
  final bool success;
  final String? errorMessage;
  final String? compressedFilePath;
  final int? compressedSize;
  final bool skipped;
  final Uint8List? compressedBytes;

  _CompressionResult({
    required this.filePath,
    required this.fileName,
    required this.success,
    this.errorMessage,
    this.compressedFilePath,
    this.compressedSize,
    this.skipped = false,
    this.compressedBytes,
  });
}

/// 图像压缩服务
class ImageCompressService extends ChangeNotifier {
  final List<ImageFile> _selectedImages = [];
  bool _isCompressing = false;
  double _overallProgress = 0.0;
  String _statusMessage = '';

  // 多 Isolate 池管理 - 参考 LocalPickerProvider 的实现
  final List<Isolate?> _isolates = [];
  final List<SendPort?> _sendPorts = [];
  final List<ReceivePort> _receivePorts = [];
  final List<Completer<SendPort>> _sendPortCompleters = [];

  // 任务队列和并发控制
  final List<_CompressionTask> _taskQueue = [];
  final Set<String> _processingFiles = {};
  int _processingCount = 0;
  late final int _maxConcurrent; // 根据 CPU 核心数动态设置
  late final int _isolateCount; // 根据 CPU 核心数动态设置
  int _currentIsolateIndex = 0; // 轮询使用 Isolate

  // 完成计数器
  int _finishedCount = 0;
  int _successfulCount = 0;
  int _failedCount = 0;

  List<ImageFile> get selectedImages => List.unmodifiable(_selectedImages);
  bool get isCompressing => _isCompressing;
  double get overallProgress => _overallProgress;
  String get statusMessage => _statusMessage;

  int get totalSelectedImages => _selectedImages.length;
  String get totalSize {
    final totalBytes = _selectedImages.fold<int>(
      0,
      (sum, image) => sum + image.sizeInBytes,
    );
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  ImageCompressService() {
    _initCpuBasedSettings();
    // 🔧 不在构造函数中初始化Isolate，改为按需创建
  }

  /// 根据 CPU 核心数初始化设置
  void _initCpuBasedSettings() {
    final cpuCores = Platform.numberOfProcessors;

    // Isolate 数量 = CPU 核心数 / 2，最少 1 个，最多 6 个
    _isolateCount = (cpuCores / 2).ceil().clamp(1, 6);

    // 最大并发数 = CPU 核心数 - 1，最少 1 个，最多 12 个
    _maxConcurrent = (cpuCores - 1).clamp(1, 12);
  }

  /// 初始化多个 Isolate
  Future<void> _initIsolates() async {
    for (int i = 0; i < _isolateCount; i++) {
      final receivePort = ReceivePort();
      final completer = Completer<SendPort>();

      _receivePorts.add(receivePort);
      _sendPortCompleters.add(completer);
      _isolates.add(null);
      _sendPorts.add(null);

      final isolate = await Isolate.spawn(
        _isolateWorkerEntry,
        receivePort.sendPort,
      );
      _isolates[i] = isolate;

      receivePort.listen((dynamic message) {
        if (message is SendPort) {
          _sendPorts[i] = message;
          if (!_sendPortCompleters[i].isCompleted) {
            _sendPortCompleters[i].complete(message);
          }
        } else if (message is Map<String, dynamic>) {
          final result = _CompressionResult(
            filePath: message['filePath'] as String? ?? '',
            fileName: message['fileName'] as String,
            success: message['success'] as bool,
            errorMessage: message['errorMessage'] as String?,
            compressedFilePath: message['compressedFilePath'] as String?,
            compressedSize: message['compressedSize'] as int?,
            skipped: message['skipped'] as bool? ?? false,
            compressedBytes: message['compressedBytes'] as Uint8List?,
          );
          _processingCount--;
          _processingFiles.remove(result.filePath);
          unawaited(_handleCompressionResult(result));
          _processNextTask();
        }
      });
    }
  }

  /// 🔧 销毁Isolate池 - 在压缩完成后立即清理
  void _destroyIsolates() {
    debugPrint('正在销毁Isolate池...');

    for (int i = 0; i < _sendPorts.length; i++) {
      final sendPort = _sendPorts[i];
      if (sendPort != null) {
        try {
          sendPort.send({'action': 'shutdown'});
        } catch (e) {
          debugPrint('发送关闭信号失败: $e');
        }
      }
    }

    _killIsolatesNow();
    debugPrint('Isolate池已销毁');
  }

  // 🔧 添加dispose标志位防止新任务启动
  bool _isDisposing = false;

  @override
  void dispose() {
    // 🔧 设置标志位防止新任务启动
    _isDisposing = true;

    // 🔧 停止所有正在进行的任务
    _taskQueue.clear();
    _processingFiles.clear();
    _processingCount = 0;
    _isCompressing = false;

    // 🔧 向所有Isolate发送关闭信号
    for (int i = 0; i < _sendPorts.length; i++) {
      final sendPort = _sendPorts[i];
      if (sendPort != null) {
        try {
          sendPort.send({'action': 'shutdown'});
        } catch (e) {
          debugPrint('发送关闭信号失败: $e');
        }
      }
    }

    _killIsolatesNow();

    super.dispose();
  }

  void _killIsolatesNow() {
    for (final isolate in _isolates) {
      if (isolate != null) {
        try {
          isolate.kill(priority: Isolate.immediate);
        } catch (e) {
          debugPrint('强制终止Isolate失败: $e');
        }
      }
    }

    for (final receivePort in _receivePorts) {
      try {
        receivePort.close();
      } catch (e) {
        debugPrint('关闭ReceivePort失败: $e');
      }
    }

    _isolates.clear();
    _sendPorts.clear();
    _receivePorts.clear();
    _sendPortCompleters.clear();
  }

  /// 处理压缩结果
  Future<void> _handleCompressionResult(_CompressionResult result) async {
    final imageIndex = _selectedImages.indexWhere(
      (img) => img.filePath == result.filePath,
    );

    if (imageIndex != -1) {
      if (result.success) {
        String? finalOutputPath = result.compressedFilePath;

        // 如果是移动端且有压缩字节数据，则保存到相册
        if ((Platform.isAndroid || Platform.isIOS || Platform.isMacOS) &&
            result.compressedBytes != null &&
            !result.skipped) {
          try {
            final fileName =
                '${path.basenameWithoutExtension(result.fileName)}_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await Gal.putImageBytes(result.compressedBytes!, name: fileName);
            finalOutputPath = '已保存到相册';
            _statusMessage = '已完成并保存到相册: ${result.fileName}';
          } catch (e) {
            debugPrint('保存到相册失败: $e');
            _statusMessage = '压缩完成但保存到相册失败: ${result.fileName}';
          }
        }

        _selectedImages[imageIndex] = _selectedImages[imageIndex].copyWith(
          progress: 1.0,
          isCompressing: false,
          isCompleted: true,
          compressedFilePath: finalOutputPath,
          compressedSizeInBytes: result.compressedSize,
          status: result.skipped ? 'skipped' : 'completed',
          errorMessage: null,
        );
        _successfulCount++;
        _finishedCount++;

        if (result.skipped) {
          _statusMessage = '跳过: ${result.fileName} (无需压缩)';
        } else if (finalOutputPath == '已保存到相册') {
          // 状态消息已在上面设置
        } else {
          _statusMessage = '已完成: ${result.fileName}';
        }
      } else {
        _selectedImages[imageIndex] = _selectedImages[imageIndex].copyWith(
          progress: 0.0,
          isCompressing: false,
          isCompleted: false,
          status: 'error',
          errorMessage: result.errorMessage ?? '未知错误',
        );
        _failedCount++;
        _finishedCount++;
        _statusMessage = '压缩失败: ${result.fileName} - ${result.errorMessage}';
      }

      // 更新总体进度
      _overallProgress = _finishedCount / _selectedImages.length;
      notifyListeners();

      // 检查是否所有任务都已完成
      if (_finishedCount >= _selectedImages.length &&
          _taskQueue.isEmpty &&
          _processingCount == 0) {
        _isCompressing = false;
        final platform =
            Platform.isAndroid || Platform.isIOS || Platform.isMacOS
            ? '并已保存到相册'
            : '';
        _statusMessage =
            '压缩完成：成功/跳过 $_successfulCount 张，失败 $_failedCount 张$platform';
        // 🔧 压缩完成后立即销毁Isolate池
        _destroyIsolates();
        notifyListeners();
      }
    }
  }

  /// 处理下一个任务
  void _processNextTask() {
    // 🔧 如果正在dispose，不处理新任务
    if (_isDisposing ||
        _taskQueue.isEmpty ||
        _processingCount >= _maxConcurrent) {
      return;
    }

    final task = _taskQueue.removeAt(0);
    if (_processingFiles.contains(task.filePath)) {
      // 避免重复处理
      return;
    }

    _processingFiles.add(task.filePath);
    _processingCount++;

    // 轮询选择 Isolate
    final isolateIndex = _currentIsolateIndex % _isolateCount;
    _currentIsolateIndex++;

    // 等待 SendPort 准备好
    _sendPortCompleters[isolateIndex].future.then((sendPort) {
      sendPort.send({
        'filePath': task.filePath,
        'fileName': task.fileName,
        'config': {
          'quality': task.config.quality,
          'maxWidth': task.config.maxWidth,
          'maxHeight': task.config.maxHeight,
          'outputToOriginalDir': task.config.outputToOriginalDir,
          'outputDirectory': task.config.outputDirectory,
          'overwriteOriginal': task.config.overwriteOriginal,
        },
        'originalWidth': task.originalWidth,
        'originalHeight': task.originalHeight,
      });
    });

    // 更新对应图片的状态为正在压缩
    final imageIndex = _selectedImages.indexWhere(
      (img) => img.filePath == task.filePath,
    );
    if (imageIndex != -1) {
      _selectedImages[imageIndex] = _selectedImages[imageIndex].copyWith(
        isCompressing: true,
        progress: 0.1, // 显示开始处理
      );
      notifyListeners();
    }
  }

  /// 选择图片文件（只允许JPG格式）
  Future<void> pickImages() async {
    try {
      _statusMessage = '正在选择图片...';
      notifyListeners();

      List<File> selectedFiles = [];

      // 检查是否为移动端平台或MacOS
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        // 移动端：优先从相册选择多张图片，失败则使用文件选择器
        try {
          final galleryFiles =
              await ImagePickerService.pickMultipleImagesFromGallery();
          if (galleryFiles.isNotEmpty) {
            for (final file in galleryFiles) {
              if (_isValidImageFile(file)) {
                selectedFiles.add(file);
              }
            }
          }
        } catch (e) {
          debugPrint('从相册选择失败，尝试文件选择器: $e');
          // 相册选择失败，使用文件选择器
          final filePickerFile = await ImagePickerService.pickImageFromFile();
          if (filePickerFile != null && _isValidImageFile(filePickerFile)) {
            selectedFiles.add(filePickerFile);
          }
        }
      } else {
        // 桌面端：使用原有的文件选择器逻辑
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'JPG', 'JPEG'],
          withData: false,
          withReadStream: false,
        );

        if (result != null && result.files.isNotEmpty) {
          for (final file in result.files) {
            if (file.path != null) {
              final imageFile = File(file.path!);
              if (_isValidImageFile(imageFile)) {
                selectedFiles.add(imageFile);
              }
            }
          }
        }
      }

      if (selectedFiles.isNotEmpty) {
        _statusMessage = '正在分析选中的图片...';
        notifyListeners();

        final List<ImageFile> newImages = [];

        for (final file in selectedFiles) {
          try {
            final imageFile = await _analyzeImageFile(file.path);
            if (imageFile != null) {
              // 检查是否已经存在相同的文件
              final exists = _selectedImages.any(
                (img) => img.filePath == imageFile.filePath,
              );
              if (!exists) {
                newImages.add(imageFile);
              }
            }
          } catch (e) {
            debugPrint('分析图片文件失败: ${file.path}, 错误: $e');
          }
        }

        _selectedImages.addAll(newImages);
        _statusMessage = '已添加 ${newImages.length} 张图片';
        notifyListeners();
      } else {
        _statusMessage = '未选择任何图片';
        notifyListeners();
      }
    } catch (e) {
      _statusMessage = '选择图片失败: $e';
      notifyListeners();
    }
  }

  /// 验证图片文件是否有效
  bool _isValidImageFile(File file) {
    if (!file.existsSync()) return false;

    final extension = path.extension(file.path).toLowerCase();
    return ['.jpg', '.jpeg'].contains(extension);
  }

  /// 分析图片文件信息
  Future<ImageFile?> _analyzeImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final imageInfo = await _getImageSize(file);

      if (imageInfo == null) {
        debugPrint('无法获取图片尺寸: $filePath');
        return null;
      }

      return ImageFile(
        name: path.basename(filePath),
        filePath: filePath,
        sizeInBytes: stat.size,
        width: imageInfo.width.toInt(),
        height: imageInfo.height.toInt(),
      );
    } catch (e) {
      debugPrint('分析图片文件失败: $filePath, 错误: $e');
      return null;
    }
  }

  Future<Size?> _getImageSize(File file) {
    final completer = Completer<Size?>();
    final image = Image.file(file);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              completer.complete(
                Size(info.image.width.toDouble(), info.image.height.toDouble()),
              );
            },
            onError: (dynamic exception, StackTrace? stackTrace) {
              completer.complete(null);
            },
          ),
        );
    return completer.future;
  }

  /// 从列表中移除指定图片
  void removeImages(List<ImageFile> images) {
    final pathsToRemove = images.map((e) => e.filePath).toSet();
    _selectedImages.removeWhere((img) => pathsToRemove.contains(img.filePath));
    _statusMessage = '已移除 ${images.length} 张图片';
    notifyListeners();
  }

  /// 移除所有已完成的图片
  void removeCompletedImages() {
    final removedCount = _selectedImages.where((img) => img.isCompleted).length;
    _selectedImages.removeWhere((img) => img.isCompleted);
    _statusMessage = '已移除 $removedCount 张已完成的图片';
    notifyListeners();
  }

  /// 清空所有图片
  void clearAllImages() {
    final count = _selectedImages.length;
    _selectedImages.clear();
    _statusMessage = '已清空所有图片 ($count 张)';
    notifyListeners();
  }

  @visibleForTesting
  void replaceSelectedImagesForTesting(List<ImageFile> images) {
    _selectedImages
      ..clear()
      ..addAll(images);
    notifyListeners();
  }

  @visibleForTesting
  Future<void> applyCompressionResultForTesting({
    required String filePath,
    required String fileName,
    required bool success,
    String? errorMessage,
    String? compressedFilePath,
    int? compressedSize,
    bool skipped = false,
    Uint8List? compressedBytes,
  }) {
    if (!_isCompressing && _selectedImages.isNotEmpty) {
      _isCompressing = true;
      _finishedCount = 0;
      _successfulCount = 0;
      _failedCount = 0;
      _overallProgress = 0.0;
    }
    return _handleCompressionResult(
      _CompressionResult(
        filePath: filePath,
        fileName: fileName,
        success: success,
        errorMessage: errorMessage,
        compressedFilePath: compressedFilePath,
        compressedSize: compressedSize,
        skipped: skipped,
        compressedBytes: compressedBytes,
      ),
    );
  }

  /// 排序图片
  void sortImages(int columnIndex, bool ascending) {
    _selectedImages.sort((a, b) {
      int comparison;
      switch (columnIndex) {
        case 0: // Name
          comparison = a.name.compareTo(b.name);
          break;
        case 1: // Size
          comparison = a.sizeInBytes.compareTo(b.sizeInBytes);
          break;
        case 2: // Resolution
          comparison = (a.width * a.height).compareTo(b.width * b.height);
          break;
        case 3: // Savings
          final savingsA = a.compressedSizeInBytes != null
              ? (a.sizeInBytes - a.compressedSizeInBytes!)
              : 0;
          final savingsB = b.compressedSizeInBytes != null
              ? (b.sizeInBytes - b.compressedSizeInBytes!)
              : 0;
          comparison = savingsA.compareTo(savingsB);
          break;
        default:
          return 0;
      }
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
  }

  /// 开始批量压缩 - 使用多 Isolate 并发处理
  Future<void> startCompression(CompressionConfig config) async {
    if (_selectedImages.isEmpty) {
      _statusMessage = '请先选择要压缩的图片';
      notifyListeners();
      return;
    }

    if (_isCompressing) {
      _statusMessage = '压缩正在进行中...';
      notifyListeners();
      return;
    }

    final requiresDirectory =
        !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS) &&
        !config.outputToOriginalDir &&
        (config.outputDirectory == null || config.outputDirectory!.isEmpty);
    if (requiresDirectory) {
      _statusMessage = '请先选择输出目录，或改为输出到原目录';
      notifyListeners();
      return;
    }

    _isCompressing = true;
    _overallProgress = 0.0;
    _finishedCount = 0;
    _successfulCount = 0;
    _failedCount = 0;
    _statusMessage = '正在初始化压缩环境...';
    notifyListeners();

    // 🔧 按需创建Isolate池
    if (_isolates.isEmpty) {
      await _initIsolates();
    }

    _statusMessage = '正在开始压缩...';

    // 重置所有图片的压缩状态
    for (int i = 0; i < _selectedImages.length; i++) {
      _selectedImages[i] = _selectedImages[i].copyWith(
        progress: 0.0,
        isCompressing: false,
        isCompleted: false,
        compressedFilePath: null,
        compressedSizeInBytes: null,
        status: null,
        errorMessage: null,
      );
    }

    // 清空任务队列和处理状态
    _taskQueue.clear();
    _processingFiles.clear();
    _processingCount = 0;

    // 将所有图片加入任务队列
    for (final image in _selectedImages) {
      _taskQueue.add(
        _CompressionTask(
          filePath: image.filePath,
          fileName: image.name,
          config: config,
          originalWidth: image.width,
          originalHeight: image.height,
        ),
      );
    }

    notifyListeners();

    try {
      // 启动任务处理
      for (int i = 0; i < _maxConcurrent && i < _taskQueue.length; i++) {
        _processNextTask();
      }
    } catch (e) {
      _statusMessage = '压缩过程中发生错误: $e';
      _isCompressing = false;
      notifyListeners();
    }
  }

  /// Isolate 工作线程入口函数 - 处理单个压缩任务
  static void _isolateWorkerEntry(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    // 确保在任何退出路径都清理资源
    void cleanup() {
      receivePort.close();
    }

    // 初始化图像压缩库
    try {
      await NativeImageCompress.init();
    } catch (e) {
      // 发送错误消息
      try {
        sendPort.send({
          'filePath': '',
          'fileName': 'system',
          'success': false,
          'errorMessage': '初始化压缩库失败: $e',
        });
      } catch (sendError) {
        // 如果发送失败，至少记录错误
        debugPrint('发送初始化错误失败: $sendError');
      }
      cleanup(); // 🔧 确保资源清理
      return;
    }

    // 设置消息监听器，并添加错误处理
    receivePort.listen(
      (dynamic message) async {
        if (message is Map<String, dynamic>) {
          // 🔧 检查关闭信号
          if (message['action'] == 'shutdown') {
            cleanup();
            return;
          }

          final filePath = message['filePath'] as String;
          final fileName = message['fileName'] as String;
          final configMap = message['config'] as Map<String, dynamic>;
          final originalWidth = message['originalWidth'] as int;
          final originalHeight = message['originalHeight'] as int;

          final config = CompressionConfig(
            quality: configMap['quality'] as double,
            maxWidth: configMap['maxWidth'] as int?,
            maxHeight: configMap['maxHeight'] as int?,
            outputToOriginalDir: configMap['outputToOriginalDir'] as bool,
            outputDirectory: configMap['outputDirectory'] as String?,
            overwriteOriginal: configMap['overwriteOriginal'] as bool,
          );

          try {
            // 执行压缩
            final result = await _compressImage(
              filePath,
              config,
              originalWidth,
              originalHeight,
            );

            if (result['success'] as bool) {
              try {
                sendPort.send({
                  'filePath': filePath,
                  'fileName': fileName,
                  'success': true,
                  'compressedFilePath': result['outputPath'] as String,
                  'compressedSize': result['compressedSize'] as int,
                  'skipped': result['skipped'] as bool? ?? false,
                  'compressedBytes': result['compressedBytes'] as Uint8List?,
                });
              } catch (e) {
                debugPrint('发送成功结果失败: $e');
              }
            } else {
              try {
                sendPort.send({
                  'filePath': filePath,
                  'fileName': fileName,
                  'success': false,
                  'errorMessage': result['error'] as String,
                });
              } catch (e) {
                debugPrint('发送错误结果失败: $e');
              }
            }
          } catch (e) {
            try {
              sendPort.send({
                'filePath': filePath,
                'fileName': fileName,
                'success': false,
                'errorMessage': '压缩失败: $e',
              });
            } catch (sendError) {
              debugPrint('发送异常结果失败: $sendError');
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Isolate消息处理错误: $error');
        cleanup(); // 🔧 错误时清理资源
      },
      onDone: () {
        cleanup(); // 🔧 正常完成时清理资源
      },
    );
  }

  /// 压缩单个图片
  static Future<Map<String, dynamic>> _compressImage(
    String filePath,
    CompressionConfig config,
    int originalWidth,
    int originalHeight,
  ) async {
    try {
      final inputFile = File(filePath);
      if (!await inputFile.exists()) {
        return {'success': false, 'error': '文件不存在'};
      }

      // 执行压缩
      Uint8List? compressedBytes;

      if (config.maxWidth != null || config.maxHeight != null) {
        // 有尺寸限制，使用 contain 方法
        compressedBytes = await ImageCompress.containFromFilepath(
          filePath: filePath,
          compressFormat: CompressFormat.jpeg,
          quality: config.quality.round(),
          maxWidth: config.maxWidth ?? 4096,
          maxHeight: config.maxHeight ?? 4096,
          samplingFilter: FilterType.triangle,
        );
      } else {
        // 无尺寸限制，使用基本压缩
        compressedBytes = await ImageCompress.containFromFilepath(
          filePath: filePath,
          compressFormat: CompressFormat.jpeg,
          quality: config.quality.round(),
          maxWidth: originalWidth,
          maxHeight: originalHeight,
          samplingFilter: FilterType.triangle,
        );
      }

      if (compressedBytes.isEmpty) {
        return {'success': false, 'error': '压缩失败，返回数据为空'};
      }

      if (compressedBytes.length >= inputFile.lengthSync()) {
        return {
          'success': true,
          'skipped': true,
          'outputPath': filePath,
          'compressedSize': inputFile.lengthSync(),
          'compressedBytes': null, // 跳过时不返回字节数据
        };
      }

      // 根据平台选择保存方式
      String outputPath;
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        // 移动端：保存到相册，返回特殊标记
        outputPath = 'gallery_saved'; // 特殊标记表示已保存到相册
      } else {
        // 桌面端：保存到文件系统
        if (config.outputToOriginalDir) {
          if (config.overwriteOriginal) {
            outputPath = filePath;
          } else {
            final dir = path.dirname(filePath);
            final nameWithoutExt = path.basenameWithoutExtension(filePath);
            outputPath = path.join(dir, '${nameWithoutExt}_compressed.jpg');
          }
        } else {
          final outputDir = config.outputDirectory ?? path.dirname(filePath);
          if (outputDir.trim().isEmpty) {
            return {'success': false, 'error': '未设置输出目录'};
          }
          final fileName = path.basenameWithoutExtension(filePath);
          outputPath = path.join(outputDir, '${fileName}_compressed.jpg');
        }

        // 桌面端直接保存文件
        final outputFile = File(outputPath);
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(compressedBytes);
      }

      return {
        'success': true,
        'skipped': false,
        'outputPath': outputPath,
        'compressedSize': compressedBytes.length,
        'compressedBytes':
            (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
            ? compressedBytes
            : null, // 移动端返回字节数据用于保存到相册
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
