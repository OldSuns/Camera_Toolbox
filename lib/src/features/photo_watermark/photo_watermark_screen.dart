import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'photo_watermark_provider.dart';
import 'widgets/watermark_preview.dart';
import 'widgets/watermark_settings.dart';
import 'widgets/batch_process_list.dart';
import 'design_tokens.dart';

/// 照片水印主界面 - 三栏布局
class PhotoWatermarkScreen extends StatefulWidget {
  const PhotoWatermarkScreen({super.key});

  @override
  State<PhotoWatermarkScreen> createState() => _PhotoWatermarkScreenState();
}

class _PhotoWatermarkScreenState extends State<PhotoWatermarkScreen> {
  bool _isDragging = false;
  bool _isRightPanelCollapsed = false; // 右侧面板是否收起

  Future<void> _pickFiles({bool multiple = false}) async {
    if (!mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
      allowMultiple: multiple,
    );

    if (result != null && result.files.isNotEmpty) {
      if (!mounted) return;
      final provider = context.read<PhotoWatermarkProvider>();

      if (multiple) {
        // 批处理模式
        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
        await provider.addBatchFiles(files);
      } else {
        // 单个文件模式
        final file = File(result.files.first.path!);
        await provider.loadImage(file);
      }
    }
  }

  Future<void> _pickOutputDirectory() async {
    if (!mounted) return;

    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      if (!mounted) return;
      context.read<PhotoWatermarkProvider>().setOutputDirectory(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundPrimary,
      appBar: AppBar(
        title: const Text('照片边框水印'),
        elevation: 0,
        backgroundColor: DesignTokens.backgroundSecondary,
        actions: [
          // 输出目录按钮
          Consumer<PhotoWatermarkProvider>(
            builder: (context, provider, _) {
              return TextButton.icon(
                onPressed: _pickOutputDirectory,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  provider.outputDirectory?.path
                          .split(Platform.pathSeparator)
                          .last ??
                      '选择输出目录',
                  style: DesignTokens.bodySmall,
                ),
              );
            },
          ),
          const SizedBox(width: DesignTokens.spacing8),
          // 打开输出目录
          IconButton(
            onPressed: () {
              context.read<PhotoWatermarkProvider>().openOutputDirectory();
            },
            icon: const Icon(Icons.launch),
            tooltip: '打开输出目录',
          ),
          const SizedBox(width: DesignTokens.spacing16),
        ],
      ),
      body: DropTarget(
        onDragDone: (details) async {
          debugPrint('拖拽文件数量: ${details.files.length}');

          final files = details.files
              .where((f) {
                final extension = f.path.toLowerCase();
                final isValidImage =
                    extension.endsWith('.jpg') ||
                    extension.endsWith('.jpeg') ||
                    extension.endsWith('.png') ||
                    extension.endsWith('.heic') ||
                    extension.endsWith('.heif');
                debugPrint('文件: ${f.path}, 是否有效图片: $isValidImage');
                return isValidImage;
              })
              .map((f) => File(f.path))
              .toList();

          debugPrint('有效图片文件数量: ${files.length}');

          if (files.isNotEmpty && mounted) {
            final provider = context.read<PhotoWatermarkProvider>();
            if (files.length == 1) {
              // 单张处理
              debugPrint('加载单张图片: ${files.first.path}');
              await provider.loadImage(files.first);
            } else {
              // 批量处理
              debugPrint('添加批量文件');
              await provider.addBatchFiles(files);
            }
          }
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            // 三栏布局
            Row(
              children: [
                // 左侧：设置面板
                _buildLeftPanel(),
                // 中间：预览区域
                _buildCenterPanel(),
                // 收起/展开按钮
                _buildCollapseButton(),
                // 右侧：批处理队列
                _buildRightPanel(),
              ],
            ),
            // 拖放提示
            if (_isDragging)
              Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spacing32),
                    decoration: BoxDecoration(
                      color: DesignTokens.backgroundSecondary,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusXLarge,
                      ),
                      boxShadow: DesignTokens.shadowXLarge,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        const Text(
                          '释放以添加图片',
                          style: DesignTokens.headingMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建左侧设置面板
  Widget _buildLeftPanel() {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return Container(
          width: DesignTokens.sidebarWidth,
          decoration: BoxDecoration(
            color: DesignTokens.backgroundSecondary,
            border: Border(
              right: BorderSide(color: DesignTokens.borderColorLight),
            ),
          ),
          child: Column(
            children: [
              // 工具栏
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: DesignTokens.borderColorLight),
                  ),
                ),
                child: Column(
                  children: [
                    // 选择图片按钮
                    ElevatedButton.icon(
                      onPressed: () => _pickFiles(multiple: false),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('选择图片'),
                      style: DesignTokens.primaryButtonStyle,
                    ),
                    const SizedBox(height: DesignTokens.spacing8),
                    // 添加批量按钮
                    OutlinedButton.icon(
                      onPressed: () => _pickFiles(multiple: true),
                      icon: const Icon(Icons.collections),
                      label: const Text('批量添加'),
                      style: DesignTokens.secondaryButtonStyle,
                    ),
                  ],
                ),
              ),
              // 设置面板
              const Expanded(child: WatermarkSettings()),
              // 底部操作按钮
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: DesignTokens.borderColorLight),
                  ),
                ),
                child: Column(
                  children: [
                    // 预览按钮
                    ElevatedButton.icon(
                      onPressed:
                          provider.currentImage != null &&
                              provider.needsPreviewGeneration &&
                              provider.status != ProcessingStatus.processing
                          ? () => provider.generatePreviewManually()
                          : null,
                      icon:
                          provider.status == ProcessingStatus.processing &&
                              !provider.needsPreviewGeneration
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.visibility),
                      label: Text(
                        provider.status == ProcessingStatus.processing &&
                                !provider.needsPreviewGeneration
                            ? '生成中...'
                            : '生成预览',
                      ),
                      style: DesignTokens.primaryButtonStyle,
                    ),
                    const SizedBox(height: DesignTokens.spacing12),
                    // 保存按钮
                    ElevatedButton.icon(
                      onPressed:
                          provider.currentImage != null &&
                              provider.previewImage != null &&
                              provider.status != ProcessingStatus.processing
                          ? () => provider.saveCurrentImage()
                          : null,
                      icon: provider.status == ProcessingStatus.processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        provider.status == ProcessingStatus.processing
                            ? '处理中...'
                            : '保存图片',
                      ),
                      style: DesignTokens.primaryButtonStyle.copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.disabled)) {
                            return Colors.grey;
                          }
                          return Colors.green;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建中间预览面板
  Widget _buildCenterPanel() {
    return Expanded(
      flex: 2,
      child: Container(
        color: DesignTokens.backgroundPrimary,
        child: Consumer<PhotoWatermarkProvider>(
          builder: (context, provider, _) {
            if (provider.currentImage != null) {
              return const WatermarkPreview();
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 128,
                    color: DesignTokens.textTertiary,
                  ),
                  const SizedBox(height: DesignTokens.spacing24),
                  Text(
                    '拖放图片到此处或点击选择',
                    style: DesignTokens.headingMedium.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                  OutlinedButton.icon(
                    onPressed: () => _pickFiles(multiple: false),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('浏览文件'),
                    style: DesignTokens.secondaryButtonStyle.copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size(160, DesignTokens.buttonHeight),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建收起/展开按钮
  Widget _buildCollapseButton() {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        // 只有当有批处理任务时才显示按钮
        if (provider.batchTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: 24,
          decoration: BoxDecoration(
            color: DesignTokens.backgroundSecondary,
            border: Border(
              left: BorderSide(color: DesignTokens.borderColorLight),
              right: BorderSide(color: DesignTokens.borderColorLight),
            ),
          ),
          child: Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isRightPanelCollapsed = !_isRightPanelCollapsed;
                });
              },
              child: Container(
                height: 80,
                width: 24,
                decoration: BoxDecoration(
                  color: DesignTokens.backgroundTertiary,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Icon(
                  _isRightPanelCollapsed
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  size: 16,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建右侧批处理面板
  Widget _buildRightPanel() {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return AnimatedContainer(
          duration: DesignTokens.animationFast,
          width: provider.batchTasks.isNotEmpty && !_isRightPanelCollapsed
              ? DesignTokens.rightPanelWidth
              : 0,
          decoration: BoxDecoration(
            color: DesignTokens.backgroundSecondary,
            border: Border(
              left: BorderSide(color: DesignTokens.borderColorLight),
            ),
          ),
          child: provider.batchTasks.isNotEmpty
              ? Column(
                  children: [
                    // 批处理工具栏
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacing16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: DesignTokens.borderColorLight,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('批处理队列', style: DesignTokens.headingSmall),
                              Text(
                                '${provider.batchTasks.length} 个文件',
                                style: DesignTokens.bodySmall.copyWith(
                                  color: DesignTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spacing12),
                          // 进度信息
                          if (provider.status ==
                              ProcessingStatus.processing) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '进度: ${provider.completedCount} / ${provider.totalCount}',
                                  style: DesignTokens.bodySmall,
                                ),
                                Text(
                                  '${(provider.overallProgress * 100).toInt()}%',
                                  style: DesignTokens.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: DesignTokens.spacing8),
                            LinearProgressIndicator(
                              value: provider.overallProgress,
                              backgroundColor: DesignTokens.borderColorLight,
                            ),
                            const SizedBox(height: DesignTokens.spacing12),
                          ],
                          // 操作按钮
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: provider.batchTasks.isNotEmpty
                                      ? () => provider.clearBatchTasks()
                                      : null,
                                  icon: const Icon(Icons.clear_all, size: 20),
                                  label: const Text('清空'),
                                  style: DesignTokens.secondaryButtonStyle
                                      .copyWith(
                                        minimumSize: WidgetStateProperty.all(
                                          const Size(0, 36),
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spacing8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      provider.batchTasks.isNotEmpty &&
                                          provider.status !=
                                              ProcessingStatus.processing
                                      ? () => provider.startBatchProcessing()
                                      : null,
                                  icon:
                                      provider.status ==
                                          ProcessingStatus.processing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.play_arrow, size: 20),
                                  label: Text(
                                    provider.status ==
                                            ProcessingStatus.processing
                                        ? '处理中'
                                        : '开始',
                                  ),
                                  style: DesignTokens.primaryButtonStyle
                                      .copyWith(
                                        minimumSize: WidgetStateProperty.all(
                                          const Size(0, 36),
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 批处理文件列表
                    const Expanded(child: BatchProcessList()),
                  ],
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
