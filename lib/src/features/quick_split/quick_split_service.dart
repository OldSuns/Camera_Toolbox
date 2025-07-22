import 'dart:io';
import 'quick_split_exception.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

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

    // 创建输出目录并预加载现有文件名
    final outputDir = Directory(outputDirectory);
    final existingFiles = <String>{};
    try {
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      } else {
        await for (final entity in outputDir.list(recursive: false)) {
          if (entity is File) {
            existingFiles.add(path.basename(entity.path));
          }
        }
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

      // 移除循环内的存在性检查，因为_matchRawFiles已经处理
      // final rawFile = File(match.rawPath);
      // final rawExists = await rawFile.exists();
      // if (!rawExists) {
      //   throw SourceFileNotFoundException(match.rawPath);
      // }

      // 处理文件冲突
      final finalDestPath = await _handleFileConflict(
        destPath,
        conflictAction,
        match.rawPath,
        existingFiles, // 传递预加载的文件名集合
      );

      if (finalDestPath.isNotEmpty) {
        // 如果是覆盖操作，先删除已存在的文件
        if (conflictAction == ConflictAction.overwrite &&
            await File(finalDestPath).exists()) {
          try {
            await File(finalDestPath).delete();
          } catch (e) {
            throw FileCopyException(
              match.rawPath,
              finalDestPath,
              '删除已存在文件失败: $e',
            );
          }
        }

        await _copyFileWithProgress(match.rawPath, finalDestPath, (
          copied,
          total,
        ) {
          // 这里可以添加单个文件的进度
        });
        // 如果是重命名，需要将新文件名添加到集合中
        if (conflictAction == ConflictAction.rename &&
            !existingFiles.contains(path.basename(finalDestPath))) {
          existingFiles.add(path.basename(finalDestPath));
        }
      }

      processed++;
      onProgress(processed, matches.length);
    }
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
    // 修复：改为非递归扫描，只扫描指定目录
    await for (final entity in dir.list(recursive: false)) {
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

    // 优化: 使用Set进行O(1)复杂度的查找
    final rawFileMap = <String, String>{};
    try {
      // 修复：改为非递归扫描，只扫描rawDirectory指定的目录
      await for (final entity in rawDir.list(recursive: false)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedRawFormats.contains(extension)) {
            final rawName = path
                .basenameWithoutExtension(entity.path)
                .toLowerCase();
            rawFileMap[rawName] = entity.path;
          }
        }
      }
    } catch (e) {
      // 捕获列出文件时的潜在错误
      throw DirectoryNotFoundException(rawDirectory);
    }

    if (rawFileMap.isEmpty) {
      throw NoRawFilesFoundException(rawDirectory);
    }

    final rawFileNames = rawFileMap.keys.toSet();

    // 匹配文件 - O(N)
    for (final imageFile in imageFiles) {
      final imageName = path.basenameWithoutExtension(imageFile).toLowerCase();
      if (rawFileNames.contains(imageName)) {
        final rawPath = rawFileMap[imageName]!;
        matches.add(RawMatch(imagePath: imageFile, rawPath: rawPath));
      }
    }

    return matches;
  }

  /// 处理文件冲突
  Future<String> _handleFileConflict(
    String destPath,
    ConflictAction action,
    String sourcePath,
    Set<String> existingFileNames, // 接收预加载的文件名集合
  ) async {
    final fileName = path.basename(destPath);
    final exists = existingFileNames.contains(fileName);

    if (!exists) {
      return destPath;
    }

    switch (action) {
      case ConflictAction.overwrite:
        return destPath;

      case ConflictAction.skip:
        return '';

      case ConflictAction.rename:
        final dir = path.dirname(destPath);
        final name = path.basenameWithoutExtension(destPath);
        final ext = path.extension(destPath);

        int counter = 1;
        String newFileName;
        do {
          newFileName = '${name}_$counter$ext';
          counter++;
        } while (existingFileNames.contains(newFileName));

        return path.join(dir, newFileName);
    }
  }

  /// 带进度拷贝文件
  Future<void> _copyFileWithProgress(
    String sourcePath,
    String destPath,
    Function(int copied, int total) onProgress,
  ) async {
    final sourceFile = File(sourcePath);

    // 验证源文件存在
    final sourceExists = await sourceFile.exists();
    if (!sourceExists) {
      throw SourceFileNotFoundException(sourcePath);
    }

    final sourceSize = await sourceFile.length();

    // 验证目标目录存在
    final destDir = File(destPath).parent;
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // 使用try-catch捕获具体的文件操作异常
    try {
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

      // 验证目标文件已创建且大小正确
      final destFileCheck = File(destPath);
      final destExists = await destFileCheck.exists();
      if (!destExists) {
        throw FileCopyException(sourcePath, destPath, '目标文件未成功创建');
      }

      final destSize = await destFileCheck.length();
      if (destSize != sourceSize) {
        throw FileCopyException(
          sourcePath,
          destPath,
          '文件大小不匹配: $destSize != $sourceSize',
        );
      }
    } on PathNotFoundException catch (e) {
      // 专门处理PathNotFoundException
      if (e.path == sourcePath) {
        throw SourceFileNotFoundException(sourcePath);
      } else {
        throw FileCopyException(sourcePath, destPath, '路径不存在: ${e.path}');
      }
    } on FileSystemException catch (e) {
      // 处理文件系统异常
      throw FileCopyException(sourcePath, destPath, '文件系统错误: ${e.message}');
    } catch (e) {
      // 处理其他异常
      throw FileCopyException(sourcePath, destPath, '未知错误: $e');
    }
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
