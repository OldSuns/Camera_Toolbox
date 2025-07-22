import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'local_picker_provider.dart';

class LocalPickerScreen extends StatefulWidget {
  const LocalPickerScreen({super.key});

  @override
  State<LocalPickerScreen> createState() => _LocalPickerScreenState();
}

class _LocalPickerScreenState extends State<LocalPickerScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalPickerProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: Selector<LocalPickerProvider, bool>(
            selector: (_, provider) => provider.isLoading,
            builder: (_, isLoading, __) =>
                Text(isLoading ? '正在加载图片...' : '本地选片'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Consumer<LocalPickerProvider>(
              builder: (context, provider, _) =>
                  _buildTopBar(context, provider),
            ),
            Selector<LocalPickerProvider, bool>(
              selector: (_, provider) => provider.isExporting,
              builder: (context, isExporting, _) {
                if (!isExporting) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Selector<LocalPickerProvider, double>(
                    selector: (_, provider) => provider.exportProgress,
                    builder: (context, exportProgress, _) => Column(
                      children: [
                        LinearProgressIndicator(value: exportProgress),
                        const SizedBox(height: 8),
                        Text(
                          '导出中... ${(exportProgress * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: Selector<LocalPickerProvider, bool>(
                selector: (_, provider) => provider.isLoading,
                builder: (context, isLoading, child) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Selector<LocalPickerProvider, bool>(
                    selector: (_, provider) => provider.images.isEmpty,
                    builder: (context, isEmpty, _) {
                      if (isEmpty) {
                        return const Center(child: Text('请选择一个包含.jpg图片的文件夹'));
                      }
                      return Consumer<LocalPickerProvider>(
                        builder: (context, provider, _) =>
                            _buildImageGrid(context, provider),
                      );
                    },
                  );
                },
              ),
            ),
            Consumer<LocalPickerProvider>(
              builder: (context, provider, _) =>
                  _buildBottomBar(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('本地选片帮助'),
        content: const SingleChildScrollView(
          child: Text(
            '本地选片功能允许您从设备的存储中选择、查看和管理照片。\n\n'
            '核心操作：\n'
            '- 点击“选择文件夹”按钮，选择一个包含照片的文件夹。\n'
            '- 所有支持的图片会以缩略图的形式显示在网格中。\n'
            '- 点击缩略图可以进入大图查看模式。\n\n'
            '大图查看模式：\n'
            '- 支持左右滑动或使用键盘的左右方向键来切换图片。\n'
            '- 支持双指或鼠标滚轮缩放，查看图片细节。\n'
            '- 按下“F”键可以快速选择或取消选择当前图片。\n'
            '- 顶部栏提供关闭和选择功能。\n\n'
            '图片管理：\n'
            '- 在缩略图网格或大图查看器中，您可以选择或取消选择图片。\n'
            '- 选中的图片会有一个明显的标记。\n'
            '- 点击主界面的“导出”按钮，可以将所有选中的图片保存到您指定的目录中。\n\n'
            '支持的格式：\n'
            '- 支持常见的图片格式，如 JPG, PNG, HEIC 等。',
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

  Widget _buildTopBar(BuildContext context, LocalPickerProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonGroup = [
            TextButton(onPressed: provider.selectAll, child: const Text('全选')),
            TextButton(
              onPressed: provider.deselectAll,
              child: const Text('全不选'),
            ),
            TextButton(
              onPressed: provider.invertSelection,
              child: const Text('反选'),
            ),
          ];

          // Estimate the width of the buttons
          const double selectFolderWidth = 150;
          const double buttonGroupWidth = 240; // 80 per button * 3
          const double spacing = 16;

          if (constraints.maxWidth <
              selectFolderWidth + buttonGroupWidth + spacing) {
            // Use a column layout if space is tight
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => provider.selectFolder(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                ),
                if (provider.images.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: buttonGroup,
                  ),
              ],
            );
          } else {
            // Use a row layout if there's enough space
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => provider.selectFolder(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                ),
                if (provider.images.isNotEmpty) Row(children: buttonGroup),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, LocalPickerProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: provider.thumbnailSize,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      ),
      itemCount: provider.images.length,
      itemBuilder: (context, index) {
        final image = provider.images[index];
        final isSelected = provider.selectedImages.contains(image);

        return Tooltip(
          message: p.basename(image.path),
          child: GestureDetector(
            onTap: () {
              provider.setCurrentImageIndex(index);
              showDialog(
                context: context,
                barrierColor: Colors.black.withAlpha((255 * 0.8).round()),
                builder: (BuildContext dialogContext) {
                  return ChangeNotifierProvider.value(
                    value: provider,
                    child: const ImageViewerDialog(),
                  );
                },
              );
            },
            child: GridTile(
              header: Align(
                alignment: Alignment.topRight,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    provider.toggleSelection(image);
                  },
                ),
              ),
              child: ThumbnailView(imagePath: image.path),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, LocalPickerProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '选中 ${provider.selectedImages.length} / ${provider.images.length} 张',
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('缩略图:'),
                    SizedBox(
                      width: 150,
                      child: Slider(
                        value: provider.thumbnailSize,
                        min: 50.0,
                        max: 300.0,
                        divisions: 5,
                        label: provider.thumbnailSize.round().toString(),
                        onChanged: (double value) {
                          provider.updateThumbnailSize(value);
                        },
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: provider.isExporting
                      ? null
                      : () => provider.exportSelected(context),
                  child: const Text('导出'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImageViewerDialog extends StatefulWidget {
  const ImageViewerDialog({super.key});

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  final FocusNode _focusNode = FocusNode();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    final provider = Provider.of<LocalPickerProvider>(context, listen: false);
    _pageController = PageController(initialPage: provider.currentImageIndex);

    // Precache initial images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.precacheAdjacentImages(context);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final provider = Provider.of<LocalPickerProvider>(context, listen: false);
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        final currentImage = provider.images[provider.currentImageIndex];
        provider.toggleSelection(currentImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LocalPickerProvider>(context);
    final image = provider.images[provider.currentImageIndex];
    final isSelected = provider.selectedImages.contains(image);
    final hasRaw = provider.rawFileStatus[image.path] ?? false;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: provider.images.length,
              onPageChanged: (index) {
                provider.setCurrentImageIndex(index);
                // Precache images when page changes
                provider.precacheAdjacentImages(context);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.file(
                    provider.images[index],
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.black.withAlpha((255 * 0.5).round()),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(image.path),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (hasRaw)
                        const Text(
                          '存在 RAW 文件',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black.withAlpha((255 * 0.5).round()),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Theme(
                      data: ThemeData(unselectedWidgetColor: Colors.white),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          provider.toggleSelection(image);
                        },
                        activeColor: Colors.white,
                        checkColor: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            Positioned(
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThumbnailView extends StatelessWidget {
  final String imagePath;

  const ThumbnailView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    // Use a Selector to only rebuild when the specific thumbnail data changes.
    return Selector<LocalPickerProvider, Uint8List?>(
      selector: (_, provider) => provider.getThumbnail(imagePath),
      builder: (context, thumbnailData, child) {
        if (thumbnailData != null) {
          return Image.memory(
            thumbnailData,
            fit: BoxFit.cover,
            gaplessPlayback: true, // Avoids flicker when image loads
          );
        } else {
          // Show a placeholder while the thumbnail is generating.
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.image_outlined, color: Colors.grey),
            ),
          );
        }
      },
    );
  }
}
