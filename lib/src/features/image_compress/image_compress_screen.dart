import 'dart:io';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../shared/widgets/feature_page_layout.dart';
import '../../shared/widgets/responsive_layout.dart';
import 'image_compress_service.dart';

class ImageCompressScreen extends StatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  double _quality = 90;
  bool _outputToOriginalDir = false;
  final _maxWidthController = TextEditingController();
  final _maxHeightController = TextEditingController();
  String? _selectedOutputDirectory;
  final Set<String> _selectedRowPaths = {};
  bool _overwriteOriginal = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // 🔧 将Service实例提升到State级别
  late final ImageCompressService _service;

  // 响应式布局断点
  static const double kDesktopLayoutBreakpoint = 700.0;

  @override
  void initState() {
    super.initState();
    dataTableShowLogs = false;
    _service = ImageCompressService();
  }

  @override
  void dispose() {
    _maxWidthController.dispose();
    _maxHeightController.dispose();
    // 🔧 显式清理Service资源
    _service.dispose();
    super.dispose();
  }

  void _pickImages(ImageCompressService service) {
    service.pickImages();
  }

  void _removeSelectedImages(ImageCompressService service) {
    if (_selectedRowPaths.isEmpty) return;
    final selectedImages = service.selectedImages
        .where((image) => _selectedRowPaths.contains(image.filePath))
        .toList(growable: false);
    service.removeImages(selectedImages);
    setState(() {
      _selectedRowPaths.clear();
    });
  }

  void _startCompression(ImageCompressService service) {
    final config = CompressionConfig(
      quality: _quality,
      maxWidth: _maxWidthController.text.isNotEmpty
          ? int.tryParse(_maxWidthController.text)
          : null,
      maxHeight: _maxHeightController.text.isNotEmpty
          ? int.tryParse(_maxHeightController.text)
          : null,
      outputToOriginalDir: _outputToOriginalDir,
      outputDirectory: _selectedOutputDirectory,
      overwriteOriginal: _overwriteOriginal,
    );

    service.startCompression(config);
  }

  void _selectOutputDirectory() async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      setState(() {
        _selectedOutputDirectory = directoryPath;
      });
    }
  }

  void _onSort(ImageCompressService service, int columnIndex, bool ascending) {
    service.sortImages(columnIndex, ascending);
    // We still need setState to rebuild the DataTable with the new sort arrows
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  int get _selectedRowsDigest => Object.hashAllUnordered(_selectedRowPaths);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: FeaturePageLayout(
        title: '图像压缩',
        child: StableWidthBuilder<bool>(
          resolve: (width) => width > kDesktopLayoutBreakpoint,
          cacheKey: (
            _quality.round(),
            _outputToOriginalDir,
            _selectedOutputDirectory,
            _overwriteOriginal,
            _sortColumnIndex,
            _sortAscending,
            _selectedRowsDigest,
          ),
          builder: (context, isDesktop) {
            if (isDesktop) {
              return KeyedSubtree(
                key: const ValueKey<String>('image_compress_desktop'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDesktopLayout(),
                ),
              );
            }

            return KeyedSubtree(
              key: const ValueKey<String>('image_compress_mobile'),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const Material(
                      child: TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.list), text: '文件列表'),
                          Tab(icon: Icon(Icons.settings), text: '压缩设置'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildMobileLayout(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建桌面端布局
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildActionButtons(isDesktop: true),
              const SizedBox(height: 8),
              _buildImageDataTable(needsExpanded: true),
              const SizedBox(height: 8),
              _buildStatusBar(),
            ],
          ),
        ),
        const VerticalDivider(width: 16),
        Expanded(flex: 1, child: _buildOptionsPanel()),
      ],
    );
  }

  /// 构建移动端布局
  Widget _buildMobileLayout() {
    return TabBarView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Column(
          children: [
            _buildActionButtons(isDesktop: false),
            const SizedBox(height: 8),
            _buildImageDataTable(needsExpanded: true),
            const SizedBox(height: 8),
            _buildStatusBar(),
          ],
        ),
        _buildOptionsPanel(isMobile: true),
      ],
    );
  }

  Widget _buildActionButtons({required bool isDesktop}) {
    return _ImageCompressActionButtons(
      isDesktop: isDesktop,
      hasSelection: _selectedRowPaths.isNotEmpty,
      onPickImages: () => _pickImages(_service),
      onRemoveSelected: () => _removeSelectedImages(_service),
      onClearAll: () {
        _service.clearAllImages();
        setState(() {
          _selectedRowPaths.clear();
        });
      },
      onStartCompression: () => _startCompression(_service),
    );
  }

  Widget _buildImageDataTable({bool needsExpanded = true}) {
    void rowSelectionChanged(String filePath, bool selected) {
      setState(() {
        if (selected) {
          _selectedRowPaths.add(filePath);
        } else {
          _selectedRowPaths.remove(filePath);
        }
      });
    }

    final table = Platform.isWindows
        ? _ImageCompressWindowsList(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            selectedRowPaths: _selectedRowPaths,
            onSort: _onSort,
            onRowSelectionChanged: rowSelectionChanged,
          )
        : _ImageCompressDataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            selectedRowPaths: _selectedRowPaths,
            onSort: _onSort,
            onRowSelectionChanged: rowSelectionChanged,
          );

    return needsExpanded ? Expanded(child: table) : table;
  }

  Widget _buildStatusBar() {
    return const _ImageCompressStatusBar();
  }

  Widget _buildOptionsPanel({bool isMobile = false}) {
    return _ImageCompressOptionsPanel(
      quality: _quality,
      maxWidthController: _maxWidthController,
      maxHeightController: _maxHeightController,
      selectedOutputDirectory: _selectedOutputDirectory,
      outputToOriginalDir: _outputToOriginalDir,
      overwriteOriginal: _overwriteOriginal,
      onQualityChanged: (value) {
        setState(() {
          _quality = value;
        });
      },
      onSelectOutputDirectory: _selectOutputDirectory,
      onOutputToOriginalDirChanged: (value) {
        setState(() {
          _outputToOriginalDir = value;
        });
      },
      onOverwriteOriginalChanged: (value) {
        setState(() {
          _overwriteOriginal = value;
        });
      },
    );
  }
}

class _ImageCompressActionButtons extends StatelessWidget {
  const _ImageCompressActionButtons({
    required this.isDesktop,
    required this.hasSelection,
    required this.onPickImages,
    required this.onRemoveSelected,
    required this.onClearAll,
    required this.onStartCompression,
  });

  final bool isDesktop;
  final bool hasSelection;
  final VoidCallback onPickImages;
  final VoidCallback onRemoveSelected;
  final VoidCallback onClearAll;
  final VoidCallback onStartCompression;

  @override
  Widget build(BuildContext context) {
    final actionState = context
        .select<ImageCompressService, ({bool isCompressing, bool hasImages})>((
          service,
        ) {
          return (
            isCompressing: service.isCompressing,
            hasImages: service.selectedImages.isNotEmpty,
          );
        });

    final buttons = [
      ElevatedButton.icon(
        onPressed: actionState.isCompressing ? null : onPickImages,
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: actionState.isCompressing || !hasSelection
            ? null
            : onRemoveSelected,
        icon: const Icon(Icons.remove),
        label: const Text('移除'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: actionState.isCompressing || !actionState.hasImages
            ? null
            : onClearAll,
        icon: const Icon(Icons.clear_all),
        label: const Text('清空'),
      ),
    ];

    final compressButton = ElevatedButton.icon(
      onPressed: actionState.isCompressing || !actionState.hasImages
          ? null
          : onStartCompression,
      icon: actionState.isCompressing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.compress),
      label: Text(actionState.isCompressing ? '压缩中...' : '压缩'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );

    if (isDesktop) {
      return Row(children: [...buttons, const Spacer(), compressButton]);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 8),
            Expanded(child: buttons[2]),
            const SizedBox(width: 8),
            Expanded(child: buttons[4]),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: compressButton),
      ],
    );
  }
}

class _ImageCompressDataTable extends StatelessWidget {
  const _ImageCompressDataTable({
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.selectedRowPaths,
    required this.onSort,
    required this.onRowSelectionChanged,
  });

  final int? sortColumnIndex;
  final bool sortAscending;
  final Set<String> selectedRowPaths;
  final void Function(
    ImageCompressService service,
    int columnIndex,
    bool ascending,
  )
  onSort;
  final void Function(String filePath, bool selected) onRowSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageCompressService>(
      builder: (context, service, _) {
        return DataTable2(
          columnSpacing: 20,
          horizontalMargin: 12,
          minWidth: 600,
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          isHorizontalScrollBarVisible: true,
          isVerticalScrollBarVisible: true,
          columns: [
            DataColumn2(
              label: const Text('名称'),
              size: ColumnSize.L,
              onSort: (columnIndex, ascending) {
                onSort(service, columnIndex, ascending);
              },
            ),
            DataColumn2(
              label: const Text('大小'),
              size: ColumnSize.S,
              onSort: (columnIndex, ascending) {
                onSort(service, columnIndex, ascending);
              },
            ),
            DataColumn2(
              label: const Text('分辨率'),
              size: ColumnSize.M,
              onSort: (columnIndex, ascending) {
                onSort(service, columnIndex, ascending);
              },
            ),
            DataColumn2(
              label: const Text('节省了'),
              size: ColumnSize.S,
              onSort: (columnIndex, ascending) {
                onSort(service, columnIndex, ascending);
              },
            ),
            const DataColumn2(label: Text('状态'), size: ColumnSize.M),
          ],
          rows: service.selectedImages.map((file) {
            final isSelected = selectedRowPaths.contains(file.filePath);
            return DataRow(
              selected: isSelected,
              onSelectChanged: (selected) {
                onRowSelectionChanged(file.filePath, selected ?? false);
              },
              cells: [
                DataCell(
                  Row(
                    children: [
                      Expanded(child: Text(file.name)),
                      if (file.isCompleted)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        )
                      else if (file.status == 'error')
                        const Icon(Icons.error, color: Colors.red, size: 16)
                      else if (file.isCompressing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(file.size)),
                DataCell(Text(file.resolution)),
                DataCell(Text(file.compressionSavings)),
                DataCell(
                  file.isCompressing
                      ? LinearProgressIndicator(value: file.progress)
                      : file.status == 'error'
                      ? Tooltip(
                          message: file.errorMessage ?? '压缩失败',
                          child: Text(
                            '失败',
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : file.isCompleted
                      ? Text(
                          file.status == 'skipped' ? '已跳过' : '已完成',
                          style: TextStyle(
                            color: file.status == 'skipped'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        )
                      : const Text('等待中'),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _ImageCompressWindowsList extends StatelessWidget {
  const _ImageCompressWindowsList({
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.selectedRowPaths,
    required this.onSort,
    required this.onRowSelectionChanged,
  });

  final int? sortColumnIndex;
  final bool sortAscending;
  final Set<String> selectedRowPaths;
  final void Function(
    ImageCompressService service,
    int columnIndex,
    bool ascending,
  )
  onSort;
  final void Function(String filePath, bool selected) onRowSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageCompressService>(
      builder: (context, service, _) {
        return Column(
          children: [
            _ImageCompressWindowsHeader(
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              service: service,
              onSort: onSort,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: service.selectedImages.length,
                itemBuilder: (context, index) {
                  final file = service.selectedImages[index];
                  final isSelected = selectedRowPaths.contains(file.filePath);
                  return _ImageCompressWindowsRow(
                    file: file,
                    isSelected: isSelected,
                    onSelectionChanged: (selected) {
                      onRowSelectionChanged(file.filePath, selected);
                    },
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 8),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImageCompressWindowsHeader extends StatelessWidget {
  const _ImageCompressWindowsHeader({
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.service,
    required this.onSort,
  });

  final int? sortColumnIndex;
  final bool sortAscending;
  final ImageCompressService service;
  final void Function(
    ImageCompressService service,
    int columnIndex,
    bool ascending,
  )
  onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            flex: 4,
            child: _ImageCompressHeaderButton(
              label: '名称',
              columnIndex: 0,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onPressed: () => onSort(
                service,
                0,
                sortColumnIndex == 0 ? !sortAscending : true,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _ImageCompressHeaderButton(
              label: '大小',
              columnIndex: 1,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onPressed: () => onSort(
                service,
                1,
                sortColumnIndex == 1 ? !sortAscending : true,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _ImageCompressHeaderButton(
              label: '分辨率',
              columnIndex: 2,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onPressed: () => onSort(
                service,
                2,
                sortColumnIndex == 2 ? !sortAscending : true,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _ImageCompressHeaderButton(
              label: '节省了',
              columnIndex: 3,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onPressed: () => onSort(
                service,
                3,
                sortColumnIndex == 3 ? !sortAscending : true,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('状态', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCompressHeaderButton extends StatelessWidget {
  const _ImageCompressHeaderButton({
    required this.label,
    required this.columnIndex,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onPressed,
  });

  final String label;
  final int columnIndex;
  final int? sortColumnIndex;
  final bool sortAscending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isSorted = sortColumnIndex == columnIndex;
    return TextButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: Icon(
        isSorted
            ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
            : Icons.unfold_more,
        size: 16,
      ),
      label: Text(label),
    );
  }
}

class _ImageCompressWindowsRow extends StatelessWidget {
  const _ImageCompressWindowsRow({
    required this.file,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final ImageFile file;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusText = file.isCompressing
        ? '压缩中'
        : file.status == 'error'
        ? '失败'
        : file.isCompleted
        ? (file.status == 'skipped' ? '已跳过' : '已完成')
        : '等待中';
    final statusColor = file.status == 'error'
        ? Colors.red
        : file.status == 'skipped'
        ? Colors.orange
        : file.isCompleted
        ? Colors.green
        : colorScheme.onSurfaceVariant;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectionChanged(!isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    key: ValueKey<String>('compress_select_${file.filePath}'),
                    value: isSelected,
                    onChanged: (value) {
                      onSelectionChanged(value ?? false);
                    },
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (file.isCompleted)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                          )
                        else if (file.status == 'error')
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: Text(file.size)),
                  Expanded(flex: 2, child: Text(file.resolution)),
                  Expanded(flex: 2, child: Text(file.compressionSavings)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                ],
              ),
              if (file.isCompressing) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: file.progress),
              ],
              if (file.status == 'error' && file.errorMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    file.errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageCompressStatusBar extends StatelessWidget {
  const _ImageCompressStatusBar();

  @override
  Widget build(BuildContext context) {
    final statusState = context
        .select<
          ImageCompressService,
          ({
            int totalSelectedImages,
            String totalSize,
            bool isCompressing,
            double overallProgress,
            String statusMessage,
          })
        >((service) {
          return (
            totalSelectedImages: service.totalSelectedImages,
            totalSize: service.totalSize,
            isCompressing: service.isCompressing,
            overallProgress: service.overallProgress,
            statusMessage: service.statusMessage,
          );
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${statusState.totalSelectedImages} 张已选图片 | ${statusState.totalSize}',
        ),
        if (statusState.isCompressing) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: statusState.overallProgress),
          const SizedBox(height: 4),
        ],
        if (statusState.statusMessage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              statusState.statusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageCompressOptionsPanel extends StatelessWidget {
  const _ImageCompressOptionsPanel({
    required this.quality,
    required this.maxWidthController,
    required this.maxHeightController,
    required this.selectedOutputDirectory,
    required this.outputToOriginalDir,
    required this.overwriteOriginal,
    required this.onQualityChanged,
    required this.onSelectOutputDirectory,
    required this.onOutputToOriginalDirChanged,
    required this.onOverwriteOriginalChanged,
  });

  final double quality;
  final TextEditingController maxWidthController;
  final TextEditingController maxHeightController;
  final String? selectedOutputDirectory;
  final bool outputToOriginalDir;
  final bool overwriteOriginal;
  final ValueChanged<double> onQualityChanged;
  final VoidCallback onSelectOutputDirectory;
  final ValueChanged<bool> onOutputToOriginalDirChanged;
  final ValueChanged<bool> onOverwriteOriginalChanged;

  @override
  Widget build(BuildContext context) {
    final isMobileOrMacOS =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    return ListView(
      children: [
        const Text('压缩选项', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('JPEG 图片质量'), Text(quality.round().toString())],
        ),
        Slider(
          value: quality,
          min: 1,
          max: 100,
          divisions: 99,
          label: quality.round().toString(),
          onChanged: onQualityChanged,
        ),
        const SizedBox(height: 24),
        const Text('图片尺寸', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: maxWidthController,
          decoration: const InputDecoration(
            labelText: '最大宽度 (可选)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: maxHeightController,
          decoration: const InputDecoration(
            labelText: '最大高度 (可选)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        if (!isMobileOrMacOS) ...[
          const SizedBox(height: 24),
          const Text('输出', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!outputToOriginalDir && selectedOutputDirectory != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '当前输出目录: $selectedOutputDirectory',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (!outputToOriginalDir)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: onSelectOutputDirectory,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  selectedOutputDirectory != null ? '已选择目录' : '选择输出目录',
                ),
              ),
            ),
          if (!outputToOriginalDir && selectedOutputDirectory == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '未勾选输出到原目录时，需要先选择输出目录。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          CheckboxListTile(
            title: const Text('输出到原目录'),
            value: outputToOriginalDir,
            onChanged: (value) {
              onOutputToOriginalDirChanged(value ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (outputToOriginalDir)
            CheckboxListTile(
              title: const Text('覆盖原文件'),
              value: overwriteOriginal,
              onChanged: (value) {
                onOverwriteOriginalChanged(value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ],
    );
  }
}
