import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../photo_watermark_provider.dart';
import '../design_tokens.dart';

/// 批处理列表组件 - 优化版，适配右侧固定栏
class BatchProcessList extends StatelessWidget {
  const BatchProcessList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return ListView.builder(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
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

/// 批处理任务项 - 优化版
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

        return AnimatedContainer(
          duration: DesignTokens.animationFast,
          margin: const EdgeInsets.only(bottom: DesignTokens.spacing8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                : DesignTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : DesignTokens.borderColorLight,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? DesignTokens.shadowSmall : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onTap(context, provider),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文件名和状态
                    Row(
                      children: [
                        _buildStatusIcon(),
                        const SizedBox(width: DesignTokens.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.file.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DesignTokens.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : DesignTokens.textPrimary,
                                ),
                              ),
                              if (_buildSubtitleText() != null) ...[
                                const SizedBox(height: DesignTokens.spacing4),
                                Text(
                                  _buildSubtitleText()!,
                                  style: DesignTokens.bodySmall.copyWith(
                                    color: task.status == ProcessingStatus.error
                                        ? Colors.red
                                        : DesignTokens.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spacing8),
                        _buildTrailing(),
                      ],
                    ),
                    // 进度条
                    if (task.status == ProcessingStatus.processing) ...[
                      const SizedBox(height: DesignTokens.spacing8),
                      LinearProgressIndicator(
                        value: task.progress,
                        backgroundColor: DesignTokens.borderColorLight,
                        minHeight: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTap(BuildContext context, PhotoWatermarkProvider provider) {
    // 如果正在处理中，不允许切换
    if (provider.isBatchProcessing) {
      return;
    }

    // 加载选中的图片进行预览
    provider.loadImage(task.file);
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case ProcessingStatus.idle:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: DesignTokens.backgroundTertiary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.hourglass_empty,
            color: DesignTokens.textSecondary,
            size: 16,
          ),
        );
      case ProcessingStatus.processing:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ProcessingStatus.completed:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        );
      case ProcessingStatus.error:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error, color: Colors.red, size: 20),
        );
    }
  }

  String? _buildSubtitleText() {
    if (task.status == ProcessingStatus.error && task.errorMessage != null) {
      return task.errorMessage!;
    }

    if (task.status == ProcessingStatus.completed) {
      return '已完成';
    }

    // 显示文件大小
    final file = task.file;
    if (file.existsSync()) {
      final size = file.lengthSync();
      return _formatFileSize(size);
    }

    return null;
  }

  Widget _buildTrailing() {
    if (task.status == ProcessingStatus.idle ||
        task.status == ProcessingStatus.error) {
      return IconButton(
        icon: Icon(Icons.close, size: 18, color: DesignTokens.textTertiary),
        onPressed: onRemove,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: '移除',
      );
    }

    if (task.status == ProcessingStatus.completed) {
      return SizedBox(
        width: 72, // 固定宽度以避免溢出
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: (Platform.isAndroid || Platform.isIOS)
                  ? null
                  : () => _openOutputFile(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.folder_open,
                  size: 18,
                  color: (Platform.isAndroid || Platform.isIOS)
                      ? DesignTokens.textTertiary
                      : DesignTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: DesignTokens.textTertiary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox(width: 32, height: 32);
  }

  void _openOutputFile() {
    // This should only be called on desktop.
    if (task.outputPath == null) return;
    final outputFile = File(task.outputPath!);
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
