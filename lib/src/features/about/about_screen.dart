import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页面
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Create an instance of the updater class
  final _updater = ShorebirdUpdater();
  int? _patchNumber;
  bool _isCheckingForUpdate = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentPatch();
  }

  Future<void> _fetchCurrentPatch() async {
    try {
      final currentPatch = await _updater.readCurrentPatch();
      if (mounted) {
        setState(() {
          _patchNumber = currentPatch?.number;
        });
      }
    } catch (error, stackTrace) {
      log('获取当前补丁失败', error: error, stackTrace: stackTrace);
      // 打开浏览器跳转到指定网页
      final uri = Uri.parse('https://github.com/OldSuns/Camera_Toolbox');
      if (await launchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已在浏览器中打开项目主页')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '无法打开浏览器，请手动访问 https://github.com/OldSuns/Camera_Toolbox',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdate) return;

    setState(() {
      _isCheckingForUpdate = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      log('正在检查新Patch...');
      final status = await _updater.checkForUpdate();
      log('检查更新状态: $status');

      if (!mounted) return;

      if (status == UpdateStatus.outdated) {
        log('发现新补丁，正在下载...');
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('发现新补丁，正在下载...')),
        );
        await _updater.update();
        log('更新下载完成');
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('更新完成，请重启应用。')),
        );
      } else if (status == UpdateStatus.upToDate) {
        log('已是最新版本');
        // 打开浏览器跳转到指定网页
        final uri = Uri.parse('https://github.com/OldSuns/Camera_Toolbox');
        if (await launchUrl(uri)) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('已在浏览器中打开项目主页')),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('已是最新版本。')),
          );
        }
      } else if (status == UpdateStatus.unavailable) {
        log('Shorebird更新在当前环境不可用');
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('更新功能仅在通过Shorebird构建的应用中可用。')),
        );
        // 打开浏览器跳转到指定网页
        final uri = Uri.parse('https://github.com/OldSuns/Camera_Toolbox');
        await launchUrl(uri);
      }
    } on UpdateException catch (error, stackTrace) {
      log('更新失败', error: error, stackTrace: stackTrace);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('更新失败: $error')));
    } catch (error, stackTrace) {
      log('发生未知错误', error: error, stackTrace: stackTrace);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('检查更新时发生未知错误: $error')),
      );
      // 打开浏览器跳转到指定网页
      final uri = Uri.parse('https://github.com/OldSuns/Camera_Toolbox');
      await launchUrl(uri);
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: Center(
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
              Text(
                '版本 V1.3.2${_patchNumber == null ? '' : ' Patch $_patchNumber'}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                '一款基础相机工具应用。\n'
                '基于Flutter+Dart的跨平台应用\n\n'
                '更新日志：V1.3.2\n'
                '在设置界面添加了缓存管理\n优化本地选片功能的性能表现',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isCheckingForUpdate ? null : _checkForUpdates,
                child: _isCheckingForUpdate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('检查更新'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
