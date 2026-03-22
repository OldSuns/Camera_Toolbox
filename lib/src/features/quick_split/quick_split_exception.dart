/// 自定义异常基类
class QuickSplitException implements Exception {
  final String message;

  QuickSplitException(this.message);

  @override
  String toString() => 'QuickSplitException: $message';
}

/// 目录不存在或无法访问
class DirectoryNotFoundException extends QuickSplitException {
  DirectoryNotFoundException(String path) : super('目录不存在或无法访问: $path');
}

/// 未找到支持的图片文件
class NoImageFilesFoundException extends QuickSplitException {
  NoImageFilesFoundException(String directory)
    : super('在目录 "$directory" 中未找到支持的图片文件 (JPG, HEIF等)。');
}

/// 未找到匹配的RAW文件
class NoMatchingRawFilesException extends QuickSplitException {
  NoMatchingRawFilesException() : super('根据所选图片，未在RAW目录中找到任何同名文件。');
}

/// 输出目录创建失败
class OutputDirectoryCreationException extends QuickSplitException {
  OutputDirectoryCreationException(String path) : super('创建输出目录失败: $path');
}

/// 在指定目录中未找到任何RAW文件
class NoRawFilesFoundException extends QuickSplitException {
  NoRawFilesFoundException(String directory)
    : super('在目录 "$directory" 中未找到任何受支持的RAW文件。');
}

/// 源文件在复制过程中不存在
class SourceFileNotFoundException extends QuickSplitException {
  SourceFileNotFoundException(String path) : super('源文件在复制过程中不存在: $path');
}

/// 文件复制失败
class FileCopyException extends QuickSplitException {
  FileCopyException(String source, String dest, String reason)
    : super('文件复制失败: $source -> $dest, 原因: $reason');
}

/// 用户主动取消处理
class QuickSplitCancelledException extends QuickSplitException {
  QuickSplitCancelledException() : super('快速分片已取消');
}
