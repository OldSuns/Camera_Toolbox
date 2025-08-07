import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'models/watermark_config.dart';
import 'models/image_container.dart';
import 'services/watermark_processor.dart';

/// 处理状态
enum ProcessingStatus { idle, processing, completed, error }

/// 批处理任务
class BatchProcessTask {
  final File file;
  final String outputPath;
  ProcessingStatus status;
  String? errorMessage;
  double progress;

  BatchProcessTask({
    required this.file,
    required this.outputPath,
    this.status = ProcessingStatus.idle,
    this.errorMessage,
    this.progress = 0.0,
  });
}

/// 照片水印Provider
class PhotoWatermarkProvider extends ChangeNotifier {
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

  // 处理状态
  ProcessingStatus _status = ProcessingStatus.idle;
  ProcessingStatus get status => _status;

  // 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 总体进度
  double _overallProgress = 0.0;
  double get overallProgress => _overallProgress;

  // 输出目录
  Directory? _outputDirectory;
  Directory? get outputDirectory => _outputDirectory;

  // 是否正在处理
  bool get isProcessing => _status == ProcessingStatus.processing;

  // 已完成数量
  int get completedCount =>
      _batchTasks.where((t) => t.status == ProcessingStatus.completed).length;

  // 总任务数
  int get totalCount => _batchTasks.length;

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

  /// 切换Logo位置
  void toggleLogoPosition() {
    LogoPosition newPosition;
    switch (_config.logoPosition) {
      case LogoPosition.leftTextLeft:
        newPosition = LogoPosition.leftTextRight;
        break;
      case LogoPosition.leftTextRight:
        newPosition = LogoPosition.rightTextLeft;
        break;
      case LogoPosition.rightTextLeft:
        newPosition = LogoPosition.rightTextRight;
        break;
      case LogoPosition.rightTextRight:
        newPosition = LogoPosition.leftTextLeft;
        break;
    }

    updateConfig(_config.copyWith(logoPosition: newPosition));
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

  /// 加载单个图像
  Future<void> loadImage(File file) async {
    try {
      _status = ProcessingStatus.processing;
      _errorMessage = null;
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

      _status = ProcessingStatus.idle;
      notifyListeners();
    } catch (e) {
      _status = ProcessingStatus.error;
      _errorMessage = '加载图像失败: $e';
      notifyListeners();
    }
  }

  /// 生成预览
  Future<void> _generatePreview() async {
    if (_currentImage == null) return;

    try {
      final processor = WatermarkProcessorFactory.create(_config);

      // 先生成新的预览图像
      final newPreviewImage = await processor.process(_currentImage!);

      // 然后释放旧的预览图像并设置新的
      final oldPreviewImage = _previewImage;
      _previewImage = newPreviewImage;

      // 延迟释放旧图像，确保UI已经更新
      if (oldPreviewImage != null) {
        Future.microtask(() => oldPreviewImage.dispose());
      }

      notifyListeners();
    } catch (e) {
      // 生成预览失败，记录日志或处理错误
      debugPrint('生成预览失败: $e');
      _status = ProcessingStatus.error;
      _errorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 手动生成预览
  Future<void> generatePreviewManually() async {
    if (_currentImage == null) return;

    try {
      _status = ProcessingStatus.processing;
      _needsPreviewGeneration = false;
      _errorMessage = null;
      notifyListeners();

      final processor = WatermarkProcessorFactory.create(_config);

      // 先生成新的预览图像
      final newPreviewImage = await processor.process(_currentImage!);

      // 然后释放旧的预览图像并设置新的
      final oldPreviewImage = _previewImage;
      _previewImage = newPreviewImage;

      // 延迟释放旧图像，确保UI已经更新
      if (oldPreviewImage != null) {
        Future.microtask(() => oldPreviewImage.dispose());
      }

      _status = ProcessingStatus.idle;
      notifyListeners();
    } catch (e) {
      _status = ProcessingStatus.error;
      _errorMessage = '生成预览失败: $e';
      notifyListeners();
    }
  }

  /// 保存当前图像
  Future<void> saveCurrentImage() async {
    if (_currentImage == null || _previewImage == null) return;

    try {
      _status = ProcessingStatus.processing;
      notifyListeners();

      // 确保输出目录已设置
      await _ensureOutputDirectory();

      // 生成输出文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName =
          '${path.basenameWithoutExtension(_currentImage!.sourceFile.path)}_watermark_$timestamp.jpg';
      final outputPath = path.join(_outputDirectory!.path, outputFileName);

      // 保存为JPG格式
      await _saveImageAsJpg(_previewImage!, outputPath);

      _status = ProcessingStatus.completed;
      notifyListeners();
    } catch (e) {
      _status = ProcessingStatus.error;
      _errorMessage = '保存图像失败: $e';
      notifyListeners();
    }
  }

  /// 添加批处理文件
  Future<void> addBatchFiles(List<File> files) async {
    debugPrint('addBatchFiles 被调用，文件数量: ${files.length}');

    // 确保输出目录已设置，优先使用用户设置的目录
    await _ensureOutputDirectory();

    int addedCount = 0;
    for (final file in files) {
      debugPrint('处理文件: ${file.path}');

      // 检查文件是否存在
      if (!await file.exists()) {
        debugPrint('文件不存在: ${file.path}');
        continue;
      }

      // 检查是否已存在
      if (_batchTasks.any((t) => t.file.path == file.path)) {
        debugPrint('文件已存在于列表中: ${file.path}');
        continue;
      }

      // 生成输出路径
      final outputFileName =
          '${path.basenameWithoutExtension(file.path)}_watermark.jpg';
      final outputPath = path.join(_outputDirectory!.path, outputFileName);

      _batchTasks.add(BatchProcessTask(file: file, outputPath: outputPath));
      addedCount++;
      debugPrint('成功添加文件到批处理列表: ${file.path}');
    }

    debugPrint('总共添加了 $addedCount 个文件到批处理列表');
    debugPrint('当前批处理列表中有 ${_batchTasks.length} 个文件');
    debugPrint('使用输出目录: ${_outputDirectory!.path}');

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
    _batchTasks.clear();
    _overallProgress = 0.0;
    notifyListeners();
  }

  /// 开始批处理
  Future<void> startBatchProcessing() async {
    if (_batchTasks.isEmpty) return;

    try {
      _status = ProcessingStatus.processing;
      _errorMessage = null;
      _overallProgress = 0.0;
      notifyListeners();

      // 确保输出目录已设置
      await _ensureOutputDirectory();

      // 处理每个任务
      for (int i = 0; i < _batchTasks.length; i++) {
        final task = _batchTasks[i];

        if (task.status == ProcessingStatus.completed) {
          continue;
        }

        try {
          task.status = ProcessingStatus.processing;
          notifyListeners();

          // 在Isolate中处理图像
          await _processImageInIsolate(task);

          task.status = ProcessingStatus.completed;
          task.progress = 1.0;
        } catch (e) {
          task.status = ProcessingStatus.error;
          task.errorMessage = e.toString();
        }

        _updateOverallProgress();
        notifyListeners();
      }

      _status = ProcessingStatus.completed;
      notifyListeners();
    } catch (e) {
      _status = ProcessingStatus.error;
      _errorMessage = '批处理失败: $e';
      notifyListeners();
    }
  }

  /// 保存UI图像为JPG格式
  Future<void> _saveImageAsJpg(ui.Image image, String outputPath) async {
    // 获取图像的RGBA数据
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    // 转换为image包的格式
    final imgImage = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: byteData.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );

    // 编码为JPG格式
    final jpgBytes = img.encodeJpg(imgImage, quality: _config.outputQuality);

    // 保存文件
    final file = File(outputPath);
    await file.writeAsBytes(jpgBytes);
  }

  /// 在Isolate中处理图像
  Future<void> _processImageInIsolate(BatchProcessTask task) async {
    // 加载图像
    final container = await ImageContainer.fromFile(task.file);
    container.useEquivalentFocalLength = _config.useEquivalentFocalLength;

    // 处理图像
    final processor = WatermarkProcessorFactory.create(_config);
    final processedImage = await processor.process(container);

    // 保存为JPG格式
    await _saveImageAsJpg(processedImage, task.outputPath);

    // 清理资源
    container.dispose();
    processedImage.dispose();
  }

  /// 更新总体进度
  void _updateOverallProgress() {
    if (_batchTasks.isEmpty) {
      _overallProgress = 0.0;
    } else {
      final completed = _batchTasks
          .where((t) => t.status == ProcessingStatus.completed)
          .length;
      _overallProgress = completed / _batchTasks.length;
    }
  }

  /// 确保输出目录已设置
  Future<void> _ensureOutputDirectory() async {
    if (_outputDirectory == null) {
      // 如果用户没有设置输出目录，使用默认目录
      final appDir = await getApplicationDocumentsDirectory();
      _outputDirectory = Directory(path.join(appDir.path, 'watermark_output'));
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

  /// 打开输出目录
  Future<void> openOutputDirectory() async {
    if (_outputDirectory != null && await _outputDirectory!.exists()) {
      if (Platform.isWindows) {
        await Process.run('explorer', [_outputDirectory!.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [_outputDirectory!.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [_outputDirectory!.path]);
      }
    }
  }

  @override
  void dispose() {
    _currentImage?.dispose();
    _previewImage?.dispose();
    super.dispose();
  }
}
