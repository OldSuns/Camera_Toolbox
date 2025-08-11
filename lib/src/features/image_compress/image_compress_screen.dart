import 'dart:io';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  final Set<ImageFile> _selectedRows = {};
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
    if (_selectedRows.isEmpty) return;
    service.removeImages(_selectedRows.toList());
    setState(() {
      _selectedRows.clear();
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

  @override
  Widget build(BuildContext context) {
    // 🔧 使用ChangeNotifierProvider.value而不是create
    return ChangeNotifierProvider.value(
      value: _service,
      child: Consumer<ImageCompressService>(
        builder: (context, service, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > kDesktopLayoutBreakpoint;

              if (isDesktop) {
                // 桌面端不需要 TabController
                return Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildDesktopLayout(service),
                  ),
                );
              } else {
                // 移动端使用 TabController
                return DefaultTabController(
                  length: 2,
                  child: Scaffold(
                    body: Column(
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: const TabBar(
                            tabs: [
                              Tab(icon: Icon(Icons.list), text: '文件列表'),
                              Tab(icon: Icon(Icons.settings), text: '压缩设置'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildMobileLayout(service),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  /// 构建桌面端布局
  Widget _buildDesktopLayout(ImageCompressService service) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Pane
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildActionButtons(service, isDesktop: true),
              const SizedBox(height: 8),
              _buildImageDataTable(service, needsExpanded: true),
              const SizedBox(height: 8),
              _buildStatusBar(service),
            ],
          ),
        ),
        const VerticalDivider(width: 16),
        // Right Pane
        Expanded(flex: 1, child: _buildOptionsPanel(service)),
      ],
    );
  }

  /// 构建移动端布局
  Widget _buildMobileLayout(ImageCompressService service) {
    return TabBarView(
      children: [
        // 第一个标签页：文件列表
        Column(
          children: [
            _buildActionButtons(service, isDesktop: false),
            const SizedBox(height: 8),
            _buildImageDataTable(service, needsExpanded: true),
            const SizedBox(height: 8),
            _buildStatusBar(service),
          ],
        ),
        // 第二个标签页：压缩设置
        _buildOptionsPanel(service, isMobile: true),
      ],
    );
  }

  Widget _buildActionButtons(
    ImageCompressService service, {
    required bool isDesktop,
  }) {
    final isCompressing = service.isCompressing;
    final hasSelection = _selectedRows.isNotEmpty;

    final buttons = [
      ElevatedButton.icon(
        onPressed: isCompressing ? null : () => _pickImages(service),
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: isCompressing || !hasSelection
            ? null
            : () => _removeSelectedImages(service),
        icon: const Icon(Icons.remove),
        label: const Text('移除'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: isCompressing || service.selectedImages.isEmpty
            ? null
            : () {
                service.clearAllImages();
                setState(() {
                  _selectedRows.clear();
                });
              },
        icon: const Icon(Icons.clear_all),
        label: const Text('清空'),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          ...buttons,
          const Spacer(),
          ElevatedButton.icon(
            onPressed: isCompressing || service.selectedImages.isEmpty
                ? null
                : () => _startCompression(service),
            icon: isCompressing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.compress),
            label: Text(isCompressing ? '压缩中...' : '压缩'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      );
    } else {
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isCompressing || service.selectedImages.isEmpty
                  ? null
                  : () => _startCompression(service),
              icon: isCompressing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compress),
              label: Text(isCompressing ? '压缩中...' : '压缩'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildImageDataTable(
    ImageCompressService service, {
    bool needsExpanded = true,
  }) {
    final table = DataTable2(
      columnSpacing: 20,
      horizontalMargin: 12,
      minWidth: 600,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      isHorizontalScrollBarVisible: true,
      isVerticalScrollBarVisible: true,
      columns: [
        DataColumn2(
          label: const Text('名称'),
          size: ColumnSize.L,
          onSort: (i, a) => _onSort(service, i, a),
        ),
        DataColumn2(
          label: const Text('大小'),
          size: ColumnSize.S,
          onSort: (i, a) => _onSort(service, i, a),
        ),
        DataColumn2(
          label: const Text('分辨率'),
          size: ColumnSize.M,
          onSort: (i, a) => _onSort(service, i, a),
        ),
        DataColumn2(
          label: const Text('节省了'),
          size: ColumnSize.S,
          onSort: (i, a) => _onSort(service, i, a),
        ),
        const DataColumn2(label: Text('状态'), size: ColumnSize.M),
      ],
      rows: service.selectedImages.map((file) {
        final isSelected = _selectedRows.contains(file);
        return DataRow(
          selected: isSelected,
          onSelectChanged: (selected) {
            setState(() {
              if (selected ?? false) {
                _selectedRows.add(file);
              } else {
                _selectedRows.remove(file);
              }
            });
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

    return needsExpanded ? Expanded(child: table) : table;
  }

  Widget _buildStatusBar(ImageCompressService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('${service.totalSelectedImages} 张已选图片 | ${service.totalSize}'),
        if (service.isCompressing) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: service.overallProgress),
          const SizedBox(height: 4),
        ],
        if (service.statusMessage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              service.statusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionsPanel(
    ImageCompressService service, {
    bool isMobile = false,
  }) {
    // 检查是否为移动端或macOS平台
    final bool isMobileOrMacOS =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    return ListView(
      children: [
        const Text('压缩选项', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // 图片质量
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('JPEG 图片质量'),
            Text(_quality.round().toString()),
          ],
        ),
        Slider(
          value: _quality,
          min: 1,
          max: 100,
          divisions: 99,
          label: _quality.round().toString(),
          onChanged: (value) {
            setState(() {
              _quality = value;
            });
          },
        ),
        const SizedBox(height: 24),

        // 图片尺寸
        const Text('图片尺寸', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _maxWidthController,
          decoration: const InputDecoration(
            labelText: '最大宽度 (可选)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxHeightController,
          decoration: const InputDecoration(
            labelText: '最大高度 (可选)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),

        // 只在桌面端显示输出设置
        if (!isMobileOrMacOS) ...[
          const SizedBox(height: 24),
          // 输出设置
          const Text('输出', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!_outputToOriginalDir)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ElevatedButton.icon(
                onPressed: _selectOutputDirectory,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _selectedOutputDirectory != null ? '已选择目录' : '选择输出目录',
                ),
              ),
            ),
          CheckboxListTile(
            title: const Text('输出到原目录'),
            value: _outputToOriginalDir,
            onChanged: (value) {
              setState(() {
                _outputToOriginalDir = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (_outputToOriginalDir)
            CheckboxListTile(
              title: const Text('覆盖原文件'),
              value: _overwriteOriginal,
              onChanged: (value) {
                setState(() {
                  _overwriteOriginal = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ],
    );
  }
}
