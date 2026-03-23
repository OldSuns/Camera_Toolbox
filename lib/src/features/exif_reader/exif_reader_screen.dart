import 'dart:io';
import 'dart:ui' as ui;

import 'package:exif_reader/exif_reader.dart' as exif_reader;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'exif_data.dart';
import 'exif_service.dart';
import '../../shared/services/image_picker_service.dart';
import '../../shared/widgets/feature_page_layout.dart';
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
  Size? _previewImageSize;
  Size? _sourceImageSize;
  int _previewRotationQuarterTurns = 0;
  Map<String, String> _basicImageInfo = const {};
  bool _isLoading = false;
  String? _errorMessage;

  bool get _supportsGallerySelection =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

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
    await _pickAndLoadImage(
      _supportsGallerySelection
          ? ImagePickerService.pickImageFromGallery
          : ImagePickerService.pickImageFromFile,
    );
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
      _previewImageSize = null;
      _sourceImageSize = null;
      _previewRotationQuarterTurns = 0;
      _basicImageInfo = const {};
      _errorMessage = null;
      _isLoading = true; // Ensure loading indicator is shown
    });

    try {
      final imageInfo = await ExifService.getImageInfo(image.path);
      final exifData = await ExifService.readExifFromFile(image.path);
      final previewImageSize = await _decodeEmbeddedPreviewSize(
        exifData.thumbnailBytes,
      );
      final sourceImageSize = await _decodeFileImageSize(image);
      final previewRotationQuarterTurns = _resolvePreviewRotationQuarterTurns(
        exifData,
      );
      if (mounted) {
        setState(() {
          _basicImageInfo = imageInfo;
          _exifData = exifData;
          _previewImageBytes = exifData.thumbnailBytes;
          _previewImageSize = previewImageSize;
          _sourceImageSize = sourceImageSize;
          _previewRotationQuarterTurns = previewRotationQuarterTurns;
          _errorMessage = exifData.hasExif
              ? null
              : (exifData.errorMessage ?? '未读取到EXIF信息');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _basicImageInfo = const {};
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
      _previewImageSize = null;
      _sourceImageSize = null;
      _previewRotationQuarterTurns = 0;
      _basicImageInfo = const {};
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
    return FeaturePageLayout(
      title: '图片EXIF信息阅读器',
      actions: [
        FilledButton.icon(
          onPressed: _isLoading ? null : _selectImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(_supportsGallerySelection ? '选择图片' : '选择文件'),
        ),
        if (_exifData?.translatedData.isNotEmpty ?? false)
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
      child: _buildBody(),
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_supportsGallerySelection) ...[
                  ElevatedButton.icon(
                    onPressed: _selectImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('从相册选择'),
                  ),
                  const SizedBox(width: 16),
                ],
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
          if (_errorMessage != null) ...[
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.orange),
                title: Text(_errorMessage!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildBasicInfoCard(),
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

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '文件信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('文件名', p.basename(_selectedImage!.path)),
            ..._basicImageInfo.entries.map(
              (entry) => _buildInfoRow(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final previewHeight = (availableWidth * 0.62).clamp(220.0, 300.0);
        final aspectRatio = _resolvedPreviewAspectRatio();
        final previewWidth = aspectRatio == null
            ? availableWidth
            : (previewHeight * aspectRatio).clamp(0.0, availableWidth);
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final targetWidth = (previewWidth * devicePixelRatio).round();
        final targetHeight = (previewHeight * devicePixelRatio).round();
        final shouldUseEmbeddedPreview = _shouldUseEmbeddedPreview(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );

        return Center(
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: shouldUseEmbeddedPreview && _previewImageBytes != null
                ? _buildEmbeddedPreview()
                : _buildFilePreview(
                    cacheWidth: targetWidth,
                    cacheHeight: targetHeight,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmbeddedPreview() {
    return _applyPreviewRotation(
      Image.memory(
        _previewImageBytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return _buildRawImagePlaceholder();
        },
      ),
    );
  }

  Widget _applyPreviewRotation(Widget child) {
    if (_previewRotationQuarterTurns == 0) {
      return child;
    }
    return RotatedBox(quarterTurns: _previewRotationQuarterTurns, child: child);
  }

  Widget _buildFilePreview({
    required int cacheWidth,
    required int cacheHeight,
  }) {
    return _applyPreviewRotation(
      Image.file(
        _selectedImage!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheWidth > 0 ? cacheWidth : null,
        cacheHeight: cacheHeight > 0 ? cacheHeight : null,
        errorBuilder: (context, error, stackTrace) {
          if (_previewImageBytes != null) {
            return _buildEmbeddedPreview();
          }
          return _buildRawImagePlaceholder();
        },
      ),
    );
  }

  Widget _buildRawImagePlaceholder() {
    return Container(
      height: double.infinity,
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

  bool _shouldUseEmbeddedPreview({
    required int targetWidth,
    required int targetHeight,
  }) {
    if (_previewImageBytes == null || _selectedImage == null) {
      return false;
    }

    if (_isRawLikeFile(_selectedImage!.path)) {
      return true;
    }

    if (_previewImageSize == null) {
      return false;
    }

    return _previewImageSize!.width >= targetWidth * 0.75 ||
        _previewImageSize!.height >= targetHeight * 0.75;
  }

  bool _isRawLikeFile(String filePath) {
    const rawExtensions = {
      'arw',
      'raw',
      'dng',
      'crw',
      'cr2',
      'cr3',
      'nrw',
      'nef',
      'raf',
      'orf',
      'rw2',
      'pef',
      'ptx',
      'srf',
      'sr2',
      'srw',
      'gpr',
      '3fr',
      'fff',
      'dcr',
      'kdc',
      'mrw',
      'mos',
      'x3f',
    };
    return rawExtensions.contains(filePath.toLowerCase().split('.').last);
  }

  double? _resolvedPreviewAspectRatio() {
    final sourceImageSize = _rotatedPreviewSize(_sourceImageSize);
    if (sourceImageSize != null &&
        sourceImageSize.width > 0 &&
        sourceImageSize.height > 0) {
      return sourceImageSize.width / sourceImageSize.height;
    }

    final previewImageSize = _rotatedPreviewSize(_previewImageSize);
    if (previewImageSize != null &&
        previewImageSize.width > 0 &&
        previewImageSize.height > 0) {
      return previewImageSize.width / previewImageSize.height;
    }

    final exifWidth = _tryParseDimension(_exifData?.translatedData['图片宽度']);
    final exifHeight = _tryParseDimension(_exifData?.translatedData['图片高度']);
    if (exifWidth != null && exifHeight != null && exifHeight > 0) {
      return exifWidth / exifHeight;
    }

    return null;
  }

  Size? _rotatedPreviewSize(Size? size) {
    if (size == null) {
      return null;
    }
    if (_previewRotationQuarterTurns.isOdd) {
      return Size(size.height, size.width);
    }
    return size;
  }

  int _resolvePreviewRotationQuarterTurns(ExifData exifData) {
    final orientationValue = exifData.rawData['Image Orientation'];
    final orientation = _parseExifOrientation(orientationValue);
    switch (orientation) {
      case 6:
        return 1;
      case 3:
        return 2;
      case 8:
        return 3;
      default:
        return 0;
    }
  }

  int? _parseExifOrientation(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is exif_reader.IfdTag) {
      final values = value.values.toList();
      if (values.isEmpty) {
        return null;
      }
      final first = values.first;
      if (first is num) {
        return first.toInt();
      }
    }

    if (value is num) {
      return value.toInt();
    }

    final text = value.toString();
    final match = RegExp(r'\d+').firstMatch(text);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }

  double? _tryParseDimension(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(value);
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!);
  }

  Future<Size?> _decodeEmbeddedPreviewSize(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<Size?> _decodeFileImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return _decodeImageSize(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return null;
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }
}
