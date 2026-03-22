import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/responsive_layout.dart';
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

  // 响应式布局断点
  static const double kDesktopLayoutBreakpoint = 800.0;

  Future<void> _pickFiles({bool multiple = false}) async {
    if (!mounted) return;
    final provider = context.read<PhotoWatermarkProvider>();
    List<File> files = [];

    // Mobile-specific logic using image_picker for a native gallery experience
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final picker = ImagePicker();
      if (multiple) {
        final List<XFile> images = await picker.pickMultiImage();
        files = images.map((xfile) => File(xfile.path)).toList();
      } else {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          files.add(File(image.path));
        }
      }
    }
    // Desktop-specific logic using file_picker
    else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
        allowMultiple: multiple,
      );
      if (result != null && result.files.isNotEmpty) {
        files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
      }
    }

    if (!mounted || files.isEmpty) return;

    if (multiple) {
      await provider.addBatchFiles(files);
    } else {
      await provider.loadImage(files.first);
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
    final hasBatchTasks = context.select<PhotoWatermarkProvider, bool>(
      (provider) => provider.batchTasks.isNotEmpty,
    );
    final tabCount = hasBatchTasks ? 3 : 2;

    return StableWidthBuilder<bool>(
      resolve: (width) => width > kDesktopLayoutBreakpoint,
      cacheKey: (tabCount, _isDragging, _isRightPanelCollapsed),
      builder: (context, isDesktop) {
        return DefaultTabController(
          key: ValueKey<int>(tabCount),
          length: tabCount,
          child: Scaffold(
            backgroundColor: DesignTokens.backgroundPrimary,
            appBar: AppBar(
              title: const Text('照片边框水印'),
              elevation: 0,
              backgroundColor: DesignTokens.backgroundSecondary,
              actions: [
                if (Platform.isWindows ||
                    Platform.isMacOS ||
                    Platform.isLinux) ...[
                  _PhotoWatermarkOutputDirectoryButton(
                    onPressed: _pickOutputDirectory,
                  ),
                  const SizedBox(width: DesignTokens.spacing8),
                  IconButton(
                    onPressed: () {
                      context
                          .read<PhotoWatermarkProvider>()
                          .openOutputDirectory();
                    },
                    icon: const Icon(Icons.launch),
                    tooltip: '打开输出目录',
                  ),
                ],
                const SizedBox(width: DesignTokens.spacing16),
              ],
              bottom: isDesktop
                  ? null
                  : TabBar(
                      tabs: [
                        const Tab(icon: Icon(Icons.settings), text: '设置'),
                        const Tab(icon: Icon(Icons.preview), text: '预览'),
                        if (hasBatchTasks)
                          const Tab(icon: Icon(Icons.view_list), text: '批处理'),
                      ],
                    ),
            ),
            body: DropTarget(
              onDragDone: (details) async {
                debugPrint('拖拽文件数量: ${details.files.length}');
                final files = details.files
                    .where((f) {
                      final extension = f.path.toLowerCase();
                      return extension.endsWith('.jpg') ||
                          extension.endsWith('.jpeg') ||
                          extension.endsWith('.png') ||
                          extension.endsWith('.heic') ||
                          extension.endsWith('.heif');
                    })
                    .map((f) => File(f.path))
                    .toList();
                if (files.isNotEmpty && mounted) {
                  final provider = context.read<PhotoWatermarkProvider>();
                  if (files.length == 1) {
                    await provider.loadImage(files.first);
                  } else {
                    await provider.addBatchFiles(files);
                  }
                }
              },
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              child: Stack(
                children: [
                  isDesktop
                      ? _buildDesktopLayout(hasBatchTasks: hasBatchTasks)
                      : _buildMobileLayout(hasBatchTasks),
                  if (_isDragging) const _PhotoWatermarkDragOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建桌面端布局
  Widget _buildDesktopLayout({required bool hasBatchTasks}) {
    return Row(
      children: [
        // 左侧：设置面板
        _buildLeftPanel(),
        // 中间：预览区域
        Expanded(flex: 2, child: _buildCenterPanel()),
        // 收起/展开按钮
        _buildCollapseButton(hasBatchTasks: hasBatchTasks),
        // 右侧：批处理队列
        _buildRightPanel(hasBatchTasks: hasBatchTasks),
      ],
    );
  }

  /// 构建移动端布局
  Widget _buildMobileLayout(bool hasBatchTasks) {
    final List<Widget> children = [
      _buildLeftPanel(isMobile: true),
      _buildCenterPanel(),
      if (hasBatchTasks) _buildRightPanel(isMobile: true, hasBatchTasks: true),
    ];
    return TabBarView(children: children);
  }

  /// 构建左侧设置面板
  Widget _buildLeftPanel({bool isMobile = false}) {
    final panelContent = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: DesignTokens.borderColorLight),
            ),
          ),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickFiles(multiple: false),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('选择图片'),
                style: DesignTokens.primaryButtonStyle,
              ),
              const SizedBox(height: DesignTokens.spacing8),
              OutlinedButton.icon(
                onPressed: () => _pickFiles(multiple: true),
                icon: const Icon(Icons.collections),
                label: const Text('批量添加'),
                style: DesignTokens.secondaryButtonStyle,
              ),
            ],
          ),
        ),
        const Expanded(child: WatermarkSettings()),
        const _PhotoWatermarkActionPanel(),
      ],
    );

    if (isMobile) {
      return panelContent;
    }

    return Container(
      width: DesignTokens.sidebarWidth,
      decoration: BoxDecoration(
        color: DesignTokens.backgroundSecondary,
        border: Border(right: BorderSide(color: DesignTokens.borderColorLight)),
      ),
      child: panelContent,
    );
  }

  /// 构建中间预览面板
  Widget _buildCenterPanel() {
    return Container(
      color: DesignTokens.backgroundPrimary,
      child: Selector<PhotoWatermarkProvider, bool>(
        selector: (context, provider) => provider.currentImage != null,
        builder: (context, hasCurrentImage, _) {
          if (hasCurrentImage) {
            return const RepaintBoundary(child: WatermarkPreview());
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
    );
  }

  /// 构建收起/展开按钮
  Widget _buildCollapseButton({required bool hasBatchTasks}) {
    if (!hasBatchTasks) {
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
              _isRightPanelCollapsed ? Icons.chevron_left : Icons.chevron_right,
              size: 16,
              color: DesignTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建右侧批处理面板
  Widget _buildRightPanel({
    bool isMobile = false,
    required bool hasBatchTasks,
  }) {
    if (!hasBatchTasks) {
      return const SizedBox.shrink();
    }

    final panelContent = const Column(
      children: [
        _PhotoWatermarkBatchPanelHeader(),
        Expanded(child: BatchProcessList()),
      ],
    );

    if (isMobile) {
      return panelContent;
    }

    return AnimatedContainer(
      duration: DesignTokens.animationFast,
      width: !_isRightPanelCollapsed ? DesignTokens.rightPanelWidth : 0,
      decoration: BoxDecoration(
        color: DesignTokens.backgroundSecondary,
        border: Border(left: BorderSide(color: DesignTokens.borderColorLight)),
      ),
      child: panelContent,
    );
  }
}

class _PhotoWatermarkOutputDirectoryButton extends StatelessWidget {
  const _PhotoWatermarkOutputDirectoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.select<PhotoWatermarkProvider, String>((provider) {
      return provider.outputDirectory?.path
              .split(Platform.pathSeparator)
              .last ??
          '选择输出目录';
    });

    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.folder_open),
      label: Text(
        label,
        style: DesignTokens.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PhotoWatermarkActionPanel extends StatelessWidget {
  const _PhotoWatermarkActionPanel();

  @override
  Widget build(BuildContext context) {
    final panelState = context
        .select<
          PhotoWatermarkProvider,
          ({
            bool hasCurrentImage,
            bool needsPreviewGeneration,
            bool hasPreviewImage,
            ProcessingStatus status,
            String? errorMessage,
          })
        >((provider) {
          return (
            hasCurrentImage: provider.currentImage != null,
            needsPreviewGeneration: provider.needsPreviewGeneration,
            hasPreviewImage: provider.previewImage != null,
            status: provider.status,
            errorMessage: provider.errorMessage,
          );
        });
    final provider = context.read<PhotoWatermarkProvider>();
    final isGenerating =
        panelState.status == ProcessingStatus.processing &&
        !panelState.needsPreviewGeneration;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: DesignTokens.borderColorLight)),
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed:
                panelState.hasCurrentImage &&
                    panelState.needsPreviewGeneration &&
                    panelState.status != ProcessingStatus.processing
                ? provider.generatePreviewManually
                : null,
            icon: isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.visibility),
            label: Text(isGenerating ? '生成中...' : '生成预览'),
            style: DesignTokens.primaryButtonStyle,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          ElevatedButton.icon(
            onPressed:
                panelState.hasCurrentImage &&
                    panelState.hasPreviewImage &&
                    panelState.status != ProcessingStatus.processing
                ? provider.saveCurrentImage
                : null,
            icon: panelState.status == ProcessingStatus.processing
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
              panelState.status == ProcessingStatus.processing
                  ? '处理中...'
                  : '保存图片',
            ),
            style: DesignTokens.primaryButtonStyle.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey;
                }
                return Colors.green;
              }),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          if (panelState.status == ProcessingStatus.error &&
              panelState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '错误: ${panelState.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else if (panelState.status == ProcessingStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '操作成功!',
                style: TextStyle(color: Colors.green[700], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoWatermarkBatchPanelHeader extends StatelessWidget {
  const _PhotoWatermarkBatchPanelHeader();

  @override
  Widget build(BuildContext context) {
    final headerState = context
        .select<
          PhotoWatermarkProvider,
          ({
            int taskCount,
            int completedCount,
            int totalCount,
            double overallProgress,
            ProcessingStatus status,
          })
        >((provider) {
          return (
            taskCount: provider.batchTasks.length,
            completedCount: provider.completedCount,
            totalCount: provider.totalCount,
            overallProgress: provider.overallProgress,
            status: provider.status,
          );
        });
    final provider = context.read<PhotoWatermarkProvider>();

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DesignTokens.borderColorLight),
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
                '${headerState.taskCount} 个文件',
                style: DesignTokens.bodySmall.copyWith(
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          if (headerState.status == ProcessingStatus.processing) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '进度: ${headerState.completedCount} / ${headerState.totalCount}',
                  style: DesignTokens.bodySmall,
                ),
                Text(
                  '${(headerState.overallProgress * 100).toInt()}%',
                  style: DesignTokens.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing8),
            LinearProgressIndicator(
              value: headerState.overallProgress,
              backgroundColor: DesignTokens.borderColorLight,
            ),
            const SizedBox(height: DesignTokens.spacing12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: headerState.taskCount > 0
                      ? provider.clearBatchTasks
                      : null,
                  icon: const Icon(Icons.clear_all, size: 20),
                  label: const Text('清空'),
                  style: DesignTokens.secondaryButtonStyle.copyWith(
                    minimumSize: WidgetStateProperty.all(const Size(0, 36)),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      headerState.taskCount > 0 &&
                          headerState.status != ProcessingStatus.processing
                      ? provider.startBatchProcessing
                      : null,
                  icon: headerState.status == ProcessingStatus.processing
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
                    headerState.status == ProcessingStatus.processing
                        ? '处理中'
                        : '开始',
                  ),
                  style: DesignTokens.primaryButtonStyle.copyWith(
                    minimumSize: WidgetStateProperty.all(const Size(0, 36)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoWatermarkDragOverlay extends StatelessWidget {
  const _PhotoWatermarkDragOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withAlpha(25),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.spacing32),
          decoration: BoxDecoration(
            color: DesignTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
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
              const Text('释放以添加图片', style: DesignTokens.headingMedium),
            ],
          ),
        ),
      ),
    );
  }
}
