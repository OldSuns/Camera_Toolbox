import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

/// 文件选择服务 - 混合使用file_picker和file_selector以实现最佳兼容性
class FileSelectorService {
  /// 选择单个目录 - 使用file_picker以获取真实路径
  static Future<String?> selectDirectory() async {
    final directory = await FilePicker.platform.getDirectoryPath();
    return directory;
  }

  /// 选择多个目录
  static Future<List<String>?> selectMultipleDirectories() async {
    final directories = await getDirectoryPaths();
    return directories.map((e) => e.toString()).toList();
  }

  /// 选择单个文件
  static Future<String?> selectFile({
    List<String>? allowedExtensions,
    String? initialDirectory,
  }) async {
    final extensions =
        allowedExtensions ?? ['jpg', 'jpeg', 'png', 'tiff', 'tif'];
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'Images',
      extensions: extensions,
    );

    final file = await openFile(
      acceptedTypeGroups: [typeGroup],
      initialDirectory: initialDirectory,
    );

    return file?.path;
  }

  /// 选择多个文件
  static Future<List<String>?> selectMultipleFiles({
    List<String>? allowedExtensions,
    String? initialDirectory,
  }) async {
    final extensions =
        allowedExtensions ?? ['jpg', 'jpeg', 'png', 'tiff', 'tif'];
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'Images',
      extensions: extensions,
    );

    final files = await openFiles(
      acceptedTypeGroups: [typeGroup],
      initialDirectory: initialDirectory,
    );

    return files.map((file) => file.path).toList();
  }

  /// 检查目录是否存在且有权限访问
  static Future<bool> checkDirectoryAccess(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      return await directory.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取目录中的文件列表
  static Future<List<String>> getFilesInDirectory(
    String directoryPath, {
    List<String>? allowedExtensions,
  }) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return [];
      }

      final files = <String>[];
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final pathParts = entity.path.split('.');
          if (pathParts.length > 1) {
            final extension = pathParts.last.toLowerCase();
            if (allowedExtensions == null ||
                allowedExtensions.contains(extension)) {
              files.add(entity.path);
            }
          }
        }
      }

      return files;
    } catch (e) {
      return [];
    }
  }
}
