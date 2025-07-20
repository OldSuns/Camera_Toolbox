import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// 图片选择服务
/// 提供多种方式选择图片文件
class ImagePickerService {
  /// 使用相机拍照
  static Future<File?> pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('无法访问相机: ${e.toString()}');
    }
  }

  /// 从相册选择图片
  static Future<File?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('无法访问相册: ${e.toString()}');
    }
  }

  /// 使用文件选择器选择图片
  static Future<File?> pickImageFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
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

  /// 获取所有可用的图片选择方式
  static Future<List<String>> getAvailableMethods() async {
    final methods = <String>['文件选择器'];

    // 检查相机权限
    try {
      final picker = ImagePicker();
      final status = await picker.pickImage(source: ImageSource.camera);
      if (status != null) {
        methods.add('相机拍照');
      }
    } catch (e) {
      // 相机不可用
    }

    // 检查相册权限
    try {
      final picker = ImagePicker();
      final status = await picker.pickImage(source: ImageSource.gallery);
      if (status != null) {
        methods.add('相册选择');
      }
    } catch (e) {
      // 相册不可用
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

  /// 获取图片文件信息
  static Map<String, dynamic> getFileInfo(File file) {
    final stat = file.statSync();

    return {
      'path': file.path,
      'name': file.path.split('/').last,
      'size': stat.size,
      'modified': stat.modified,
      'extension': file.path.split('.').last.toLowerCase(),
    };
  }
}
