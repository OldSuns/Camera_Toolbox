import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      body: Column(
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
                    const SizedBox(height: 16),
                    _buildFileAndIssueArea(provider),
                  ],
                ),
              );
            },
          ),
        ],
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

  Widget _buildFileAndIssueArea(RenameProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildFileSelectionArea(provider),
          if (provider.issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildIssueList(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSelectionArea(RenameProvider provider) {
    return Card(
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: provider.files.isEmpty
            ? DropTarget(
                onDragDone: _handleDrop,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.upload_file,
                        size: 48,
                        color: Colors.grey,
                      ),
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
                              final duplicateCount = await provider
                                  .selectFiles();
                              _showDuplicateFilesSnackBar(duplicateCount);
                            },
                            child: const Text('选择文件'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              final duplicateCount = await provider
                                  .selectFolder();
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
                            final duplicateCount = await provider
                                .selectFolder();
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
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.files.length,
                        itemBuilder: (context, index) {
                          final fileDetail = provider.files[index];
                          final previewItem = provider.previewItemAt(index);
                          return ListTile(
                            key: ValueKey(fileDetail.file.path),
                            title: Text(fileDetail.fileName),
                            subtitle: _buildPreviewSubtitle(
                              context,
                              previewItem,
                              fileDetail,
                            ),
                            trailing: SizedBox(
                              width: 126,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    DateFormat(
                                      'yyyy-MM-dd HH:mm',
                                    ).format(fileDetail.lastModified.toLocal()),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${(fileDetail.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  IconButton(
                                    padding: const EdgeInsets.only(
                                      left: 5,
                                      right: 10,
                                    ),
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                                    onPressed: () => provider.removeFile(index),
                                  ),
                                ],
                              ),
                            ),
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
              ),
      ),
    );
  }

  Widget _buildPreviewSubtitle(
    BuildContext context,
    RenamePlanItem? item,
    FileDetail fileDetail,
  ) {
    final theme = Theme.of(context);
    if (item == null) {
      return Text(fileDetail.fileName);
    }

    final statusColor = switch (item.status) {
      RenamePreviewStatus.normal => theme.colorScheme.primary,
      RenamePreviewStatus.unchanged => theme.colorScheme.onSurfaceVariant,
      RenamePreviewStatus.warning => Colors.orange.shade700,
      RenamePreviewStatus.conflict => theme.colorScheme.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.targetName,
          style: TextStyle(
            color: statusColor,
            fontWeight: item.status == RenamePreviewStatus.conflict
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildStatusChip(context, item.status),
            _buildActionChip(context, item.action),
            if (item.caseOnlyRename) _buildInfoChip(context, '仅大小写变化'),
          ],
        ),
        if (item.issues.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.primaryMessage,
            style: TextStyle(fontSize: 12, color: statusColor),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, RenamePreviewStatus status) {
    final theme = Theme.of(context);
    final color = switch (status) {
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
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildActionChip(BuildContext context, RenamePlanAction action) {
    return Chip(
      label: Text(action.label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildInfoChip(BuildContext context, String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildIssueList(RenameProvider provider) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        height: 180,
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
                itemCount: provider.issues.length,
                itemBuilder: (context, index) {
                  final issue = provider.issues[index];
                  final icon = switch (issue.severity) {
                    RenameIssueSeverity.info => Icons.info_outline,
                    RenameIssueSeverity.warning => Icons.warning_amber_rounded,
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
    );
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
            value: provider.conflictPolicy,
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
              value: provider.exifMissingPolicy,
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
    return '将改名 ${summary.renameCount} | 跳过 ${summary.skippedCount} | 冲突 ${summary.conflictCount} | 警告 ${summary.warningCount}';
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
