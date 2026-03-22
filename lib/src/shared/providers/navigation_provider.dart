import 'package:flutter/material.dart';

/// 导航状态管理
class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) {
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }
}

/// 应用页面枚举
enum AppPage {
  exifReader,
  localPicker,
  rawManager,
  batchRename,
  photoWatermark,
  imageCompress,
  settings,
  about,
}

extension AppPageExtension on AppPage {
  String get title {
    switch (this) {
      case AppPage.exifReader:
        return 'Exif读取器';
      case AppPage.localPicker:
        return '本地选片';
      case AppPage.rawManager:
        return '快速分片';
      case AppPage.batchRename:
        return '批量重命名';
      case AppPage.photoWatermark:
        return '照片水印';
      case AppPage.imageCompress:
        return '图像压缩';
      case AppPage.settings:
        return '设置';
      case AppPage.about:
        return '关于';
    }
  }

  IconData get icon {
    switch (this) {
      case AppPage.exifReader:
        return Icons.photo_camera;
      case AppPage.localPicker:
        return Icons.photo_library_outlined;
      case AppPage.rawManager:
        return Icons.folder;
      case AppPage.batchRename:
        return Icons.text_format;
      case AppPage.photoWatermark:
        return Icons.photo_filter;
      case AppPage.imageCompress:
        return Icons.compress;
      case AppPage.settings:
        return Icons.settings;
      case AppPage.about:
        return Icons.info_outline;
    }
  }
}
