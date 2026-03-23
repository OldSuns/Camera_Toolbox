import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'models/watermark_config.dart';
import 'models/image_container.dart';
import 'services/watermark_processor.dart';

/// Isolate 请求数据 - 包含预处理的水印图像数据
class _WatermarkRequest {
  final String inputFile;
  final String? outputFile;
  final WatermarkConfig config;
  final String requestId;
  final Uint8List processedImageBytes;
  final int imageWidth;
  final int imageHeight;

  _WatermarkRequest({
    required this.inputFile,
    this.outputFile,
    required this.config,
    required this.requestId,
    required this.processedImageBytes,
    required this.imageWidth,
    required this.imageHeight,
  });
}

/// Isolate 结果
class _WatermarkResult {
  final String inputFile;
  final bool success;
  final String? errorMessage;
  final Uint8List? processedBytes;

  _WatermarkResult(
    this.inputFile,
    this.success, {
    this.errorMessage,
    this.processedBytes,
  });
}

// --- Isolate Entry Points ---

/// Isolate入口点：保存预处理的图像数据
void _watermarkGenerator(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is _WatermarkRequest) {
      try {
        debugPrint('Isolate: 开始处理 ${message.inputFile}');

        // 将RGBA字节数据转换为image包格式
        final processedImage = img.Image.fromBytes(
          width: message.imageWidth,
          height: message.imageHeight,
          bytes: message.processedImageBytes.buffer,
          format: img.Format.uint8,
          numChannels: 4,
        );

        // 编码为JPG
        final jpgBytes = img.encodeJpg(
          processedImage,
          quality: message.config.outputQuality,
        );

        debugPrint('Isolate: 处理完成 ${message.inputFile}');
        sendPort.send(
          _WatermarkResult(
            message.inputFile,
            true,
            processedBytes: Uint8List.fromList(jpgBytes),
          ),
        );
      } catch (e) {
        debugPrint('Isolate: 处理失败 ${message.inputFile}: $e');
        sendPort.send(
          _WatermarkResult(
            message.inputFile,
            false,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  });
}

/// 处理状态
enum ProcessingStatus { idle, processing, completed, error }

/// 批处理任务
class BatchProcessTask {
  final File file;
  String? outputPath;
  ProcessingStatus status;
  String? errorMessage;
  double progress;

  BatchProcessTask({
    required this.file,
    this.outputPath,
    this.status = ProcessingStatus.idle,
    this.errorMessage,
    this.progress = 0.0,
  });
}

/// 照片水印Provider
class PhotoWatermarkProvider extends ChangeNotifier {
  PhotoWatermarkProvider() {
    _initCpuBasedSettings();
  }

  // 配置
  WatermarkConfig _config = WatermarkConfig();
  WatermarkConfig get config => _config;

  // 当前处理的图像
  ImageContainer? _currentImage;
  ImageContainer? get currentImage => _currentImage;

  // 预览图像
  ui.Image? _previewImage;
  ui.Image? get previewImage {
    // 检查图像是否仍然有效
    if (_previewImage != null) {
      try {
        // 尝试访问图像属性以检查是否有效
        final width = _previewImage!.width;
        final height = _previewImage!.height;
        if (width <= 0 || height <= 0) {
          return null;
        }
      } catch (e) {
        // 图像已释放或无效
        _previewImage = null;
        return null;
      }
    }
    return _previewImage;
  }

  // 是否需要生成预览
  bool _needsPreviewGeneration = false;
  bool get needsPreviewGeneration => _needsPreviewGeneration;

  // 批处理任务列表
  final List<BatchProcessTask> _batchTasks = [];
  List<BatchProcessTask> get batchTasks => _batchTasks;

  ProcessingStatus _previewStatus = ProcessingStatus.idle;
  ProcessingStatus get previewStatus => _previewStatus;

  String? _previewErrorMessage;
  String? get previewErrorMessage => _previewErrorMessage;

  ProcessingStatus _saveStatus = ProcessingStatus.idle;
  ProcessingStatus get saveStatus => _saveStatus;

  String? _saveErrorMessage;
  String? get saveErrorMessage => _saveErrorMessage;

  ProcessingStatus _batchStatus = ProcessingStatus.idle;
  ProcessingStatus get batchStatus => _batchStatus;

  String? _batchErrorMessage;
  String? get batchErrorMessage => _batchErrorMessage;

  // 总体进度
  double _overallProgress = 0.0;
  double get overallProgress => _overallProgress;

  // 输出目录
  Directory? _outputDirectory;
  Directory? get outputDirectory => _outputDirectory;

  bool get isPreviewBusy => _previewStatus == ProcessingStatus.processing;
  bool get isSavingCurrentImage => _saveStatus == ProcessingStatus.processing;
  bool get isBatchProcessing => _batchStatus == ProcessingStatus.processing;
  bool get hasSavedCurrentImage => _saveStatus == ProcessingStatus.completed;
  bool get isProcessing =>
      isPreviewBusy || isSavingCurrentImage || isBatchProcessing;

  // 已完成数量
  int get completedCount =>
      _batchTasks.where((t) => t.status == ProcessingStatus.completed).length;

  int get failedCount =>
      _batchTasks.where((t) => t.status == ProcessingStatus.error).length;

  // 总任务数
  int get totalCount => _batchTasks.length;

  // 批处理取消标志
  bool _batchProcessingCancelled = false;

  // --- Isolate Pool and Task Queue ---
  final List<Isolate?> _isolates = [];
  final List<SendPort?> _sendPorts = [];
  final List<ReceivePort> _receivePorts = [];
  final List<Completer<SendPort>> _sendPortCompleters = [];

  int _processingCount = 0;
  late final int _maxConcurrent;
  late final int _isolateCount;
  final List<_WatermarkRequest> _requestQueue = [];
  final Set<String> _pendingTasks = {}; // Tracks input file paths
  int _currentIsolateIndex = 0;
  bool _isolatesInitialized = false;

  bool get _usesGalleryOutput => Platform.isAndroid || Platform.isIOS;
  bool get _usesDirectoryOutput =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 更新配置
  void updateConfig(WatermarkConfig newConfig) {
    _config = newConfig;
    _needsPreviewGeneration = true;
    notifyListeners();
  }

  /// 更新元素配置
  void updateElement(String position, ElementConfig element) {
    WatermarkConfig newConfig;

    switch (position) {
      case 'leftTop':
        newConfig = _config.copyWith(leftTop: element);
        break;
      case 'leftBottom':
        newConfig = _config.copyWith(leftBottom: element);
        break;
      case 'rightTop':
        newConfig = _config.copyWith(rightTop: element);
        break;
      case 'rightBottom':
        newConfig = _config.copyWith(rightBottom: element);
        break;
      default:
        return;
    }

    updateConfig(newConfig);
  }

  /// 切换Logo启用状态
  void toggleLogo() {
    updateConfig(_config.copyWith(logoEnabled: !_config.logoEnabled));
  }

  /// 设置Logo位置
  void setLogoPosition(LogoPosition position) {
    updateConfig(_config.copyWith(logoPosition: position));
  }

  /// 切换白边
  void toggleWhiteMargin() {
    updateConfig(
      _config.copyWith(whiteMarginEnabled: !_config.whiteMarginEnabled),
    );
  }

  /// 更新白边宽度
  void updateWhiteMarginWidth(double width) {
    updateConfig(_config.copyWith(whiteMarginWidth: width));
  }

  /// 更新背景模糊边框大小
  void updateBackgroundBlurPaddingPercent(double percent) {
    final newSettings = Map<String, dynamic>.from(_config.extraSettings);
    newSettings['backgroundBlurPaddingPercent'] = percent;
    updateConfig(_config.copyWith(extraSettings: newSettings));
  }

  /// 切换阴影
  void toggleShadow() {
    updateConfig(_config.copyWith(shadowEnabled: !_config.shadowEnabled));
  }

  /// 切换等效焦距
  void toggleEquivalentFocalLength() {
    updateConfig(
      _config.copyWith(
        useEquivalentFocalLength: !_config.useEquivalentFocalLength,
      ),
    );
    if (_currentImage != null) {
      _currentImage!.useEquivalentFocalLength =
          !_config.useEquivalentFocalLength;
      _generatePreview();
    }
  }

  /// 更新输出质量
  void updateOutputQuality(int quality) {
    updateConfig(_config.copyWith(outputQuality: quality.clamp(1, 100)));
  }

  /// 更新自定义文本
  void updateCustomText(WatermarkElementType type, String text) {
    if (_currentImage != null) {
      _currentImage!.customTexts[type] = text;
      _needsPreviewGeneration = true;
      notifyListeners();
    }
  }

  /// 加载单个图像
  Future<void> loadImage(File file) async {
    try {
      _previewStatus = ProcessingStatus.processing;
      _previewErrorMessage = null;
      _saveStatus = ProcessingStatus.idle;
      _saveErrorMessage = null;
      notifyListeners();

      // 释放之前的资源
      final oldImage = _currentImage;
      final oldPreview = _previewImage;

      _currentImage = null;
      _previewImage = null;

      // 延迟释放旧资源
      if (oldImage != null) {
        Future.microtask(() => oldImage.dispose());
      }
      if (oldPreview != null) {
        Future.microtask(() => oldPreview.dispose());
      }

      // 加载新图像
      _currentImage = await ImageContainer.fromFile(file);
      _currentImage!.useEquivalentFocalLength =
          _config.useEquivalentFocalLength;

      // 自动生成预览
      await _generatePreview();
      _needsPreviewGeneration = false;

      _previewStatus = ProcessingStatus.idle;
      notifyListeners();
    } catch (e) {
      _previewStatus = ProcessingStatus.error;
      _previewErrorMessage = '加载图像失败: $e';
      notifyListeners();
    }
  }

  /// 生成预览 - 在主线程中异步处理
  Future<void> _generatePreview() async {
    if (_currentImage == null) return;

    try {
      await _generatePreviewInMainThread();
    } catch (e) {
      debugPrint('生成预览失败: $e');
      _previewStatus = ProcessingStatus.error;
      _previewErrorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 手动生成预览 - 在主线程中异步处理
  Future<void> generatePreviewManually() async {
    if (_currentImage == null) return;

    try {
      _previewStatus = ProcessingStatus.processing;
      _needsPreviewGeneration = false;
      _previewErrorMessage = null;
      notifyListeners();

      await _generatePreviewInMainThread();

      _previewStatus = ProcessingStatus.idle;
      notifyListeners();
    } catch (e) {
      _previewStatus = ProcessingStatus.error;
      _previewErrorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 在主线程中生成预览
  Future<void> _generatePreviewInMainThread() async {
    if (_currentImage == null) return;

    try {
      debugPrint('主线程: 开始生成预览');

      // 创建水印处理器
      final processor = WatermarkProcessorFactory.create(_config);

      // 处理图像
      final processedImage = await processor.process(_currentImage!);

      debugPrint(
        '主线程: 水印处理完成，尺寸: ${processedImage.width}x${processedImage.height}',
      );

      // 释放旧的预览图像
      final oldPreviewImage = _previewImage;
      _previewImage = processedImage;

      if (oldPreviewImage != null) {
        Future.microtask(() => oldPreviewImage.dispose());
      }

      _previewStatus = ProcessingStatus.idle;
      _needsPreviewGeneration = false;
      _previewErrorMessage = null;
      debugPrint('主线程: 预览图像更新完成');
      notifyListeners();
    } catch (e) {
      debugPrint('主线程: 预览生成失败: $e');
      _previewStatus = ProcessingStatus.error;
      _previewErrorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 保存当前图像
  Future<bool> _requestStoragePermission() async {
    PermissionStatus status;

    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      // Desktop platforms have no runtime permissions for this
      return true;
    }

    // On iOS, `limited` access is still sufficient for saving to gallery.
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Guide user to app settings
      await openAppSettings();
    }

    return false;
  }

  /// Saves the given JPG bytes to the appropriate location based on the platform.
  Future<String> _saveJpgBytes(
    Uint8List jpgBytes,
    String fileName, {
    String? preferredOutputPath,
  }) async {
    if (_usesGalleryOutput) {
      await Gal.putImageBytes(jpgBytes, name: fileName);
      return fileName;
    } else {
      await _ensureOutputDirectory();
      final preferredPath =
          preferredOutputPath ?? path.join(_outputDirectory!.path, fileName);
      final outputPath = await _resolveUniqueOutputPath(preferredPath);
      await File(outputPath).writeAsBytes(jpgBytes);
      return outputPath;
    }
  }

  Future<void> saveCurrentImage() async {
    if (_currentImage == null || _previewImage == null) return;

    try {
      _saveStatus = ProcessingStatus.processing;
      _saveErrorMessage = null;
      notifyListeners();

      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('存储权限被拒绝');
      }

      final jpgBytes = await _getImageAsJpgBytes(_previewImage!);
      if (jpgBytes == null) {
        throw Exception('无法生成JPG数据');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${path.basenameWithoutExtension(_currentImage!.sourceFile.path)}_watermark_$timestamp.jpg';

      await _saveJpgBytes(jpgBytes, fileName);
      _saveStatus = ProcessingStatus.completed;
      notifyListeners();
    } catch (e) {
      _saveStatus = ProcessingStatus.error;
      _saveErrorMessage = '保存图像失败: $e';
      notifyListeners();
    }
  }

  /// 添加批处理文件
  Future<void> addBatchFiles(List<File> files) async {
    debugPrint('addBatchFiles 被调用，文件数量: ${files.length}');
    final isDesktop = _usesDirectoryOutput;

    // 仅在桌面端需要预设输出目录
    if (isDesktop) {
      await _ensureOutputDirectory();
    }

    int addedCount = 0;
    for (final file in files) {
      debugPrint('处理文件: ${file.path}');

      if (!await file.exists()) {
        debugPrint('文件不存在: ${file.path}');
        continue;
      }
      if (_batchTasks.any((t) => t.file.path == file.path)) {
        debugPrint('文件已存在于列表中: ${file.path}');
        continue;
      }

      // 桌面端生成完整输出路径，移动端则留空，由ImageGallerySaver处理
      String? outputPath;
      if (isDesktop) {
        final outputFileName =
            '${path.basenameWithoutExtension(file.path)}_watermark.jpg';
        outputPath = path.join(_outputDirectory!.path, outputFileName);
      }

      _batchTasks.add(BatchProcessTask(file: file, outputPath: outputPath));
      addedCount++;
      debugPrint('成功添加文件到批处理列表: ${file.path}');
    }

    debugPrint('总共添加了 $addedCount 个文件到批处理列表');
    if (isDesktop) {
      debugPrint('使用输出目录: ${_outputDirectory!.path}');
    }

    notifyListeners();
  }

  /// 移除批处理任务
  void removeBatchTask(int index) {
    if (index >= 0 && index < _batchTasks.length) {
      _batchTasks.removeAt(index);
      _updateOverallProgress();
      notifyListeners();
    }
  }

  /// 清空批处理任务
  void clearBatchTasks() {
    if (isBatchProcessing) {
      cancelBatchProcessing();
    }
    _batchTasks.clear();
    _overallProgress = 0.0;
    _batchStatus = ProcessingStatus.idle;
    _batchErrorMessage = null;
    notifyListeners();
  }

  /// 开始批处理 - 使用定时器分批处理避免阻塞UI
  /// 开始批处理 - 使用多Isolate并行处理
  Future<void> startBatchProcessing() async {
    if (_batchTasks.isEmpty || isBatchProcessing) return;

    _batchStatus = ProcessingStatus.processing;
    _batchErrorMessage = null;
    _overallProgress = 0.0;
    _batchProcessingCancelled = false;
    notifyListeners();

    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _batchStatus = ProcessingStatus.error;
      _batchErrorMessage = '存储权限被拒绝，无法开始批处理';
      notifyListeners();
      return;
    }

    // 仅在桌面端需要预设输出目录
    // Desktop platforms that use file paths need an output directory.
    if (_usesDirectoryOutput) {
      await _ensureOutputDirectory();
    }
    await _initializeIsolates();

    // 重置任务状态
    for (final task in _batchTasks) {
      task.status = ProcessingStatus.idle;
      task.progress = 0.0;
    }
    notifyListeners();

    // 预处理所有图像并填充队列
    await _preprocessBatchImages();

    // 启动处理
    for (int i = 0; i < _maxConcurrent; i++) {
      _processNextRequest();
    }
  }

  /// 预处理批量图像数据
  Future<void> _preprocessBatchImages() async {
    debugPrint('开始预处理批量图像数据，共 ${_batchTasks.length} 个文件');

    _requestQueue.clear();
    _pendingTasks.clear();

    for (int i = 0; i < _batchTasks.length; i++) {
      if (_batchProcessingCancelled) break;

      final task = _batchTasks[i];

      try {
        task.status = ProcessingStatus.processing;
        task.progress = 0.1;
        notifyListeners();
        debugPrint('预处理图像 ${i + 1}/${_batchTasks.length}: ${task.file.path}');

        // 在主线程中加载图像并生成水印
        final container = await ImageContainer.fromFile(task.file);
        container.useEquivalentFocalLength = _config.useEquivalentFocalLength;

        // 创建水印处理器并处理图像
        final processor = WatermarkProcessorFactory.create(_config);
        final processedImage = await processor.process(container);

        // 将处理后的图像转换为字节数据
        final byteData = await processedImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );

        if (byteData != null) {
          final request = _WatermarkRequest(
            inputFile: task.file.path,
            outputFile: task.outputPath,
            config: _config,
            requestId: DateTime.now().millisecondsSinceEpoch.toString(),
            processedImageBytes: byteData.buffer.asUint8List(),
            imageWidth: processedImage.width,
            imageHeight: processedImage.height,
          );
          _requestQueue.add(request);
        } else {
          throw Exception('Failed to convert processed image to bytes');
        }

        // 清理资源
        container.dispose();
        processedImage.dispose();
        task.status = ProcessingStatus.idle;
        task.progress = 0.0;

        debugPrint('预处理完成: ${task.file.path}');
      } catch (e) {
        debugPrint('预处理失败: ${task.file.path}, 错误: $e');
        task.status = ProcessingStatus.error;
        task.errorMessage = '预处理失败: $e';
        _updateOverallProgress();
      }

      // 更新进度
      notifyListeners();
      await Future<void>.delayed(Duration.zero);
    }

    debugPrint('批量图像预处理完成，队列中有 ${_requestQueue.length} 个任务');
  }

  /// 处理下一个请求
  void _processNextRequest() {
    if (_batchStatus != ProcessingStatus.processing) {
      return;
    }

    if (_requestQueue.isEmpty) {
      // 如果队列为空且没有待处理任务，则完成
      if (_pendingTasks.isEmpty) {
        if (!_batchProcessingCancelled) {
          _batchStatus = ProcessingStatus.completed;
        }
        _disposeIsolatePool();
        notifyListeners();
      }
      return;
    }

    if (_processingCount >= _maxConcurrent || _batchProcessingCancelled) {
      return;
    }

    final request = _requestQueue.removeAt(0);
    _pendingTasks.add(request.inputFile);
    _processingCount++;

    // 更新UI，显示任务正在处理
    final taskIndex = _batchTasks.indexWhere(
      (t) => t.file.path == request.inputFile,
    );
    if (taskIndex != -1) {
      _batchTasks[taskIndex].status = ProcessingStatus.processing;
      notifyListeners();
    }

    // 轮询选择Isolate
    final isolateIndex = _currentIsolateIndex % _isolateCount;
    _currentIsolateIndex++;

    // 等待SendPort准备好
    _sendPortCompleters[isolateIndex].future.then((sendPort) {
      if (!_batchProcessingCancelled) {
        sendPort.send(request);
      }
    });
  }

  /// 取消批处理
  void cancelBatchProcessing() {
    _batchProcessingCancelled = true;
    _batchStatus = ProcessingStatus.idle;
    _batchErrorMessage = null;
    for (final task in _batchTasks) {
      if (task.status == ProcessingStatus.processing) {
        task.status = ProcessingStatus.idle;
        task.progress = 0.0;
      }
    }
    _disposeIsolatePool();
    notifyListeners();
  }

  /// 将UI图像转换为JPG字节数据
  Future<Uint8List?> _getImageAsJpgBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final imgImage = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: byteData.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );

    return Uint8List.fromList(
      img.encodeJpg(imgImage, quality: _config.outputQuality),
    );
  }

  /// 更新总体进度
  void _updateOverallProgress() {
    if (_batchTasks.isEmpty) {
      _overallProgress = 0.0;
    } else {
      final completed = _batchTasks
          .where(
            (t) =>
                t.status == ProcessingStatus.completed ||
                t.status == ProcessingStatus.error,
          )
          .length;
      _overallProgress = completed / _batchTasks.length;
    }
  }

  /// 确保输出目录已设置
  Future<void> _ensureOutputDirectory() async {
    if (_outputDirectory == null) {
      Directory? baseDir;
      try {
        // 优先使用“下载”文件夹作为默认输出位置，因为它是一个标准、可靠的用户目录
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          baseDir = await getDownloadsDirectory();
        }
      } catch (e) {
        debugPrint('获取下载目录失败: $e');
      }

      // 如果获取下载目录失败（例如在某些特殊系统或移动端），则回退到应用文档目录
      baseDir ??= await getApplicationDocumentsDirectory();

      _outputDirectory = Directory(path.join(baseDir.path, 'watermark_output'));
    }

    // 确保目录存在
    if (!await _outputDirectory!.exists()) {
      await _outputDirectory!.create(recursive: true);
    }
  }

  /// 设置输出目录
  Future<void> setOutputDirectory(String pathString) async {
    _outputDirectory = Directory(pathString);
    if (!await _outputDirectory!.exists()) {
      await _outputDirectory!.create(recursive: true);
    }

    // 更新现有批处理任务的输出路径
    for (final task in _batchTasks) {
      final outputFileName =
          '${path.basenameWithoutExtension(task.file.path)}_watermark.jpg';
      final newOutputPath = path.join(_outputDirectory!.path, outputFileName);
      // 创建新的任务对象来更新输出路径
      final index = _batchTasks.indexOf(task);
      _batchTasks[index] = BatchProcessTask(
        file: task.file,
        outputPath: newOutputPath,
        status: task.status,
        errorMessage: task.errorMessage,
        progress: task.progress,
      );
    }

    notifyListeners();
  }

  /// 打开输出目录或最后保存的文件
  Future<void> openOutputDirectory() async {
    // On mobile, we can't open a directory or a specific file from gallery.
    // This function will only work on desktop.
    if (_usesDirectoryOutput) {
      if (_outputDirectory != null && await _outputDirectory!.exists()) {
        final directoryPath = _outputDirectory!.path;
        if (Platform.isWindows) {
          await Process.run('explorer', [directoryPath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [directoryPath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [directoryPath]);
        }
      }
    }
  }

  void _disposeIsolatePool() {
    for (final receivePort in _receivePorts) {
      receivePort.close();
    }
    for (final isolate in _isolates) {
      isolate?.kill(priority: Isolate.immediate);
    }
    _receivePorts.clear();
    _isolates.clear();
    _sendPorts.clear();
    _sendPortCompleters.clear();
    _requestQueue.clear();
    _pendingTasks.clear();
    _processingCount = 0;
    _currentIsolateIndex = 0;
    _isolatesInitialized = false;
  }

  /// 根据CPU核心数初始化设置
  void _initCpuBasedSettings() {
    final cpuCores = kIsWeb
        ? 2 // Web doesn't have access to this, default to 2.
        : Platform.numberOfProcessors;

    // Isolate数量 = CPU核心数 / 2，最少1个，最多6个
    _isolateCount = (cpuCores / 2).ceil().clamp(1, 6);

    // 最大并发数 = CPU核心数 - 1，最少1个，最多12个
    _maxConcurrent = (cpuCores - 1).clamp(1, 12);
  }

  /// 初始化多个Isolate
  Future<void> _initializeIsolates() async {
    if (_isolatesInitialized) return;
    _isolatesInitialized = true;

    debugPrint('开始初始化 $_isolateCount 个Isolate');

    for (int i = 0; i < _isolateCount; i++) {
      final receivePort = ReceivePort();
      final completer = Completer<SendPort>();

      _receivePorts.add(receivePort);
      _sendPortCompleters.add(completer);
      _isolates.add(null);
      _sendPorts.add(null);

      final isolate = await Isolate.spawn(
        _watermarkGenerator,
        receivePort.sendPort,
        debugName: 'WatermarkIsolate_$i',
      );
      _isolates[i] = isolate;

      receivePort.listen((dynamic message) {
        if (message is SendPort) {
          _sendPorts[i] = message;
          if (!_sendPortCompleters[i].isCompleted) {
            _sendPortCompleters[i].complete(message);
          }
          debugPrint('Isolate $i SendPort 已准备');
        } else if (message is _WatermarkResult) {
          _handleWatermarkResult(message);
        }
      });
    }

    debugPrint('所有Isolate初始化完成');
  }

  /// 处理水印结果
  void _handleWatermarkResult(_WatermarkResult result) async {
    _processingCount--;
    _pendingTasks.remove(result.inputFile);

    final taskIndex = _batchTasks.indexWhere(
      (t) => t.file.path == result.inputFile,
    );

    if (taskIndex != -1) {
      final task = _batchTasks[taskIndex];
      if (result.success && result.processedBytes != null) {
        try {
          final fileName =
              '${path.basenameWithoutExtension(task.file.path)}_watermark.jpg';

          task.outputPath = await _saveJpgBytes(
            result.processedBytes!,
            fileName,
            preferredOutputPath: task.outputPath,
          );
          task.status = ProcessingStatus.completed;
          task.progress = 1.0;
          debugPrint('任务完成并已保存: ${result.inputFile}');
        } catch (e) {
          task.status = ProcessingStatus.error;
          task.errorMessage = '保存失败: $e';
          debugPrint('任务保存失败: ${result.inputFile}, 错误: $e');
        }
      } else {
        task.status = ProcessingStatus.error;
        task.errorMessage = result.errorMessage ?? '未知处理错误';
        debugPrint('任务失败: ${result.inputFile}, 错误: ${result.errorMessage}');
      }
      _updateOverallProgress();
      notifyListeners();
    }

    // 处理下一个请求
    _processNextRequest();
  }

  @override
  void dispose() {
    // 取消批处理
    _batchProcessingCancelled = true;
    _disposeIsolatePool();

    // 清理图像资源
    _currentImage?.dispose();
    _previewImage?.dispose();

    super.dispose();
  }

  Future<String> _resolveUniqueOutputPath(String preferredPath) async {
    var candidatePath = preferredPath;
    var counter = 1;
    while (await File(candidatePath).exists()) {
      final directory = path.dirname(preferredPath);
      final baseName = path.basenameWithoutExtension(preferredPath);
      final extension = path.extension(preferredPath);
      candidatePath = path.join(directory, '${baseName}_$counter$extension');
      counter++;
    }
    return candidatePath;
  }

  void releaseTransientResources({bool notify = true}) {
    if (isBatchProcessing) {
      return;
    }

    final oldImage = _currentImage;
    final oldPreview = _previewImage;
    _currentImage = null;
    _previewImage = null;
    _needsPreviewGeneration = false;
    _previewStatus = ProcessingStatus.idle;
    _previewErrorMessage = null;
    _saveStatus = ProcessingStatus.idle;
    _saveErrorMessage = null;

    if (oldImage != null) {
      Future.microtask(oldImage.dispose);
    }
    if (oldPreview != null) {
      Future.microtask(oldPreview.dispose);
    }

    if (notify) {
      notifyListeners();
    }
  }
}

/// 信号量类，用于控制并发数量
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
