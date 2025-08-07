import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../photo_watermark_provider.dart';

/// 批处理列表组件
class BatchProcessList extends StatelessWidget {
  const BatchProcessList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.batchTasks.length,
          itemBuilder: (context, index) {
            final task = provider.batchTasks[index];
            return _BatchTaskItem(
              task: task,
              index: index,
              onRemove: () => provider.removeBatchTask(index),
            );
          },
        );
      },
    );
  }
}

/// 批处理任务项
class _BatchTaskItem extends StatelessWidget {
  final BatchProcessTask task;
  final int index;
  final VoidCallback onRemove;

  const _BatchTaskItem({
    required this.task,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        final isSelected =
            provider.currentImage?.sourceFile.path == task.file.path;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : null,
          child: ListTile(
            leading: _buildStatusIcon(),
            title: Text(
              task.file.path.split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isSelected
                  ? TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
            subtitle: _buildSubtitle(),
            trailing: _buildTrailing(),
            onTap: () => _onTap(context, provider),
          ),
        );
      },
    );
  }

  void _onTap(BuildContext context, PhotoWatermarkProvider provider) {
    // 如果正在处理中，不允许切换
    if (provider.status == ProcessingStatus.processing) {
      return;
    }

    // 加载选中的图片进行预览
    provider.loadImage(task.file);
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case ProcessingStatus.idle:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
        );
      case ProcessingStatus.processing:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        );
      case ProcessingStatus.completed:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white, size: 20),
        );
      case ProcessingStatus.error:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.error, color: Colors.white, size: 20),
        );
    }
  }

  Widget? _buildSubtitle() {
    if (task.status == ProcessingStatus.error && task.errorMessage != null) {
      return Text(
        task.errorMessage!,
        style: const TextStyle(color: Colors.red, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (task.status == ProcessingStatus.processing) {
      return LinearProgressIndicator(
        value: task.progress,
        backgroundColor: Colors.grey.shade300,
      );
    }

    if (task.status == ProcessingStatus.completed) {
      return Text(
        '已完成',
        style: TextStyle(color: Colors.green.shade700, fontSize: 12),
      );
    }

    // 显示文件大小
    final file = task.file;
    if (file.existsSync()) {
      final size = file.lengthSync();
      return Text(_formatFileSize(size), style: const TextStyle(fontSize: 12));
    }

    return null;
  }

  Widget _buildTrailing() {
    if (task.status == ProcessingStatus.idle ||
        task.status == ProcessingStatus.error) {
      return IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: onRemove,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
    }

    if (task.status == ProcessingStatus.completed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            onPressed: () => _openOutputFile(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: '打开文件位置',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _openOutputFile() {
    final outputFile = File(task.outputPath);
    if (outputFile.existsSync()) {
      final directory = outputFile.parent.path;
      if (Platform.isWindows) {
        Process.run('explorer', ['/select,', outputFile.path]);
      } else if (Platform.isMacOS) {
        Process.run('open', ['-R', outputFile.path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [directory]);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
