import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/services/file_selector_service.dart';
import '../../shared/utils/conflict_action.dart';
import '../../shared/widgets/feature_page_layout.dart';
import 'quick_split_exception.dart';
import 'quick_split_service.dart';

/// 快速分片页面 - 根据JPG文件匹配并拷贝同名RAW文件
class QuickSplitScreen extends StatefulWidget {
  const QuickSplitScreen({super.key});

  @override
  State<QuickSplitScreen> createState() => _QuickSplitScreenState();
}

class _QuickSplitScreenState extends State<QuickSplitScreen> {
  String? _jpgDirectory;
  String? _rawDirectory;
  String? _outputDirectory;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = '准备就绪';
  ReceivePort? _receivePort;
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  bool _cancelRequested = false;

  static const String _messageTypeReady = 'ready';
  static const String _messageTypeProgress = 'progress';
  static const String _messageTypeDone = 'done';
  static const String _messageTypeCancelled = 'cancelled';
  static const String _messageTypeError = 'error';
  static const String _commandTypeCancel = 'cancel';

  @override
  void dispose() {
    _disposeWorker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageLayout(
      title: '快速分片',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpDialog,
          tooltip: '帮助',
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDirectorySelector(
              title: '图片输入目录',
              directory: _jpgDirectory,
              onSelect: (path) => setState(() => _jpgDirectory = path),
              icon: Icons.image,
            ),
            const SizedBox(height: 16),
            _buildDirectorySelector(
              title: 'RAW文件输入目录',
              directory: _rawDirectory,
              onSelect: (path) => setState(() => _rawDirectory = path),
              icon: Icons.camera,
            ),
            const SizedBox(height: 16),
            _buildDirectorySelector(
              title: '输出目录',
              directory: _outputDirectory,
              onSelect: (path) => setState(() => _outputDirectory = path),
              icon: Icons.folder_open,
            ),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildProgressSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorySelector({
    required String title,
    required String? directory,
    required Function(String) onSelect,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    directory ?? '未选择目录',
                    style: TextStyle(
                      color: directory != null ? Colors.black87 : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _selectDirectory(onSelect),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('浏览'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _canStartProcessing() && !_isProcessing
                ? _startProcessing
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始分片'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? _cancelProcessing : null,
            icon: const Icon(Icons.stop),
            label: const Text('取消'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    if (!_isProcessing) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: _progress, minHeight: 8),
            const SizedBox(height: 8),
            Text(_statusText, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  bool _canStartProcessing() {
    return _jpgDirectory != null &&
        _rawDirectory != null &&
        _outputDirectory != null;
  }

  Future<void> _selectDirectory(Function(String) onSelect) async {
    try {
      // 在选择目录前请求权限
      final bool isGranted = await _requestStoragePermission();
      if (!isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('存储权限被拒绝，无法选择目录')));
        }
        return;
      }

      final directory = await FileSelectorService.selectDirectory();
      if (directory != null) {
        onSelect(directory);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择目录失败: ${e.toString()}')));
      }
    }
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // 请求所有文件访问权限
      final PermissionStatus status = await Permission.manageExternalStorage
          .request();
      return status.isGranted;
    } else {
      // 对于非安卓平台，默认拥有权限
      return true;
    }
  }

  Future<void> _startProcessing() async {
    if (!_canStartProcessing()) return;

    final conflictAction = await _showConflictDialog();
    if (conflictAction == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusText = '正在初始化...';
    });

    _disposeWorker();
    _cancelRequested = false;
    final receivePort = ReceivePort();
    _receivePort = receivePort;
    final isolate = await Isolate.spawn(_processingIsolate, {
      'sendPort': receivePort.sendPort,
      'jpgDirectory': _jpgDirectory!,
      'rawDirectory': _rawDirectory!,
      'outputDirectory': _outputDirectory!,
      'conflictAction': conflictAction,
    });
    _workerIsolate = isolate;

    receivePort.listen((data) {
      if (data is! Map) {
        return;
      }

      final type = data['type'];
      switch (type) {
        case _messageTypeReady:
          _workerSendPort = data['sendPort'] as SendPort?;
          if (_cancelRequested) {
            _workerSendPort?.send({'type': _commandTypeCancel});
          }
          break;
        case _messageTypeProgress:
          final processed = data['processed'] as int;
          final total = data['total'] as int;
          if (mounted) {
            setState(() {
              _progress = total > 0 ? processed / total : 0.0;
              _statusText = '处理中... $processed/$total';
            });
          }
          break;
        case _messageTypeDone:
          if (mounted) {
            setState(() {
              _statusText = '处理完成！';
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('快速分片处理完成！'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _disposeWorker();
          break;
        case _messageTypeCancelled:
          if (mounted) {
            setState(() {
              _statusText = '已取消';
              _isProcessing = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('快速分片已取消')));
          }
          _disposeWorker();
          break;
        case _messageTypeError:
          if (mounted) {
            _showErrorDialog('处理失败', (data['message'] as String?) ?? '发生未知错误');
            setState(() => _isProcessing = false);
          }
          _disposeWorker();
          break;
      }
    });
  }

  Future<ConflictAction?> _showConflictDialog() async {
    return showDialog<ConflictAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件冲突处理'),
        content: const Text('当输出目录中已存在同名文件时，您希望如何处理？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictAction.skip),
            child: const Text('跳过'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictAction.rename),
            child: const Text('重命名'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ConflictAction.overwrite),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }

  void _cancelProcessing() {
    _cancelRequested = true;
    _workerSendPort?.send({'type': _commandTypeCancel});
    setState(() {
      _statusText = '正在取消...';
    });
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _disposeWorker() {
    _receivePort?.close();
    _receivePort = null;
    _workerSendPort = null;
    _cancelRequested = false;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速分片帮助'),
        content: const SingleChildScrollView(
          child: Text(
            '快速分片功能可以根据图片文件名，自动匹配并拷贝同名的RAW文件到指定目录。\n\n'
            '使用步骤：\n'
            '1. 选择包含图片文件的目录 (JPG/HEIF)\n'
            '2. 选择包含RAW文件的目录\n'
            '3. 选择输出目录\n'
            '4. 点击"开始分片"即可自动处理\n\n'
            '支持的文件类型：\n'
            '• JPG/JPEG: .jpg, .jpeg\n'
            '• HEIF/HEIC: .heif, .heic\n'
            '• RAW格式：\n'
            '  - Canon: .cr2, .cr3\n'
            '  - Nikon: .nef\n'
            '  - Sony: .arw\n'
            '  - Adobe: .dng\n'
            '  - Fujifilm: .raf\n'
            '  - Olympus: .orf\n'
            '  - Panasonic: .rw2\n'
            '  - Pentax: .pef\n'
            '  - Samsung: .sr2\n'
            '  - 通用: .raw\n\n'
            '注意：文件名必须完全匹配（不含扩展名）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}

/// Isolate 入口点，用于处理文件操作
void _processingIsolate(Map<String, dynamic> context) async {
  final sendPort = context['sendPort'] as SendPort;
  final jpgDirectory = context['jpgDirectory'] as String;
  final rawDirectory = context['rawDirectory'] as String;
  final outputDirectory = context['outputDirectory'] as String;
  final conflictAction = context['conflictAction'] as ConflictAction;

  final quickSplitService = QuickSplitService();
  final controlPort = ReceivePort();
  sendPort.send({
    'type': _QuickSplitScreenState._messageTypeReady,
    'sendPort': controlPort.sendPort,
  });

  controlPort.listen((dynamic message) {
    if (message is Map<String, dynamic> &&
        message['type'] == _QuickSplitScreenState._commandTypeCancel) {
      quickSplitService.cancel();
    }
  });

  try {
    await quickSplitService.processFiles(
      imageDirectory: jpgDirectory,
      rawDirectory: rawDirectory,
      outputDirectory: outputDirectory,
      conflictAction: conflictAction,
      onProgress: (processed, total) {
        sendPort.send({
          'type': _QuickSplitScreenState._messageTypeProgress,
          'processed': processed,
          'total': total,
        });
      },
    );
    sendPort.send({'type': _QuickSplitScreenState._messageTypeDone});
  } on QuickSplitCancelledException {
    sendPort.send({'type': _QuickSplitScreenState._messageTypeCancelled});
  } catch (e) {
    sendPort.send({
      'type': _QuickSplitScreenState._messageTypeError,
      'message': e.toString(),
    });
  } finally {
    controlPort.close();
  }
}
