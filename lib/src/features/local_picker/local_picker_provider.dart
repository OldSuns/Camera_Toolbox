import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class LocalPickerProvider with ChangeNotifier {
  List<File> _images = [];
  List<File> get images => _images;

  final Set<File> _selectedImages = {};
  Set<File> get selectedImages => _selectedImages;

  double _thumbnailSize = 150.0;
  double get thumbnailSize => _thumbnailSize;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _currentImageIndex = 0;
  int get currentImageIndex => _currentImageIndex;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  double _exportProgress = 0.0;
  double get exportProgress => _exportProgress;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setCurrentImageIndex(int index) {
    _currentImageIndex = index;
    notifyListeners();
  }

  void nextImage() {
    if (_currentImageIndex < _images.length - 1) {
      _currentImageIndex++;
      notifyListeners();
    }
  }

  void previousImage() {
    if (_currentImageIndex > 0) {
      _currentImageIndex--;
      notifyListeners();
    }
  }

  Future<void> selectFolder() async {
    setLoading(true);
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final dir = Directory(selectedDirectory);
        final List<FileSystemEntity> entities = await dir.list().toList();
        _images = entities
            .where(
              (entity) =>
                  entity is File &&
                  p.extension(entity.path).toLowerCase() == '.jpg',
            )
            .map((entity) => entity as File)
            .toList();
        _selectedImages.clear();
      }
    } catch (e) {
      // Handle exceptions
      debugPrint('Error selecting folder: $e');
    } finally {
      setLoading(false);
    }
  }

  void toggleSelection(File image) {
    if (_selectedImages.contains(image)) {
      _selectedImages.remove(image);
    } else {
      _selectedImages.add(image);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedImages.addAll(_images);
    notifyListeners();
  }

  void deselectAll() {
    _selectedImages.clear();
    notifyListeners();
  }

  void invertSelection() {
    final allImages = _images.toSet();
    final currentSelection = _selectedImages.toSet();
    _selectedImages.clear();
    _selectedImages.addAll(allImages.difference(currentSelection));
    notifyListeners();
  }

  void updateThumbnailSize(double size) {
    _thumbnailSize = size;
    notifyListeners();
  }

  Future<void> exportSelected(BuildContext context) async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有选择任何图片')));
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      String? targetDirectory = await FilePicker.platform.getDirectoryPath();
      if (targetDirectory != null) {
        _isExporting = true;
        _exportProgress = 0.0;
        notifyListeners();

        int i = 0;
        for (var imageFile in _selectedImages) {
          final newPath = p.join(targetDirectory, p.basename(imageFile.path));
          await imageFile.copy(newPath);
          i++;
          _exportProgress = i / _selectedImages.length;
          notifyListeners();
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('成功导出 ${_selectedImages.length} 张图片')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
