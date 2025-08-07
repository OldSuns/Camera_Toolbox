import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'photo_watermark_provider.dart';
import 'widgets/watermark_preview.dart';
import 'widgets/watermark_settings.dart';
import 'widgets/batch_process_list.dart';

/// 照片水印主界面
class PhotoWatermarkScreen extends StatefulWidget {
  const PhotoWatermarkScreen({super.key});

  @override
  State<PhotoWatermarkScreen> createState() => _PhotoWatermarkScreenState();
}

class _PhotoWatermarkScreenState extends State<PhotoWatermarkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        if (mounted) {
          _tabController.animateTo(1); // 切换到批处理标签
        }
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
      appBar: AppBar(
        title: const Text('照片边框水印'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '单张处理', icon: Icon(Icons.photo)),
            Tab(text: '批量处理', icon: Icon(Icons.photo_library)),
          ],
        ),
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
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // 打开输出目录
          IconButton(
            onPressed: () {
              context.read<PhotoWatermarkProvider>().openOutputDirectory();
            },
            icon: const Icon(Icons.launch),
            tooltip: '打开输出目录',
          ),
          const SizedBox(width: 16),
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
            if (_tabController.index == 0 && files.length == 1) {
              // 单张处理
              debugPrint('加载单张图片: ${files.first.path}');
              await provider.loadImage(files.first);
            } else {
              // 批量处理
              debugPrint('添加批量文件');
              await provider.addBatchFiles(files);
              if (mounted) {
                _tabController.animateTo(1);
              }
            }
          }
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                // 单张处理标签页
                _buildSingleProcessTab(),
                // 批量处理标签页
                _buildBatchProcessTab(),
              ],
            ),
            // 拖放提示
            if (_isDragging)
              Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text('释放以添加图片', style: TextStyle(fontSize: 18)),
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

  Widget _buildSingleProcessTab() {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            // 左侧设置面板
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: [
                  // 选择图片按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _pickFiles(multiple: false),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('选择图片'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // 设置面板
                  const Expanded(child: WatermarkSettings()),
                  const Divider(height: 1),
                  // 预览和保存按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 预览按钮
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                provider.currentImage != null &&
                                    provider.needsPreviewGeneration &&
                                    provider.status !=
                                        ProcessingStatus.processing
                                ? () => provider.generatePreviewManually()
                                : null,
                            icon:
                                provider.status ==
                                        ProcessingStatus.processing &&
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
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 保存按钮
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                provider.currentImage != null &&
                                    provider.previewImage != null &&
                                    provider.status !=
                                        ProcessingStatus.processing
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
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 右侧预览区域
            Expanded(
              child: provider.currentImage != null
                  ? const WatermarkPreview()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 128,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '拖放图片到此处或点击选择',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(context).disabledColor,
                                ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _pickFiles(multiple: false),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('浏览文件'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBatchProcessTab() {
    return Consumer<PhotoWatermarkProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            // 左侧设置面板（与单张处理共享）
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: [
                  // 批量处理工具栏
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 添加文件按钮
                        ElevatedButton.icon(
                          onPressed: () => _pickFiles(multiple: true),
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('添加图片'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 清空和开始处理按钮
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: provider.batchTasks.isNotEmpty
                                    ? () => provider.clearBatchTasks()
                                    : null,
                                icon: const Icon(Icons.clear_all),
                                label: const Text('清空'),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                    : const Icon(Icons.play_arrow),
                                label: Text(
                                  provider.status == ProcessingStatus.processing
                                      ? '处理中'
                                      : '开始',
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 进度信息
                        if (provider.batchTasks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '进度: ${provider.completedCount} / ${provider.totalCount}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${(provider.overallProgress * 100).toInt()}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: provider.overallProgress,
                            backgroundColor: Theme.of(context).dividerColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 共享的设置面板
                  const Expanded(child: WatermarkSettings()),
                ],
              ),
            ),
            // 右侧内容区域
            Expanded(
              child: Column(
                children: [
                  // 上半部分：预览区域
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: provider.currentImage != null
                          ? const WatermarkPreview()
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 64,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '选择列表中的图片查看预览',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).disabledColor,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  // 下半部分：批处理文件列表
                  Expanded(
                    flex: 1,
                    child: provider.batchTasks.isNotEmpty
                        ? const BatchProcessList()
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.collections_outlined,
                                  size: 64,
                                  color: Theme.of(context).disabledColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '拖放多个图片到此处或点击添加',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context).disabledColor,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _pickFiles(multiple: true),
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('选择多个图片'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
