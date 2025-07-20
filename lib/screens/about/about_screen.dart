import 'package:flutter/material.dart';

/// 关于页面
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                '版本 1.0.1',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Text(
                '一款功能强大的相机工具应用，专为摄影爱好者和专业摄影师设计。支持EXIF元数据深度解析、快速分片等多种实用功能，让您的摄影工作流程更加高效。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              const Text(
                '功能特性：',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• EXIF元数据深度解析与翻译\n'
                '• 支持JPEG、PNG、HEIC、RAW等多种格式\n'
                '• RAW+JPG智能匹配与分组管理\n'
                '• 快速分割模式，一键分离处理\n'
                '• 批量文件处理与重命名\n'
                '• 跨平台响应式设计\n'
                '• 深色/浅色主题切换',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
