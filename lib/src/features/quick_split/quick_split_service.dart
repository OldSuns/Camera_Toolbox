import 'dart:io';
import 'quick_split_exception.dart';
import 'package:path/path.dart' as path;

/// 快速分片服务 - 处理JPG-RAW文件匹配和拷贝
class QuickSplitService {
  final List<String> supportedRawFormats = [
    '.raw', '.crw', // Canon
    '.cr2', '.cr3', // Canon
    '.nef', '.nrw', // Nikon
    '.arw', '.srf', '.sr2', // Sony
    '.dng', // Adobe
    '.raf', // Fujifilm
    '.orf', // Olympus
    '.rw2', // Panasonic
    '.pef', '.ptx', // Pentax
    '.kdc', // Kodak
  ];

  bool _isCancelled = false;

  /// 处理文件匹配和拷贝
  Future<void> processFiles({
    required String imageDirectory,
    required String rawDirectory,
    required String outputDirectory,
    required Function(int processed, int total) onProgress,
    ConflictAction conflictAction = ConflictAction.rename,
  }) async {
    _isCancelled = false;

    // 扫描图片文件
    final imageFiles = await _scanImageFiles(imageDirectory);
    if (imageFiles.isEmpty) {
      throw NoImageFilesFoundException(imageDirectory);
    }

    // 匹配RAW文件
    final matches = await _matchRawFiles(imageFiles, rawDirectory);
    if (matches.isEmpty) {
      throw NoMatchingRawFilesException();
    }

    // 创建输出目录
    try {
      final outputDir = Directory(outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
    } catch (e) {
      throw OutputDirectoryCreationException(outputDirectory);
    }

    // 处理文件拷贝
    int processed = 0;
    for (final match in matches) {
      if (_isCancelled) break;

      final fileName = path.basename(match.rawPath);
      final destPath = path.join(outputDirectory, fileName);

      // 处理文件冲突
      final finalDestPath = await _handleFileConflict(destPath, conflictAction);

      if (finalDestPath.isNotEmpty) {
        await _copyFileWithProgress(match.rawPath, finalDestPath, (
          copied,
          total,
        ) {
          // 这里可以添加单个文件的进度
        });
      }

      processed++;
      onProgress(processed, matches.length);
    }
    // 不再捕-捕获和重新抛出通用异常，让自定义异常传递到UI层
  }

  /// 取消处理
  void cancel() {
    _isCancelled = true;
  }

  /// 扫描图片文件
  Future<List<String>> _scanImageFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      throw DirectoryNotFoundException(directory);
    }

    final files = <String>[];
    final supportedExtensions = ['.jpg', '.jpeg', '.heif', '.heic'];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(extension)) {
          files.add(entity.path);
        }
      }
    }

    return files;
  }

  /// 匹配RAW文件
  Future<List<RawMatch>> _matchRawFiles(
    List<String> imageFiles,
    String rawDirectory,
  ) async {
    final matches = <RawMatch>[];
    final rawDir = Directory(rawDirectory);

    if (!await rawDir.exists()) {
      throw DirectoryNotFoundException(rawDirectory);
    }

    // 获取所有RAW文件
    final rawFiles = <String>[];
    try {
      await for (final entity in rawDir.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedRawFormats.contains(extension)) {
            rawFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      // 捕获列出文件时的潜在错误
      throw DirectoryNotFoundException(rawDirectory);
    }

    if (rawFiles.isEmpty) {
      throw NoRawFilesFoundException(rawDirectory);
    }

    // 匹配文件
    for (final imageFile in imageFiles) {
      final imageName = path.basenameWithoutExtension(imageFile).toLowerCase();

      for (final rawFile in rawFiles) {
        final rawName = path.basenameWithoutExtension(rawFile).toLowerCase();
        if (imageName == rawName) {
          matches.add(RawMatch(imagePath: imageFile, rawPath: rawFile));
          break;
        }
      }
    }

    return matches;
  }

  /// 处理文件冲突
  Future<String> _handleFileConflict(
    String destPath,
    ConflictAction action,
  ) async {
    final file = File(destPath);
    final exists = await file.exists();

    if (!exists) {
      return destPath;
    }

    switch (action) {
      case ConflictAction.overwrite:
        await file.delete();
        return destPath;

      case ConflictAction.skip:
        return '';

      case ConflictAction.rename:
        final dir = path.dirname(destPath);
        final name = path.basenameWithoutExtension(destPath);
        final ext = path.extension(destPath);

        int counter = 1;
        String newPath;
        do {
          newPath = path.join(dir, '${name}_$counter$ext');
          counter++;
        } while (await File(newPath).exists());

        return newPath;
    }
  }

  /// 带进度拷贝文件
  Future<void> _copyFileWithProgress(
    String sourcePath,
    String destPath,
    Function(int copied, int total) onProgress,
  ) async {
    final sourceFile = File(sourcePath);
    final sourceSize = await sourceFile.length();

    final sourceStream = sourceFile.openRead();
    final destFile = File(destPath).openWrite();

    int bytesCopied = 0;
    await for (final chunk in sourceStream) {
      if (_isCancelled) break;

      destFile.add(chunk);
      bytesCopied += chunk.length;
      onProgress(bytesCopied, sourceSize);
    }

    await destFile.close();
  }
}

/// 文件匹配结果
class RawMatch {
  final String imagePath;
  final String rawPath;

  RawMatch({required this.imagePath, required this.rawPath});
}

/// 文件冲突处理策略
enum ConflictAction {
  overwrite, // 覆盖
  skip, // 跳过
  rename, // 重命名
}
