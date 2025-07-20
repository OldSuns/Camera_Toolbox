import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/exif_data.dart';
import '../../services/exif_service.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/exif_display.dart';

/// Exif读取器页面 - 完整的Exif功能实现
class ExifReaderScreen extends StatefulWidget {
  const ExifReaderScreen({super.key});

  @override
  State<ExifReaderScreen> createState() => _ExifReaderScreenState();
}

class _ExifReaderScreenState extends State<ExifReaderScreen> {
  File? _selectedImage;
  ExifData? _exifData;
  bool _isLoading = false;
  String? _errorMessage;

  /// 选择图片
  Future<void> _selectImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final image = await ImagePickerService.pickImageFromGallery();
      if (image != null) {
        await _loadExifData(image);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择图片失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 从文件选择器选择图片
  Future<void> _selectImageFromFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final image = await ImagePickerService.pickImageFromFile();
      if (image != null) {
        await _loadExifData(image);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择文件失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载EXIF数据
  Future<void> _loadExifData(File image) async {
    setState(() {
      _selectedImage = image;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exifData = await ExifService.readExifFromFile(image.path);
      setState(() {
        _exifData = exifData;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '读取EXIF信息失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 清除选择
  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _exifData = null;
      _errorMessage = null;
    });
  }

  /// 分享EXIF信息
  void _shareExifInfo() {
    if (_exifData == null) return;

    final exifText = _exifData!.translatedData.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: exifText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EXIF信息已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片EXIF信息阅读器'),
        actions: [
          if (_exifData != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareExifInfo,
              tooltip: '分享EXIF信息',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearSelection,
            tooltip: '清除选择',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在读取EXIF信息...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _selectImage, child: const Text('重新选择')),
          ],
        ),
      );
    }

    if (_selectedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '请选择一张图片',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('从相册选择'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _selectImageFromFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('从文件选择'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片预览
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedImage!.path.split('/').last,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // EXIF信息
          if (_exifData != null)
            ExifDisplayWidget(
              exifData: _exifData!,
              onRefresh: () => _loadExifData(_selectedImage!),
            ),
        ],
      ),
    );
  }
}
