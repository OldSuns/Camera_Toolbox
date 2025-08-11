import 'package:flutter/material.dart';
import 'widgets/cache_management_widget.dart';

/// 缓存管理页面
class CacheManagementScreen extends StatelessWidget {
  const CacheManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: CacheManagementWidget(),
      ),
    );
  }
}
