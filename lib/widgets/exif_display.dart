import 'package:flutter/material.dart';
import '../models/exif_data.dart';

/// EXIF信息展示组件
class ExifDisplayWidget extends StatelessWidget {
  final ExifData exifData;
  final VoidCallback? onRefresh;

  const ExifDisplayWidget({super.key, required this.exifData, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (!exifData.hasExif) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildHeader(), const SizedBox(height: 16), _buildExifCards()],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '未找到EXIF信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '这张图片可能不包含EXIF信息，或者信息已被移除',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'EXIF信息',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: '刷新',
          ),
      ],
    );
  }

  Widget _buildExifCards() {
    final displayData = exifData.displayData;

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: displayData.entries.map((entry) {
        return _buildExifCard(title: entry.key, value: entry.value);
      }).toList(),
    );
  }

  Widget _buildExifCard({required String title, required String value}) {
    IconData icon;
    Color color;

    // 根据标题类型选择图标和颜色
    switch (title) {
      case '图片宽度':
      case '图片高度':
        icon = Icons.photo_size_select_large;
        color = Colors.blue;
        break;
      case '相机制造商':
      case '相机型号':
        icon = Icons.camera_alt;
        color = Colors.green;
        break;
      case '拍摄时间':
        icon = Icons.calendar_today;
        color = Colors.orange;
        break;
      case '曝光时间':
        icon = Icons.timer;
        color = Colors.purple;
        break;
      case '光圈值':
        icon = Icons.camera;
        color = Colors.red;
        break;
      case 'ISO感光度':
        icon = Icons.speed;
        color = Colors.indigo;
        break;
      case '焦距':
        icon = Icons.straighten;
        color = Colors.teal;
        break;
      case '闪光灯':
        icon = Icons.flash_on;
        color = Colors.yellow;
        break;
      case '纬度':
      case '经度':
        icon = Icons.location_on;
        color = Colors.red;
        break;
      case '海拔':
        icon = Icons.terrain;
        color = Colors.brown;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
        dense: true,
      ),
    );
  }
}
