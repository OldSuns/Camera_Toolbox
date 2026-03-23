import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../shared/utils/conflict_action.dart';
import '../../shared/widgets/feature_page_layout.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../../shared/widgets/semantic_summary_region.dart';
import 'local_picker_provider.dart';

const double _localPickerCompactBreakpoint = 760;
const double _localPickerScopeFieldWidth = 196;
const double _localPickerSortFieldWidth = 204;
const double _localPickerFilterFieldWidth = 172;

@immutable
class _LocalPickerBodyViewModel {
  const _LocalPickerBodyViewModel({
    required this.isLoading,
    required this.totalImageCount,
    required this.currentDirectory,
    required this.filteredImageCount,
    required this.visibleEntries,
    required this.hasMore,
    required this.thumbnailSize,
  });

  final bool isLoading;
  final int totalImageCount;
  final String? currentDirectory;
  final int filteredImageCount;
  final List<LocalImageEntry> visibleEntries;
  final bool hasMore;
  final double thumbnailSize;

  @override
  bool operator ==(Object other) {
    return other is _LocalPickerBodyViewModel &&
        other.isLoading == isLoading &&
        other.totalImageCount == totalImageCount &&
        other.currentDirectory == currentDirectory &&
        other.filteredImageCount == filteredImageCount &&
        other.hasMore == hasMore &&
        other.thumbnailSize == thumbnailSize &&
        listEquals(other.visibleEntries, visibleEntries);
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    totalImageCount,
    currentDirectory,
    filteredImageCount,
    hasMore,
    thumbnailSize,
    Object.hashAll(visibleEntries),
  );
}

class LocalPickerScreen extends StatelessWidget {
  const LocalPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LocalPickerView();
  }
}

class _LocalPickerView extends StatefulWidget {
  const _LocalPickerView();

  @override
  State<_LocalPickerView> createState() => _LocalPickerViewState();
}

class _LocalPickerViewState extends State<_LocalPickerView> {
  final ScrollController _scrollController = ScrollController();
  LocalPickerProvider? _provider;
  int? _lastHandledMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 240) {
        context.read<LocalPickerProvider>().loadMoreImages();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<LocalPickerProvider>();
    if (!identical(_provider, provider)) {
      _provider?.removeListener(_handleProviderMessages);
      _provider = provider;
      _provider?.addListener(_handleProviderMessages);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleProviderMessages);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleProviderMessages() {
    final message = _provider?.pendingUserMessage;
    if (!mounted || message == null || _lastHandledMessageId == message.id) {
      return;
    }

    _lastHandledMessageId = message.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.message)));
      _provider?.clearPendingUserMessage(message.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageLayout(
      title: '本地选片',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () => _showHelpDialog(context),
          tooltip: '帮助',
        ),
      ],
      child: Column(
        children: [
          StableWidthBuilder<bool>(
            resolve: (width) => width < _localPickerCompactBreakpoint,
            builder: (context, isCompact) {
              return Consumer<LocalPickerProvider>(
                builder: (context, provider, _) {
                  return _buildTopBar(context, provider, isCompact: isCompact);
                },
              );
            },
          ),
          const _LocalPickerExportProgress(),
          Expanded(
            child: Selector<LocalPickerProvider, _LocalPickerBodyViewModel>(
              selector: (context, provider) => _LocalPickerBodyViewModel(
                isLoading: provider.isLoading,
                totalImageCount: provider.totalImageCount,
                currentDirectory: provider.currentDirectory,
                filteredImageCount: provider.filteredImageCount,
                visibleEntries: provider.visibleImageEntries,
                hasMore: provider.hasMore,
                thumbnailSize: provider.thumbnailSize,
              ),
              builder: (context, viewModel, _) {
                return _buildBody(context, viewModel);
              },
            ),
          ),
          StableWidthBuilder<bool>(
            resolve: (width) => width < _localPickerCompactBreakpoint,
            builder: (context, isCompact) {
              return Consumer<LocalPickerProvider>(
                builder: (context, provider, _) {
                  return _buildBottomBar(provider, isCompact: isCompact);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, _LocalPickerBodyViewModel viewModel) {
    if (viewModel.isLoading && viewModel.totalImageCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.currentDirectory == null) {
      return const Center(child: Text('请选择一个图片目录开始选片'));
    }
    if (viewModel.filteredImageCount == 0) {
      return const Center(child: Text('当前范围或筛选条件下没有匹配图片'));
    }
    return SemanticSummaryRegion(
      label:
          '本地选片网格，共 ${viewModel.filteredImageCount} 张图片，当前显示 ${viewModel.visibleEntries.length} 张',
      child: RepaintBoundary(
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: viewModel.thumbnailSize,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount:
              viewModel.visibleEntries.length + (viewModel.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= viewModel.visibleEntries.length) {
              return const Center(child: CircularProgressIndicator());
            }

            final entry = viewModel.visibleEntries[index];
            return _LocalPickerGridTile(
              entry: entry,
              thumbnailSize: viewModel.thumbnailSize,
              onTap: () => _openImageViewer(context, entry),
            );
          },
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, LocalImageEntry entry) {
    final provider = context.read<LocalPickerProvider>();
    final viewerIndex = provider.filteredImageEntries.indexWhere(
      (item) => item.path == entry.path,
    );
    if (viewerIndex < 0) {
      return;
    }

    provider.setCurrentImageIndex(viewerIndex);
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.82).round()),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const ImageViewerDialog(),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    LocalPickerProvider provider, {
    required bool isCompact,
  }) {
    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: isCompact
          ? _buildCompactTopBar(context, provider)
          : _buildWideTopBar(context, provider),
    );
  }

  Widget _buildBottomBar(
    LocalPickerProvider provider, {
    required bool isCompact,
  }) {
    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: isCompact
          ? _buildCompactBottomBar(provider)
          : _buildWideBottomBar(provider),
    );
  }

  Widget _buildWideTopBar(BuildContext context, LocalPickerProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : provider.selectFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件夹'),
            ),
            if (provider.currentDirectory != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: LocalPickerDirectorySummaryCard(
                  path: provider.currentDirectory!,
                  compact: false,
                  onTap: () =>
                      _showPathDialog(context, provider.currentDirectory!),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildToolbarCard(
          context,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildScopeField(
                context,
                provider,
                width: _localPickerScopeFieldWidth,
              ),
              _buildSortField(
                context,
                provider,
                width: _localPickerSortFieldWidth,
              ),
              _buildFilterField(
                context,
                provider,
                width: _localPickerFilterFieldWidth,
              ),
              _buildSelectionActionButtons(provider),
              _buildCaptureInfoSettingTile(provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTopBar(
    BuildContext context,
    LocalPickerProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : provider.selectFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件夹'),
            ),
            Chip(
              label: Text(
                '已选 ${provider.selectedCountInFiltered}/${provider.filteredImageCount}',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showCompactControlsSheet(context, provider),
              icon: const Icon(Icons.tune),
              label: const Text('筛选与操作'),
            ),
          ],
        ),
        if (provider.currentDirectory != null) ...[
          const SizedBox(height: 8),
          LocalPickerDirectorySummaryCard(
            path: provider.currentDirectory!,
            compact: true,
            onTap: () => _showPathDialog(context, provider.currentDirectory!),
          ),
        ],
      ],
    );
  }

  Widget _buildWideBottomBar(LocalPickerProvider provider) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '当前筛选已选 ${provider.selectedCountInFiltered} / ${provider.filteredImageCount}，总选中 ${provider.selectedImagePaths.length} 张',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('缩略图:'),
            SizedBox(
              width: 150,
              child: Slider(
                value: provider.thumbnailSize,
                min: 80,
                max: 300,
                divisions: 11,
                label: provider.thumbnailSize.round().toString(),
                onChanged: provider.updateThumbnailSize,
              ),
            ),
          ],
        ),
        ElevatedButton(
          onPressed: provider.isExporting
              ? null
              : () => _showExportDialog(context, provider),
          child: const Text('导出'),
        ),
      ],
    );
  }

  Widget _buildCompactBottomBar(LocalPickerProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '已选 ${provider.selectedCountInFiltered}/${provider.filteredImageCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: provider.isExporting
              ? null
              : () => _showExportDialog(context, provider),
          child: const Text('导出'),
        ),
      ],
    );
  }

  Future<void> _showCompactControlsSheet(
    BuildContext context,
    LocalPickerProvider provider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer<LocalPickerProvider>(
            builder: (context, sheetProvider, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: _buildToolbarCard(
                  sheetContext,
                  child: LocalPickerCompactControlsContent(
                    provider: sheetProvider,
                    onClose: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showPathDialog(BuildContext context, String path) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('当前目录'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScopeField(
    BuildContext context,
    LocalPickerProvider provider, {
    double? width,
  }) {
    final field = DropdownButtonFormField<FolderScanScope>(
      initialValue: provider.scanScope,
      isExpanded: true,
      decoration: _toolbarInputDecoration(
        context,
        label: '扫描范围',
        icon: Icons.folder_copy_outlined,
      ),
      items: FolderScanScope.values
          .map(
            (scope) =>
                DropdownMenuItem(value: scope, child: Text(scope.displayName)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          unawaited(provider.setScanScope(value));
        }
      },
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _buildSortField(
    BuildContext context,
    LocalPickerProvider provider, {
    double? width,
  }) {
    final field = DropdownButtonFormField<LocalPickerSortMode>(
      initialValue: provider.sortMode,
      isExpanded: true,
      decoration: _toolbarInputDecoration(
        context,
        label: '排序',
        icon: Icons.swap_vert,
      ),
      items: LocalPickerSortMode.values
          .map(
            (mode) =>
                DropdownMenuItem(value: mode, child: Text(mode.displayName)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          provider.setSortMode(value);
        }
      },
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _buildFilterField(
    BuildContext context,
    LocalPickerProvider provider, {
    double? width,
  }) {
    final field = DropdownButtonFormField<LocalPickerFilterMode>(
      initialValue: provider.filterMode,
      isExpanded: true,
      decoration: _toolbarInputDecoration(
        context,
        label: '筛选',
        icon: Icons.filter_alt_outlined,
      ),
      items: LocalPickerFilterMode.values
          .map(
            (mode) =>
                DropdownMenuItem(value: mode, child: Text(mode.displayName)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          provider.setFilterMode(value);
        }
      },
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _buildToolbarCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildSelectionActionButtons(LocalPickerProvider provider) {
    return _LocalPickerSelectionActionButtons(provider: provider);
  }

  Widget _buildCaptureInfoSettingTile(LocalPickerProvider provider) {
    return _LocalPickerCaptureInfoTile(provider: provider);
  }

  Future<void> _showExportDialog(
    BuildContext context,
    LocalPickerProvider provider,
  ) async {
    if (provider.selectedImagePaths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择图片')));
      return;
    }

    final options = await showDialog<LocalPickerExportOptions>(
      context: context,
      builder: (_) => const LocalPickerExportDialog(),
    );

    if (options == null) {
      return;
    }

    final result = await provider.exportSelectedToDirectory(options);
    if (!context.mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final hasFailures = result.failedCount > 0;
        final hasSkips = result.skippedCount > 0;
        return AlertDialog(
          title: Text(
            hasFailures
                ? '导出完成（部分成功）'
                : hasSkips
                ? '导出完成（有跳过）'
                : '导出完成',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '导出图片 ${result.exportedImageCount} 张\n'
                    '附带 RAW ${result.exportedRawCount} 个\n'
                    '自动重命名 ${result.renamedCount} 项\n'
                    '跳过 ${result.skippedCount} 项\n'
                    '失败 ${result.failedCount} 项',
                  ),
                  if (result.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '处理详情',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: SemanticSummaryRegion(
                        label: '导出处理详情列表，共 ${result.issues.length} 条',
                        child: ListView.builder(
                          itemCount: result.issues.length,
                          itemBuilder: (context, index) {
                            final issue = result.issues[index];
                            final fileName = p.basename(issue.sourcePath);
                            final suffix = issue.targetPath == null
                                ? ''
                                : '\n目标: ${issue.targetPath}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('$fileName: ${issue.message}$suffix'),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (_isDesktopPlatform)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _openDirectory(
                    options.targetDirectory,
                    context: context,
                  );
                },
                child: const Text('打开目录'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('本地选片帮助'),
        content: const SingleChildScrollView(
          child: Text(
            '本地选片支持从当前目录或递归子目录扫描图片，并基于完整目录快照分页浏览。\n\n'
            '核心操作：\n'
            '- 选择文件夹后，可切换扫描范围、排序方式和筛选条件。\n'
            '- 全选 / 全不选 / 反选作用于当前筛选结果全集，而不是当前屏幕已渲染的页。\n'
            '- 开启“详情页显示拍摄信息”后，仅在大图查看器显示拍摄日期与拍摄参数，缩略图页不显示。\n'
            '- 点击缩略图进入大图查看，支持方向键切换、F 键快速勾选。\n\n'
            '导出：\n'
            '- 导出前可设置冲突策略：跳过、重命名、覆盖。\n'
            '- 可选附带同名 RAW 一起导出。\n\n'
            '支持格式：\n'
            '- 图片：JPG / JPEG / PNG / HEIC\n'
            '- RAW 识别：CR2 / CR3 / NEF / ARW / DNG / RAF / RW2 等',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}

class LocalPickerExportDialog extends StatefulWidget {
  const LocalPickerExportDialog({
    super.key,
    this.initialTargetDirectory,
    this.initialConflictAction = ConflictAction.rename,
    this.initialIncludeRaw = false,
  });

  final String? initialTargetDirectory;
  final ConflictAction initialConflictAction;
  final bool initialIncludeRaw;

  @override
  State<LocalPickerExportDialog> createState() =>
      _LocalPickerExportDialogState();
}

class _LocalPickerExportDialogState extends State<LocalPickerExportDialog> {
  late String? _targetDirectory;
  late ConflictAction _conflictAction;
  late bool _includeRaw;

  @override
  void initState() {
    super.initState();
    _targetDirectory = widget.initialTargetDirectory;
    _conflictAction = widget.initialConflictAction;
    _includeRaw = widget.initialIncludeRaw;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出设置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _targetDirectory == null ? '未选择导出目录' : _targetDirectory!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await FilePicker.platform.getDirectoryPath();
                  if (!mounted || selected == null) {
                    return;
                  }
                  setState(() {
                    _targetDirectory = selected;
                  });
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('选择导出目录'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ConflictAction>(
                initialValue: _conflictAction,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '冲突处理',
                  border: OutlineInputBorder(),
                ),
                items: ConflictAction.values
                    .map(
                      (action) => DropdownMenuItem(
                        value: action,
                        child: Text(action.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _conflictAction = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _conflictAction.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('附带同名 RAW'),
                subtitle: const Text('导出 JPG 时一并导出同目录下匹配的 RAW'),
                value: _includeRaw,
                onChanged: (value) {
                  setState(() {
                    _includeRaw = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _targetDirectory == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    LocalPickerExportOptions(
                      targetDirectory: _targetDirectory!,
                      conflictAction: _conflictAction,
                      includeRaw: _includeRaw,
                    ),
                  );
                },
          child: const Text('开始导出'),
        ),
      ],
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
    final provider = context.read<LocalPickerProvider>();
    _pageController = PageController(initialPage: provider.currentImageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      provider.preloadCurrentImage(context);
      provider.preloadAdjacentImages(context);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    final provider = context.read<LocalPickerProvider>();
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      final currentPath = provider.currentImageEntry?.path;
      if (currentPath != null) {
        provider.toggleSelection(currentPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEntry = context.select<LocalPickerProvider, LocalImageEntry?>(
      (provider) => provider.currentImageEntry,
    );
    if (currentEntry == null) {
      return const SizedBox.shrink();
    }

    final imagePath = currentEntry.path;
    final provider = context.read<LocalPickerProvider>();
    final itemCount = context.select<LocalPickerProvider, int>(
      (provider) => provider.filteredImageEntries.length,
    );
    final showCaptureInfo = context.select<LocalPickerProvider, bool>(
      (provider) => provider.showCaptureInfo,
    );
    final isSelected = context.select<LocalPickerProvider, bool>(
      (provider) => provider.selectedImagePaths.contains(imagePath),
    );
    final metadata = context.select<LocalPickerProvider, LocalImageMetadata?>((
      provider,
    ) {
      if (!provider.showCaptureInfo) {
        return null;
      }
      return provider.metadataForPath(imagePath);
    });

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SemanticSummaryRegion(
              label:
                  '大图查看器，共 $itemCount 张图片，当前第 ${provider.currentImageIndex + 1} 张',
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemCount,
                onPageChanged: (index) {
                  provider.setCurrentImageIndex(index);
                  provider.preloadAdjacentImages(context);
                },
                itemBuilder: (context, index) {
                  final entry = provider.filteredImageEntries[index];
                  return RepaintBoundary(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 3,
                      child: _buildImage(provider, entry.path),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: LocalPickerViewerMetadataPanel(
                entry: currentEntry,
                showCaptureInfo: showCaptureInfo,
                metadata: metadata,
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
                        onChanged: (_) => provider.toggleSelection(imagePath),
                        activeColor: Colors.white,
                        checkColor: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
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
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            Positioned(
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(LocalPickerProvider provider, String imagePath) {
    final imageProvider = provider.getImageProvider(imagePath);
    return Image(
      image: imageProvider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.error_outline, size: 64, color: Colors.grey),
          ),
        );
      },
    );
  }
}

String _formatLocalPickerCaptureTime(
  DateTime value, {
  bool withSeconds = false,
}) {
  return DateFormat(
    withSeconds ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd HH:mm',
  ).format(value.toLocal());
}

class LocalPickerGridMetadataFooter extends StatelessWidget {
  const LocalPickerGridMetadataFooter({super.key, required this.entry});

  final LocalImageEntry entry;

  @override
  Widget build(BuildContext context) {
    if (!entry.hasRaw) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withAlpha((255 * 0.72).round()),
            Colors.black.withAlpha((255 * 0.10).round()),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((255 * 0.6).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'RAW',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalPickerDirectorySummaryCard extends StatelessWidget {
  const LocalPickerDirectorySummaryCard({
    super.key,
    required this.path,
    required this.onTap,
    required this.compact,
  });

  final String path;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: compact
                  ? Text(path, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '当前目录',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                '查看完整路径',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_full,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _toolbarInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: colorScheme.surface,
    prefixIcon: Icon(icon, size: 18),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
    ),
  );
}

class _LocalPickerSelectionActionButtons extends StatelessWidget {
  const _LocalPickerSelectionActionButtons({required this.provider});

  final LocalPickerProvider provider;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          style: style,
          onPressed: provider.selectAll,
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('全选'),
        ),
        OutlinedButton.icon(
          style: style,
          onPressed: provider.deselectAll,
          icon: const Icon(Icons.remove_done, size: 18),
          label: const Text('全不选'),
        ),
        OutlinedButton.icon(
          style: style,
          onPressed: provider.invertSelection,
          icon: const Icon(Icons.flip, size: 18),
          label: const Text('反选'),
        ),
      ],
    );
  }
}

class _LocalPickerToolbarDropdown<T> extends StatelessWidget {
  const _LocalPickerToolbarDropdown({
    required this.value,
    required this.decoration,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final InputDecoration decoration;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: decoration,
      items: items,
      onChanged: onChanged,
    );
  }
}

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> _openDirectory(
  String path, {
  required BuildContext context,
}) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('无法打开目录: $error')));
  }
}

class _LocalPickerCaptureInfoTile extends StatelessWidget {
  const _LocalPickerCaptureInfoTile({required this.provider});

  final LocalPickerProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          const Text('详情页显示拍摄信息'),
          const SizedBox(width: 8),
          Switch(
            value: provider.showCaptureInfo,
            onChanged: provider.setShowCaptureInfo,
          ),
        ],
      ),
    );
  }
}

class LocalPickerCompactControlsContent extends StatelessWidget {
  const LocalPickerCompactControlsContent({
    super.key,
    required this.provider,
    required this.onClose,
  });

  final LocalPickerProvider provider;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('筛选与操作', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '调整浏览方式、筛选条件和批量选择操作。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _LocalPickerToolbarDropdown<FolderScanScope>(
          value: provider.scanScope,
          decoration: _toolbarInputDecoration(
            context,
            label: '扫描范围',
            icon: Icons.folder_copy_outlined,
          ),
          items: FolderScanScope.values
              .map(
                (scope) => DropdownMenuItem(
                  value: scope,
                  child: Text(scope.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              unawaited(provider.setScanScope(value));
            }
          },
        ),
        const SizedBox(height: 12),
        _LocalPickerToolbarDropdown<LocalPickerSortMode>(
          value: provider.sortMode,
          decoration: _toolbarInputDecoration(
            context,
            label: '排序',
            icon: Icons.swap_vert,
          ),
          items: LocalPickerSortMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              provider.setSortMode(value);
            }
          },
        ),
        const SizedBox(height: 12),
        _LocalPickerToolbarDropdown<LocalPickerFilterMode>(
          value: provider.filterMode,
          decoration: _toolbarInputDecoration(
            context,
            label: '筛选',
            icon: Icons.filter_alt_outlined,
          ),
          items: LocalPickerFilterMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              provider.setFilterMode(value);
            }
          },
        ),
        const SizedBox(height: 12),
        _LocalPickerCaptureInfoTile(provider: provider),
        const SizedBox(height: 16),
        Text('缩略图大小', style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: provider.thumbnailSize,
                min: 80,
                max: 300,
                divisions: 11,
                label: provider.thumbnailSize.round().toString(),
                onChanged: provider.updateThumbnailSize,
              ),
            ),
            const SizedBox(width: 8),
            Text(provider.thumbnailSize.round().toString()),
          ],
        ),
        const SizedBox(height: 8),
        _LocalPickerSelectionActionButtons(provider: provider),
      ],
    );
  }
}

class LocalPickerViewerMetadataPanel extends StatelessWidget {
  const LocalPickerViewerMetadataPanel({
    super.key,
    required this.entry,
    required this.showCaptureInfo,
    required this.metadata,
  });

  final LocalImageEntry entry;
  final bool showCaptureInfo;
  final LocalImageMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha((255 * 0.5).round()),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.fileName,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (showCaptureInfo && metadata != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatLocalPickerCaptureTime(
                  metadata!.captureTime,
                  withSeconds: true,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                metadata!.captureTimeLabel,
                style: TextStyle(
                  color: metadata!.captureTimeSource == CaptureTimeSource.exif
                      ? Colors.lightGreenAccent
                      : Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
              if (metadata!.cameraModel != null)
                Text(
                  metadata!.cameraModel!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              if (metadata!.exposureSummary != null)
                Text(
                  metadata!.exposureSummary!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
            if (entry.hasRaw)
              const Text(
                '存在 RAW 文件',
                style: TextStyle(color: Colors.greenAccent, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class ThumbnailView extends StatefulWidget {
  const ThumbnailView({
    super.key,
    required this.imagePath,
    required this.thumbnailSize,
  });

  final String imagePath;
  final double thumbnailSize;

  @override
  State<ThumbnailView> createState() => _ThumbnailViewState();
}

class _ThumbnailViewState extends State<ThumbnailView> {
  Future<Uint8List?>? _thumbnailFuture;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant ThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.thumbnailSize != widget.thumbnailSize) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final provider = context.read<LocalPickerProvider>();
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final targetDimension = provider.normalizeThumbnailDimension(
      (widget.thumbnailSize * devicePixelRatio).round(),
    );
    _requestKey = provider.thumbnailRequestKey(
      widget.imagePath,
      targetDimension,
    );
    _thumbnailFuture = provider.getThumbnail(
      widget.imagePath,
      targetDimension: targetDimension,
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestKey = _requestKey;
    final cachedThumbnail = context.select<LocalPickerProvider, Uint8List?>(
      (provider) =>
          requestKey == null ? null : provider.thumbnailCache[requestKey],
    );

    if (cachedThumbnail != null) {
      return Image.memory(
        cachedThumbnail,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        }
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_outlined, color: Colors.grey),
          ),
        );
      },
    );
  }
}

class _LocalPickerExportProgress extends StatelessWidget {
  const _LocalPickerExportProgress();

  @override
  Widget build(BuildContext context) {
    final exportState = context
        .select<LocalPickerProvider, ({bool isExporting, double progress})>(
          (provider) => (
            isExporting: provider.isExporting,
            progress: provider.exportProgress,
          ),
        );
    if (!exportState.isExporting) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(value: exportState.progress),
          const SizedBox(height: 8),
          Text('导出中... ${(exportState.progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _LocalPickerGridTile extends StatelessWidget {
  const _LocalPickerGridTile({
    required this.entry,
    required this.thumbnailSize,
    required this.onTap,
  });

  final LocalImageEntry entry;
  final double thumbnailSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: entry.fileName,
      child: GestureDetector(
        onTap: onTap,
        child: GridTile(
          header: Align(
            alignment: Alignment.topRight,
            child: _LocalPickerSelectionCheckbox(imagePath: entry.path),
          ),
          footer: LocalPickerGridMetadataFooter(entry: entry),
          child: ThumbnailView(
            imagePath: entry.path,
            thumbnailSize: thumbnailSize,
          ),
        ),
      ),
    );
  }
}

class _LocalPickerSelectionCheckbox extends StatelessWidget {
  const _LocalPickerSelectionCheckbox({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select<LocalPickerProvider, bool>(
      (provider) => provider.selectedImagePaths.contains(imagePath),
    );
    return Checkbox(
      value: isSelected,
      onChanged: (_) {
        context.read<LocalPickerProvider>().toggleSelection(imagePath);
      },
    );
  }
}
