import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/feature_page_layout.dart';
import 'rename_provider.dart';
import 'widgets/append_rename_view.dart';
import 'widgets/auto_numbering_view.dart';
import 'widgets/exif_rename_view.dart';
import 'widgets/replace_rename_view.dart';

class RenameScreen extends StatefulWidget {
  const RenameScreen({super.key});

  @override
  State<RenameScreen> createState() => _RenameScreenState();
}

class _RenameScreenState extends State<RenameScreen>
    with SingleTickerProviderStateMixin {
  static const double _bottomAreaSpacing = 16;
  static const double _fileSelectionEmptyHeight = 176;
  static const double _fileSelectionHeaderHeight = 56;
  static const double _fileSelectionItemHeight = 72;
  static const double _issueListHeaderHeight = 56;
  static const double _issueListItemHeight = 52;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = context.read<RenameProvider>().activeTabIndex;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<RenameProvider>().setActiveTabIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageLayout(
      title: '批量重命名',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '替换'),
                  Tab(text: '追加'),
                  Tab(text: '自动序号'),
                  Tab(text: 'EXIF命名'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    ReplaceRenameView(),
                    AppendRenameView(),
                    AutoNumberingView(),
                    ExifRenameView(),
                  ],
                ),
              ),
              Consumer<RenameProvider>(
                builder: (context, provider, _) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        _buildFileInfoAndActions(provider),
                        const SizedBox(height: _bottomAreaSpacing),
                        _buildFileAndIssueArea(
                          provider,
                          availableHeight: constraints.maxHeight,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDuplicateFilesSnackBar(int duplicateCount) {
    if (duplicateCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已过滤 $duplicateCount 个重复文件'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final provider = context.read<RenameProvider>();
    final beforeCount = provider.files.length;
    await provider.addFiles(details.files);
    final afterCount = provider.files.length;
    _showDuplicateFilesSnackBar(
      details.files.length - (afterCount - beforeCount),
    );
  }

  Widget _buildFileAndIssueArea(
    RenameProvider provider, {
    required double availableHeight,
  }) {
    final fileSelectionHeight = _calculateFileSelectionHeight(
      availableHeight,
      provider,
    );
    final issueListHeight = provider.issues.isEmpty
        ? null
        : _calculateIssueListHeight(availableHeight, provider.issues.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildFileSelectionArea(
            provider,
            targetHeight: fileSelectionHeight,
            maxHeight: _calculateFileSelectionMaxHeight(
              availableHeight,
              hasIssues: provider.issues.isNotEmpty,
            ),
          ),
          if (provider.issues.isNotEmpty) ...[
            const SizedBox(height: _bottomAreaSpacing),
            _buildIssueList(
              provider,
              targetHeight: issueListHeight!,
              maxHeight: _calculateIssueListMaxHeight(availableHeight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSelectionArea(
    RenameProvider provider, {
    required double targetHeight,
    required double maxHeight,
  }) {
    final fileSelectionBody = provider.files.isEmpty
        ? DropTarget(
            onDragDone: _handleDrop,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text(
                    '拖放文件到此处或点击选择文件',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final duplicateCount = await provider.selectFiles();
                          _showDuplicateFilesSnackBar(duplicateCount);
                        },
                        child: const Text('选择文件'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final duplicateCount = await provider.selectFolder();
                          if (duplicateCount == -1) {
                            _showPermissionDeniedSnackBar();
                          } else {
                            _showDuplicateFilesSnackBar(duplicateCount);
                          }
                        },
                        child: const Text('选择文件夹'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final duplicateCount = await provider.selectFiles();
                        _showDuplicateFilesSnackBar(duplicateCount);
                      },
                      child: const Text('添加文件'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final duplicateCount = await provider.selectFolder();
                        if (duplicateCount == -1) {
                          _showPermissionDeniedSnackBar();
                        } else {
                          _showDuplicateFilesSnackBar(duplicateCount);
                        }
                      },
                      child: const Text('添加文件夹'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DropTarget(
                  onDragDone: _handleDrop,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: provider.files.length,
                    itemBuilder: (context, index) {
                      final fileDetail = provider.files[index];
                      final previewItem = provider.previewItemAt(index);
                      return _RenamePreviewListItem(
                        key: ValueKey(fileDetail.file.path),
                        index: index,
                        fileDetail: fileDetail,
                        previewItem: previewItem,
                        onRemove: () => provider.removeFile(index),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      provider.reorderFiles(oldIndex, newIndex);
                    },
                  ),
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: targetHeight,
        maxHeight: maxHeight,
      ),
      child: SizedBox(
        height: targetHeight,
        child: Card(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: fileSelectionBody,
          ),
        ),
      ),
    );
  }

  Widget _buildIssueList(
    RenameProvider provider, {
    required double targetHeight,
    required double maxHeight,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: targetHeight,
        maxHeight: maxHeight,
      ),
      child: SizedBox(
        height: targetHeight,
        child: Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '处理日志 (${provider.issues.length} 条)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: provider.issues.length,
                    itemBuilder: (context, index) {
                      final issue = provider.issues[index];
                      final icon = switch (issue.severity) {
                        RenameIssueSeverity.info => Icons.info_outline,
                        RenameIssueSeverity.warning =>
                          Icons.warning_amber_rounded,
                        RenameIssueSeverity.error => Icons.error_outline,
                      };
                      final color = switch (issue.severity) {
                        RenameIssueSeverity.info => Theme.of(
                          context,
                        ).colorScheme.primary,
                        RenameIssueSeverity.warning => Colors.orange.shade700,
                        RenameIssueSeverity.error => Theme.of(
                          context,
                        ).colorScheme.error,
                      };
                      return ListTile(
                        dense: true,
                        leading: Icon(icon, color: color),
                        title: Text(issue.fileName ?? issue.code),
                        subtitle: Text(_formatIssueSubtitle(issue)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateFileSelectionMaxHeight(
    double availableHeight, {
    required bool hasIssues,
  }) {
    final rawMaxHeight = hasIssues
        ? availableHeight * 0.24
        : availableHeight * 0.34;
    final minMaxHeight = hasIssues ? 160.0 : 180.0;
    final maxMaxHeight = hasIssues ? 260.0 : 300.0;
    return rawMaxHeight.clamp(minMaxHeight, maxMaxHeight).toDouble();
  }

  double _calculateFileSelectionHeight(
    double availableHeight,
    RenameProvider provider,
  ) {
    final maxHeight = _calculateFileSelectionMaxHeight(
      availableHeight,
      hasIssues: provider.issues.isNotEmpty,
    );
    final estimatedContentHeight = provider.files.isEmpty
        ? _fileSelectionEmptyHeight
        : _fileSelectionHeaderHeight +
              (_fileSelectionItemHeight * provider.files.length.clamp(1, 3)) +
              16;
    return estimatedContentHeight.clamp(0.0, maxHeight).toDouble();
  }

  double _calculateIssueListMaxHeight(double availableHeight) {
    return (availableHeight * 0.18).clamp(96.0, 160.0).toDouble();
  }

  double _calculateIssueListHeight(double availableHeight, int issueCount) {
    final maxHeight = _calculateIssueListMaxHeight(availableHeight);
    final estimatedContentHeight =
        _issueListHeaderHeight +
        (_issueListItemHeight * issueCount.clamp(1, 2));
    return estimatedContentHeight.clamp(96.0, maxHeight).toDouble();
  }

  String _formatIssueSubtitle(RenameIssue issue) {
    if (issue.targetPath != null && issue.targetPath!.isNotEmpty) {
      return '${issue.message}\n目标: ${issue.targetPath}';
    }
    return issue.message;
  }

  Widget _buildFileInfoAndActions(RenameProvider provider) {
    final summary = provider.previewPlan.summary;
    final actionButtons = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        Tooltip(
          message: '按原始基础文件名分组编号，同名 JPG/RAW 可共用同一序号',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('同名合并'),
              Switch(
                value: provider.mergeSameName,
                onChanged: provider.setMergeSameName,
              ),
            ],
          ),
        ),
        PopupMenuButton<SortCriterion>(
          icon: const Icon(Icons.sort),
          tooltip: '排序方式',
          onSelected: provider.sortFiles,
          itemBuilder: (context) => const [
            PopupMenuItem(value: SortCriterion.nameAsc, child: Text('按文件名升序')),
            PopupMenuItem(value: SortCriterion.nameDesc, child: Text('按文件名降序')),
            PopupMenuItem(value: SortCriterion.dateAsc, child: Text('按日期升序')),
            PopupMenuItem(value: SortCriterion.dateDesc, child: Text('按日期降序')),
          ],
        ),
        Tooltip(
          message: '清除列表',
          child: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: provider.files.isNotEmpty
                ? provider.clearSelection
                : null,
          ),
        ),
        if (provider.lastRenameLog.isNotEmpty)
          OutlinedButton(
            onPressed: () async {
              final result = await provider.undoRename();
              if (!mounted) {
                return;
              }
              final message = result.failedCount == 0
                  ? '撤销操作已完成'
                  : '撤销失败 ${result.failedCount} 项，请查看处理日志';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('撤销上次操作'),
          ),
        ElevatedButton(
          onPressed: provider.files.isNotEmpty
              ? () => _showRenameConfirmationDialog(context, provider)
              : null,
          child: const Text('确定重命名'),
        ),
      ],
    );

    final optionFields = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<RenameConflictPolicy>(
            initialValue: provider.conflictPolicy,
            decoration: const InputDecoration(
              labelText: '冲突处理',
              border: OutlineInputBorder(),
            ),
            items: RenameConflictPolicy.values
                .map(
                  (policy) => DropdownMenuItem(
                    value: policy,
                    child: Text(policy.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setConflictPolicy(value);
              }
            },
          ),
        ),
        if (provider.activeMode == RenameMode.exif)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<ExifMissingPolicy>(
              initialValue: provider.exifMissingPolicy,
              decoration: const InputDecoration(
                labelText: 'EXIF 缺失处理',
                border: OutlineInputBorder(),
              ),
              items: ExifMissingPolicy.values
                  .map(
                    (policy) => DropdownMenuItem(
                      value: policy,
                      child: Text(policy.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  provider.setExifMissingPolicy(value);
                }
              },
            ),
          ),
        Chip(label: Text(_summaryText(summary))),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 720) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已选择 ${provider.files.length} 个文件'),
                    Flexible(child: actionButtons),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('已选择 ${provider.files.length} 个文件'),
                  const SizedBox(height: 8),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          optionFields,
        ],
      ),
    );
  }

  String _summaryText(RenamePlanSummary summary) {
    return '将改名 ${summary.renameCount} | 未变化 ${summary.unchangedCount} | 跳过 ${summary.skippedCount} | 冲突 ${summary.conflictCount} | 警告 ${summary.warningCount}';
  }

  void _showRenameConfirmationDialog(
    BuildContext context,
    RenameProvider provider,
  ) {
    final plan = provider.previewPlan;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认重命名'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_summaryText(plan.summary)),
                const SizedBox(height: 12),
                if (plan.summary.renameCount == 0) const Text('当前没有可执行的重命名项。'),
                if (plan.summary.conflictCount > 0) ...[
                  const Text(
                    '检测到冲突，当前策略下不能直接执行。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...plan.items
                      .where(
                        (item) => item.status == RenamePreviewStatus.conflict,
                      )
                      .take(5)
                      .map(
                        (item) => Text(
                          '${item.originalName} -> ${item.primaryMessage}',
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: plan.canExecute
                  ? () {
                      Navigator.of(dialogContext).pop();
                      _executeRename(context, provider);
                    }
                  : null,
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeRename(
    BuildContext context,
    RenameProvider provider,
  ) async {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('正在重命名...')),
            ],
          ),
        );
      },
    );

    final result = await provider.executeRename();
    if (!mounted) {
      return;
    }
    navigator.pop();

    await showDialog(
      context: this.context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('重命名完成'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成功：${result.successCount} 个\n失败：${result.failedCount} 个\n跳过：${result.skippedCount} 个\n警告：${result.warningCount} 个',
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
                      child: ListView.builder(
                        itemCount: result.issues.length,
                        itemBuilder: (context, index) {
                          final issue = result.issues[index];
                          final fileName = issue.fileName ?? '未指定文件';
                          final targetText = issue.targetPath == null
                              ? ''
                              : '\n目标: ${issue.targetPath}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '$fileName: ${issue.message}$targetText',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedSnackBar() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('存储权限被拒绝，无法访问文件夹中的文件。请在设置中授予权限后重试。'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _RenamePreviewListItem extends StatelessWidget {
  const _RenamePreviewListItem({
    super.key,
    required this.index,
    required this.fileDetail,
    required this.previewItem,
    required this.onRemove,
  });

  final int index;
  final FileDetail fileDetail;
  final RenamePlanItem? previewItem;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryStatus = _resolvePrimaryStatus(previewItem);
    final statusColor = _statusColor(context, primaryStatus);
    final targetName = previewItem?.targetName ?? fileDetail.fileName;
    final tooltipMessage = _buildTooltipMessage(previewItem);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(90),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RenameStatusBadge(
                  status: primaryStatus,
                  tooltipMessage: tooltipMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileDetail.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: primaryStatus == RenamePreviewStatus.conflict
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 156,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Tooltip(
                      message: _buildMetaTooltip(fileDetail),
                      child: Text(
                        _buildMetaText(fileDetail),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: onRemove,
                    tooltip: '删除',
                  ),
                  const SizedBox(width: 4),
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: '拖动排序',
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: Icon(
                            Icons.drag_indicator,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  RenamePreviewStatus _resolvePrimaryStatus(RenamePlanItem? item) {
    if (item == null) {
      return RenamePreviewStatus.normal;
    }

    if (item.status == RenamePreviewStatus.conflict || item.hasErrors) {
      return RenamePreviewStatus.conflict;
    }
    if (item.status == RenamePreviewStatus.warning || item.hasWarnings) {
      return RenamePreviewStatus.warning;
    }
    if (item.status == RenamePreviewStatus.unchanged ||
        item.action == RenamePlanAction.unchanged) {
      return RenamePreviewStatus.unchanged;
    }
    return RenamePreviewStatus.normal;
  }

  Color _statusColor(BuildContext context, RenamePreviewStatus status) {
    final theme = Theme.of(context);
    return switch (status) {
      RenamePreviewStatus.normal => theme.colorScheme.primary,
      RenamePreviewStatus.unchanged => theme.colorScheme.onSurfaceVariant,
      RenamePreviewStatus.warning => Colors.orange.shade700,
      RenamePreviewStatus.conflict => theme.colorScheme.error,
    };
  }

  String _buildMetaText(FileDetail fileDetail) {
    final dateText = DateFormat(
      'MM-dd',
    ).format(fileDetail.lastModified.toLocal());
    return '$dateText · ${_formatCompactFileSize(fileDetail.size)}';
  }

  String _buildMetaTooltip(FileDetail fileDetail) {
    final timeText = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(fileDetail.lastModified.toLocal());
    final sizeText = '${(fileDetail.size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '$timeText · $sizeText';
  }

  String? _buildTooltipMessage(RenamePlanItem? item) {
    if (item == null) {
      return '预览生成中';
    }

    final parts = <String>[];
    if (item.primaryMessage.isNotEmpty) {
      parts.add(item.primaryMessage);
    }
    if (item.caseOnlyRename) {
      parts.add('仅大小写变化');
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  String _formatCompactFileSize(int bytes) {
    final megaBytes = bytes / (1024 * 1024);
    if (megaBytes >= 1024) {
      return '${(megaBytes / 1024).toStringAsFixed(1)}G';
    }
    if (megaBytes >= 1) {
      return '${megaBytes.toStringAsFixed(1)}M';
    }
    final kiloBytes = bytes / 1024;
    return '${kiloBytes.toStringAsFixed(0)}K';
  }
}

class _RenameStatusBadge extends StatelessWidget {
  const _RenameStatusBadge({
    required this.status,
    required this.tooltipMessage,
  });

  final RenamePreviewStatus status;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (status) {
      RenamePreviewStatus.normal => theme.colorScheme.primaryContainer,
      RenamePreviewStatus.unchanged =>
        theme.colorScheme.surfaceContainerHighest,
      RenamePreviewStatus.warning => Colors.orange.shade100,
      RenamePreviewStatus.conflict => theme.colorScheme.errorContainer,
    };
    final textColor = switch (status) {
      RenamePreviewStatus.normal => theme.colorScheme.onPrimaryContainer,
      RenamePreviewStatus.unchanged => theme.colorScheme.onSurfaceVariant,
      RenamePreviewStatus.warning => Colors.orange.shade900,
      RenamePreviewStatus.conflict => theme.colorScheme.onErrorContainer,
    };

    final badge = Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _badgeLabel(status),
        maxLines: 1,
        softWrap: false,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );

    if (tooltipMessage == null || tooltipMessage!.isEmpty) {
      return badge;
    }

    return Tooltip(message: tooltipMessage, child: badge);
  }

  String _badgeLabel(RenamePreviewStatus status) {
    return switch (status) {
      RenamePreviewStatus.normal => '正常',
      RenamePreviewStatus.unchanged => '未变',
      RenamePreviewStatus.warning => '警告',
      RenamePreviewStatus.conflict => '冲突',
    };
  }
}
