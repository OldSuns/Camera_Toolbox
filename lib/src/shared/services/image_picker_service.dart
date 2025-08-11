import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// 图片选择服务
/// 提供多种方式选择图片文件
class ImagePickerService {
  /// 使用相机拍照
  static Future<File?> pickImageFromCamera() async {
    try {
      // 首先检查和请求权限
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
        );

        if (pickedFile != null) {
          return File(pickedFile.path);
        }
      } else {
        // 可以选择抛出异常或返回null来通知UI层权限被拒绝
        throw Exception('相机权限被拒绝');
      }
      return null;
    } catch (e) {
      throw Exception('无法访问相机: ${e.toString()}');
    }
  }

  /// 从相册选择图片
  static Future<File?> pickImageFromGallery() async {
    try {
      // 首先检查和请求权限
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
        );

        if (pickedFile != null) {
          return File(pickedFile.path);
        }
      } else {
        throw Exception('相册权限被拒绝');
      }
      return null;
    } catch (e) {
      throw Exception('无法访问相册: ${e.toString()}');
    }
  }

  /// 从相册选择多张图片
  static Future<List<File>> pickMultipleImagesFromGallery() async {
    try {
      // 首先检查和请求权限
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        final picker = ImagePicker();
        final pickedFiles = await picker.pickMultiImage(imageQuality: 100);

        if (pickedFiles.isNotEmpty) {
          return pickedFiles.map((file) => File(file.path)).toList();
        }
      } else {
        throw Exception('相册权限被拒绝');
      }
      return [];
    } catch (e) {
      throw Exception('无法访问相册: ${e.toString()}');
    }
  }

  /// 使用文件选择器选择图片
  static Future<File?> pickImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      throw Exception('无法选择文件: ${e.toString()}');
    }
  }

  /// 获取所有可用的图片选择方式 (已修复逻辑)
  /// 通过检查权限状态而非实际调用来判断可用性。
  static Future<List<String>> getAvailableMethods() async {
    final methods = <String>['文件选择器'];

    // 检查相机权限
    try {
      if (await Permission.camera.isGranted ||
          !(await Permission.camera.isPermanentlyDenied)) {
        methods.add('相机拍照');
      }
    } catch (e) {
      // 忽略异常，方法不可用
    }

    // 检查相册权限
    try {
      if (await Permission.photos.isGranted ||
          await Permission.photos.isLimited ||
          !(await Permission.photos.isPermanentlyDenied)) {
        methods.add('相册选择');
      }
    } catch (e) {
      // 忽略异常，方法不可用
    }

    return methods;
  }

  /// 验证图片文件
  static bool validateImageFile(File? file) {
    if (file == null) return false;

    if (!file.existsSync()) return false;

    final extension = file.path.toLowerCase().split('.').last;
    final supportedExtensions = ['jpg', 'jpeg', 'png', 'tiff', 'tif', 'webp'];

    return supportedExtensions.contains(extension);
  }

  /// 获取图片文件信息 (已修复: 使用异步stat)
  static Future<Map<String, dynamic>> getFileInfo(File file) async {
    final stat = await file.stat();

    return {
      'path': file.path,
      'name': file.path.split('/').last,
      'size': stat.size,
      'modified': stat.modified,
      'extension': file.path.split('.').last.toLowerCase(),
    };
  }
}
