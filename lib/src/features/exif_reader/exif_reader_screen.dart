import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'exif_data.dart';
import 'exif_service.dart';
import '../../shared/services/image_picker_service.dart';
import 'exif_display.dart';

/// ExifReaderScreen - A feature-rich screen for reading EXIF data from images.
///
/// This screen allows users to select an image from their gallery or file system,
/// reads the EXIF metadata, and displays it in a user-friendly format.
/// It supports various image formats, including common RAW files.
class ExifReaderScreen extends StatefulWidget {
  const ExifReaderScreen({super.key});

  @override
  State<ExifReaderScreen> createState() => _ExifReaderScreenState();
}

class _ExifReaderScreenState extends State<ExifReaderScreen> {
  File? _selectedImage;
  ExifData? _exifData;
  Uint8List? _previewImageBytes;
  bool _isLoading = false;
  String? _errorMessage;

  /// A generic method to pick an image using a provided picker function.
  ///
  /// This reduces code duplication by handling the common logic for setting
  /// loading states, error handling, and triggering the EXIF data loading.
  /// The [picker] parameter is a function that returns a `Future<File?>`.
  Future<void> _pickAndLoadImage(Future<File?> Function() picker) async {
    // Prevent user interaction while an operation is in progress.
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final image = await picker();
      if (image != null) {
        await _loadExifData(image);
      } else {
        // If no image was selected, stop the loading indicator.
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择图片失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Selects an image from the gallery and loads its EXIF data.
  Future<void> _selectImage() async {
    await _pickAndLoadImage(ImagePickerService.pickImageFromGallery);
  }

  /// Selects an image using the system file picker and loads its EXIF data.
  Future<void> _selectImageFromFile() async {
    await _pickAndLoadImage(ImagePickerService.pickImageFromFile);
  }

  /// Loads and processes the EXIF data from the selected [image].
  ///
  /// This method updates the UI to show a loading state, then asynchronously
  /// reads the EXIF data. Upon completion, it updates the state with the
  /// extracted data or an error message.
  Future<void> _loadExifData(File image) async {
    // Reset state for the new image and start loading.
    setState(() {
      _selectedImage = image;
      _exifData = null;
      _previewImageBytes = null;
      _errorMessage = null;
      _isLoading = true; // Ensure loading indicator is shown
    });

    try {
      final exifData = await ExifService.readExifFromFile(image.path);
      if (mounted) {
        setState(() {
          if (exifData.hasExif) {
            _exifData = exifData;
            _previewImageBytes = exifData.thumbnailBytes;
          } else {
            _errorMessage = exifData.errorMessage ?? '无法解析此文件';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '处理文件时发生未知错误';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 清除选择
  /// Clears the current image selection and resets the state.
  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _exifData = null;
      _previewImageBytes = null;
      _errorMessage = null;
      _isLoading = false; // Ensure loading state is reset
    });
  }

  /// 分享EXIF信息
  /// Copies the formatted EXIF data to the clipboard and shows a confirmation.
  void _shareExifInfo() {
    if (_exifData == null) return;

    // Create a formatted string of the translated EXIF data.
    final exifText = _exifData!.translatedData.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');

    Clipboard.setData(ClipboardData(text: exifText));

    // Show a SnackBar to confirm the action to the user.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EXIF信息已复制到剪贴板'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 显示功能说明对话框
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('功能说明'),
        content: const SingleChildScrollView(
          child: Text(
            '本功能支持读取多种图片格式（包括JPG, PNG, WebP）和常见的RAW文件格式（如ARW, CR3, NEF, DNG等）的EXIF元数据。\n\n'
            '对于RAW文件，应用会尝试提取并显示嵌入的预览图，以提高加载性能。\n\n'
            '您可以选择一张图片，应用会自动解析并展示其详细的拍摄信息。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: '功能说明',
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
                    child: _buildPreviewImage(),
                  ),
                  const SizedBox(height: 8),
                  // Use path package for reliable file name extraction
                  Text(
                    p.basename(_selectedImage!.path),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildPreviewImage() {
    // 如果有预览图字节，优先尝试渲染
    if (_previewImageBytes != null) {
      try {
        // 使用 Image.memory 并提供 errorBuilder 作为第一层防护
        return Image.memory(
          _previewImageBytes!,
          height: 300,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // 如果解码失败，显示占位符
            return _buildRawImagePlaceholder();
          },
        );
      } catch (e) {
        // 如果发生更底层的异常（如 Invalid image data），也显示占位符
        return _buildRawImagePlaceholder();
      }
    }

    // 如果没有预览图，但有原始图片文件，则尝试直接显示文件
    // 这适用于非RAW格式的普通图片
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        height: 300,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 如果连文件本身都无法渲染，同样显示占位符
          return _buildRawImagePlaceholder();
        },
      );
    }

    // 如果什么都没有，则返回一个空的小部件
    return const SizedBox.shrink();
  }

  Widget _buildRawImagePlaceholder() {
    return Container(
      height: 300,
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.raw_on, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('无法加载RAW预览图', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
