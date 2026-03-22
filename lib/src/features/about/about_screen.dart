import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/feature_page_layout.dart';
import '../../shared/services/version_check_service.dart';

/// 关于页面
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isOpeningLink = false;
  bool _isCheckingUpdate = false;
  bool _hasUpdate = false;
  VersionInfo? _latestVersion;
  String _currentVersion = ''; // 版本号，从package_info_plus获取
  DateTime? _lastCheckTime; // 最后检查时间

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkForUpdates();
      }
    });
  }

  /// 格式化时间显示
  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}天前';
    if (difference.inHours > 0) return '${difference.inHours}小时前';
    if (difference.inMinutes > 0) return '${difference.inMinutes}分钟前';
    return '刚刚';
  }

  /// 格式化发布时间
  String _formatPublishTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.year}年${dateTime.month}月${dateTime.day}日';
    }
    if (difference.inDays > 0) return '${difference.inDays}天前发布';
    if (difference.inHours > 0) return '${difference.inHours}小时前发布';
    return '刚刚发布';
  }

  /// 截取更新日志预览
  String _getChangelogPreview(String body) {
    if (body.isEmpty) return '暂无更新日志';

    String cleanBody = body
        .replaceAll(RegExp(r'```[\s\S]*?```'), '') // 移除多行代码块
        .replaceAllMapped(
          RegExp(r'`([^`\n]+)`'),
          (m) => m.group(1) ?? '',
        ) // 单行代码块
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '') // 标题符号
        .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'),
          (m) => m.group(1) ?? '',
        ) // 粗体
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '') // 斜体
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (m) => m.group(1) ?? '',
        ) // 链接
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
          (m) => m.group(1) ?? '',
        ) // 图片
        .replaceAll(RegExp(r'^\s*[-*+]\s*', multiLine: true), '') // 列表符号
        .replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true), '') // 有序列表
        .replaceAll(RegExp(r'\n\s*\n'), '\n') // 合并空行
        .replaceAll(RegExp(r'^\s+|\s+$', multiLine: true), '') // 清理空格
        .trim();

    return cleanBody.length > 100
        ? '${cleanBody.substring(0, 100)}...'
        : cleanBody;
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final versionStatus = await VersionCheckService.checkVersionStatus();
      if (mounted) {
        setState(() {
          _currentVersion = versionStatus.currentVersion;
          _latestVersion = versionStatus.latestVersion;
          _hasUpdate = versionStatus.hasUpdate;
          _isCheckingUpdate = false;
          _lastCheckTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
          _lastCheckTime = DateTime.now();
        });
      }
    }
  }

  Future<void> _openProjectPage() async {
    if (_isOpeningLink) return;
    setState(() => _isOpeningLink = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final url = _hasUpdate
        ? 'https://github.com/OldSuns/Camera_Toolbox/releases'
        : 'https://github.com/OldSuns/Camera_Toolbox';

    try {
      if (await launchUrl(Uri.parse(url))) {
        final message = _hasUpdate ? '已在浏览器中打开更新页面' : '已在浏览器中打开项目主页';
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('无法打开浏览器，请手动访问 $url')),
        );
      }
    } catch (error) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('打开页面时发生错误: $error')),
      );
    } finally {
      if (mounted) setState(() => _isOpeningLink = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageLayout(
      title: '关于',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'OldSun相机工具箱',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // 版本信息显示
              Column(
                children: [
                  Text(
                    _currentVersion.isEmpty
                        ? '版本加载中...'
                        : '版本 V$_currentVersion',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (_hasUpdate && _latestVersion != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '新版本 ${_latestVersion!.tagName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatPublishTime(_latestVersion!.publishedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_lastCheckTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '最后检查: ${_formatTimeAgo(_lastCheckTime!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              // 应用描述
              const Text(
                '一款基础相机工具应用。\n'
                '基于Flutter+Dart的跨平台应用',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              // 更新日志显示
              if (_latestVersion != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasUpdate
                        ? Colors.blue.withValues(alpha: 0.05)
                        : Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasUpdate
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasUpdate ? Icons.update : Icons.check_circle,
                            size: 16,
                            color: _hasUpdate ? Colors.blue : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasUpdate
                                ? '${_latestVersion!.tagName} 更新内容'
                                : '${_latestVersion!.tagName} 最新版本',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _hasUpdate ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getChangelogPreview(_latestVersion!.body),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            _currentVersion.isEmpty
                                ? '当前版本加载中...'
                                : '当前版本 V$_currentVersion',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '暂无更新日志信息\n请点击刷新按钮检查最新版本',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_isOpeningLink || _isCheckingUpdate)
                        ? null
                        : _openProjectPage,
                    icon: _isOpeningLink
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _isCheckingUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_hasUpdate ? Icons.download : Icons.open_in_new),
                    label: Text(
                      _isCheckingUpdate
                          ? '检查更新中...'
                          : _hasUpdate
                          ? '检测到更新'
                          : '访问项目主页',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasUpdate ? Colors.orange : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (_lastCheckTime != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('刷新'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
