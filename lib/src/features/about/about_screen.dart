import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页面
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isOpeningLink = false;

  Future<void> _openProjectPage() async {
    if (_isOpeningLink) return;

    setState(() {
      _isOpeningLink = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final uri = Uri.parse('https://github.com/OldSuns/Camera_Toolbox');
      if (await launchUrl(uri)) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('已在浏览器中打开项目主页')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              '无法打开浏览器，请手动访问 https://github.com/OldSuns/Camera_Toolbox',
            ),
          ),
        );
      }
    } catch (error) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('打开项目主页时发生错误: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningLink = false;
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
              const Text(
                '版本 V1.3.3',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                '一款基础相机工具应用。\n'
                '基于Flutter+Dart的跨平台应用\n\n'
                '更新日志：V1.3.3\n'
                '在设置界面添加了缓存管理\n优化本地选片功能的性能表现',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isOpeningLink ? null : _openProjectPage,
                child: _isOpeningLink
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('访问项目主页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
