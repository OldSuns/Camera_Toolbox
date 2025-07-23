import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'rename_provider.dart';
import 'widgets/replace_rename_view.dart';
import 'widgets/append_rename_view.dart';
import 'widgets/auto_numbering_view.dart';
import 'widgets/exif_rename_view.dart';

/// 批量重命名页面 - 提供多种策略批量修改文件名
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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // 当标签切换时，更新Provider中的状态
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
      appBar: AppBar(
        title: const Text('批量重命名'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '替换'),
            Tab(text: '追加'),
            Tab(text: '自动序号'),
            Tab(text: 'EXIF命名'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          // Consumer只包裹需要它的部分
          Consumer<RenameProvider>(
            builder: (context, renameProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    _buildFileInfoAndActions(renameProvider),
                    const SizedBox(height: 16),
                    _buildFileSelectionArea(renameProvider),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 显示重复文件提示
  void _showDuplicateFilesSnackBar(int duplicateCount) {
    if (duplicateCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已过滤 $duplicateCount 个重复文件'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 构建文件选择区域
  Widget _buildFileSelectionArea(RenameProvider renameProvider) {
    // 计算容器高度：最小150，每个文件项约60高度，最大300
    final containerHeight = renameProvider.files.isEmpty
        ? 150.0
        : (150.0 + (renameProvider.files.length * 60.0)).clamp(150.0, 300.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: containerHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: renameProvider.files.isEmpty
            ? DropTarget(
                onDragDone: (detail) async {
                  // 记录添加前的文件数量
                  final beforeCount = renameProvider.files.length;

                  // 添加文件
                  await renameProvider.addFiles(detail.files);

                  // 计算实际添加的文件数量
                  final afterCount = renameProvider.files.length;
                  final addedCount = afterCount - beforeCount;

                  // 计算重复文件数量
                  final duplicateCount = detail.files.length - addedCount;

                  // 显示重复文件提示
                  _showDuplicateFilesSnackBar(duplicateCount);
                },
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
                            onPressed: () => renameProvider.selectFiles(),
                            child: const Text('选择文件'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => renameProvider.selectFolder(),
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
                  // 添加文件按钮
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () async {
                            // 调用选择文件方法并获取重复文件数量
                            final duplicateCount = await renameProvider
                                .selectFiles();

                            // 显示重复文件提示
                            _showDuplicateFilesSnackBar(duplicateCount);
                          },
                          child: const Text('添加文件'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            // 调用选择文件夹方法并获取重复文件数量
                            final duplicateCount = await renameProvider
                                .selectFolder();

                            // 显示重复文件提示
                            _showDuplicateFilesSnackBar(duplicateCount);
                          },
                          child: const Text('添加文件夹'),
                        ),
                      ],
                    ),
                  ),
                  // 文件列表
                  Expanded(
                    child: DropTarget(
                      onDragDone: (detail) async {
                        // 记录添加前的文件数量
                        final beforeCount = renameProvider.files.length;

                        // 添加文件
                        await renameProvider.addFiles(detail.files);

                        // 计算实际添加的文件数量
                        final afterCount = renameProvider.files.length;
                        final addedCount = afterCount - beforeCount;

                        // 计算重复文件数量
                        final duplicateCount = detail.files.length - addedCount;

                        // 显示重复文件提示
                        _showDuplicateFilesSnackBar(duplicateCount);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: renameProvider.files.length,
                        itemBuilder: (context, index) {
                          final fileDetail = renameProvider.files[index];
                          final file = fileDetail.file;
                          return ListTile(
                            title: Text(
                              file.path.split(Platform.pathSeparator).last,
                            ),
                            subtitle: Text(
                              renameProvider.previewRename(fileDetail, index),
                            ),
                            trailing: SizedBox(
                              width: 120, // 限制trailing区域的最大宽度
                              child: Wrap(
                                alignment: WrapAlignment.end, // 右对齐
                                spacing: 8.0,
                                runSpacing: 4.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      renameProvider.removeFile(index);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 构建文件信息和操作按钮
  Widget _buildFileInfoAndActions(RenameProvider renameProvider) {
    // 提取操作按钮到一个独立的Widget，方便复用
    final actionButtons = Wrap(
      spacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end, // 在Column布局中让按钮靠右
      children: [
        // 同名合并开关
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('同名合并'),
            Switch(
              value: renameProvider.mergeSameName,
              onChanged: (value) {
                renameProvider.setMergeSameName(value);
              },
            ),
          ],
        ),
        // 排序按钮
        PopupMenuButton<SortCriterion>(
          icon: const Icon(Icons.sort),
          tooltip: '排序方式',
          onSelected: (SortCriterion criterion) {
            renameProvider.sortFiles(criterion);
          },
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<SortCriterion>>[
                const PopupMenuItem<SortCriterion>(
                  value: SortCriterion.nameAsc,
                  child: Text('按名称升序'),
                ),
                const PopupMenuItem<SortCriterion>(
                  value: SortCriterion.nameDesc,
                  child: Text('按名称降序'),
                ),
                const PopupMenuItem<SortCriterion>(
                  value: SortCriterion.dateAsc,
                  child: Text('按日期升序'),
                ),
                const PopupMenuItem<SortCriterion>(
                  value: SortCriterion.dateDesc,
                  child: Text('按日期降序'),
                ),
              ],
        ),
        // 清除选择按钮
        Tooltip(
          message: '清除列表',
          child: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: renameProvider.files.isNotEmpty
                ? () {
                    renameProvider.clearSelection();
                  }
                : null,
          ),
        ),
        // 确定重命名按钮
        ElevatedButton(
          onPressed: renameProvider.files.isNotEmpty
              ? () => _showRenameConfirmationDialog(context, renameProvider)
              : null,
          child: const Text('确定重命名'),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 设置一个断点，例如550
          if (constraints.maxWidth > 550) {
            // 宽屏布局
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('已选择 ${renameProvider.files.length} 个文件'),
                actionButtons,
              ],
            );
          } else {
            // 窄屏布局
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('已选择 ${renameProvider.files.length} 个文件'),
                const SizedBox(height: 8),
                actionButtons,
              ],
            );
          }
        },
      ),
    );
  }

  void _showRenameConfirmationDialog(
    BuildContext context,
    RenameProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认重命名'),
          content: Text('即将重命名 ${provider.files.length} 个文件。此操作无法撤销，是否继续？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('确认'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close confirmation dialog
                _executeRename(context, provider);
              },
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
    // 在异步操作之前获取Navigator和Context
    final navigator = Navigator.of(context);
    final currentContext = context;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("正在重命名..."),
            ],
          ),
        );
      },
    );

    try {
      final result = await provider.executeRename();
      if (!mounted) return;
      navigator.pop(); // Close loading dialog

      // Show result dialog
      if (!mounted) return;
      if (!currentContext.mounted) return;
      await showDialog(
        context: currentContext,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('重命名完成'),
            content: Text(
              '成功：${result['success']} 个\n失败：${result['failed']} 个',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('好的'),
                onPressed: () {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
      // Clear selection after showing result
      if (!mounted) return;
      provider.clearSelection();
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // Close loading dialog on error
      // Show error dialog
      if (!mounted) return;
      if (!currentContext.mounted) return;
      await showDialog(
        context: currentContext,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('发生错误'),
            content: Text('重命名失败: $e'),
            actions: <Widget>[
              TextButton(
                child: const Text('好的'),
                onPressed: () {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
