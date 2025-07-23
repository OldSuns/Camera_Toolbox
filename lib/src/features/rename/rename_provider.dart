import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';
import '../exif_reader/exif_service.dart';
import '../../shared/services/file_selector_service.dart';
import 'replace_rule.dart';

// Isolate的入口函数必须是顶层函数或静态方法
Future<Map<String, dynamic>> _renameWorker(Map<String, dynamic> params) async {
  // 解包文件列表以进行迭代
  final filesData = params['files'] as List<Map<String, dynamic>>;
  final files = filesData.map((data) => FileDetail.fromJson(data)).toList();

  int successCount = 0;
  int failedCount = 0;
  final List<Map<String, String>> renameLog = [];
  final List<Map<String, String>> failedFiles = [];

  for (int i = 0; i < files.length; i++) {
    final fileDetail = files[i];
    final oldPath = fileDetail.file.path;
    try {
      // 调用静态方法获取新文件名，避免创建Provider实例
      final newName = RenameProvider._getNewNameForWorker(
        params,
        fileDetail,
        i,
        files,
      );
      final newPath =
          '${fileDetail.file.parent.path}${Platform.pathSeparator}$newName';

      if (oldPath != newPath) {
        if (await File(newPath).exists()) {
          const error = 'File already exists';
          debugPrint('$error: $newPath, skipping rename.');
          failedCount++;
          failedFiles.add({'path': oldPath, 'error': error});
          continue;
        }
        await fileDetail.file.rename(newPath);
        renameLog.add({'oldPath': oldPath, 'newPath': newPath});
      }
      successCount++;
    } on FileSystemException catch (e) {
      final error = e.osError?.message ?? e.message;
      debugPrint('Failed to rename ${fileDetail.file.path}: $error');
      failedCount++;
      failedFiles.add({'path': oldPath, 'error': error});
    } catch (e) {
      final error = e.toString();
      debugPrint('Failed to rename ${fileDetail.file.path}: $error');
      failedCount++;
      failedFiles.add({'path': oldPath, 'error': error});
    }
  }

  return {
    'success': successCount,
    'failed': failedCount,
    'renameLog': renameLog,
    'failedFiles': failedFiles,
  };
}

// 定义排序标准枚举
enum SortCriterion { nameAsc, nameDesc, dateAsc, dateDesc }

// 定义追加模式枚举
enum AppendMode { afterFilename, beforeExtension }

// 定义自动序号类型枚举
enum NumberingType {
  arabic,
  upperRoman,
  lowerRoman,
  upperLetter,
  lowerLetter;

  String get displayName {
    switch (this) {
      case NumberingType.arabic:
        return '阿拉伯数字';
      case NumberingType.upperRoman:
        return '大写罗马';
      case NumberingType.lowerRoman:
        return '小写罗马';
      case NumberingType.upperLetter:
        return '大写字母';
      case NumberingType.lowerLetter:
        return '小写字母';
    }
  }
}

// 定义文件详情模型
class FileDetail {
  final File file;
  final int size;
  final DateTime lastModified;

  FileDetail({
    required this.file,
    required this.size,
    required this.lastModified,
  });

  factory FileDetail.fromJson(Map<String, dynamic> json) {
    return FileDetail(
      file: File(json['path']),
      size: json['size'],
      lastModified: DateTime.parse(json['lastModified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': file.path,
      'size': size,
      'lastModified': lastModified.toIso8601String(),
    };
  }
}

class RenameProvider with ChangeNotifier {
  // 内部构造函数，仅用于在 isolate 中创建实例
  RenameProvider._internal();

  // 公共工厂构造函数
  factory RenameProvider() {
    return RenameProvider._internal().._init();
  }

  void _init() {
    // 可以在这里进行一些初始化
  }

  // Worker的静态入口，用于计算新文件名
  static String _getNewNameForWorker(
    Map<String, dynamic> params,
    FileDetail fileDetail,
    int index,
    List<FileDetail> files,
  ) {
    final fileName = fileDetail.file.uri.pathSegments.last;
    final activeTabIndex = params['activeTabIndex'] as int;

    switch (activeTabIndex) {
      case 0: // 替换
        final replaceRules =
            (params['replaceRules'] as List<Map<String, dynamic>>)
                .map((r) => ReplaceRule.fromJson(r))
                .toList();
        return _applyReplaceRule(fileName, replaceRules);
      case 1: // 追加
        final appendPrefix = params['appendPrefix'] as String;
        final appendSuffix = params['appendSuffix'] as String;
        final appendAfterFilename = params['appendAfterFilename'] as bool;
        return _applyAppendRule(
          fileName,
          appendPrefix,
          appendSuffix,
          appendAfterFilename,
        );
      case 2: // 自动序号
        final numberingPrefix = params['numberingPrefix'] as String;
        final numberingSuffix = params['numberingSuffix'] as String;
        final startNumber = params['startNumber'] as int;
        final numberingType = params['numberingType'] as NumberingType;
        final fixedDigits = params['fixedDigits'] as int;
        final keepOriginalName = params['keepOriginalName'] as bool;
        final mergeSameName = params['mergeSameName'] as bool;
        final mergedNumberingCache =
            params['mergedNumberingCache'] as Map<String, int>;
        return _applyAutoNumberingRule(
          fileName,
          index,
          files,
          startNumber,
          mergeSameName,
          numberingType,
          fixedDigits,
          keepOriginalName,
          numberingPrefix,
          numberingSuffix,
          mergedNumberingCache,
        );
      case 3: // EXIF命名
        final exifTemplate = params['exifTemplate'] as String;
        final exifCache =
            params['exifCache'] as Map<String, Map<String, dynamic>>;
        final mergeSameName = params['mergeSameName'] as bool;
        final startNumber = params['startNumber'] as int;
        final numberingPrefix = params['numberingPrefix'] as String;
        final numberingSuffix = params['numberingSuffix'] as String;
        final numberingType = params['numberingType'] as NumberingType;
        final fixedDigits = params['fixedDigits'] as int;

        final mergedNumberingCache =
            params['mergedNumberingCache'] as Map<String, int>;
        return _applyExifNamingRule(
          fileDetail,
          index,
          files,
          exifTemplate,
          exifCache,
          mergeSameName,
          startNumber,
          numberingPrefix,
          numberingSuffix,
          numberingType,
          fixedDigits,
          mergedNumberingCache,
        );
      default:
        return fileName;
    }
  }

  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  void setActiveTabIndex(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  final List<FileDetail> _files = [];
  List<FileDetail> get files => _files;

  List<Map<String, String>> _lastRenameLog = [];
  List<Map<String, String>> get lastRenameLog => _lastRenameLog;

  List<Map<String, String>> _lastFailedFiles = [];
  List<Map<String, String>> get lastFailedFiles => _lastFailedFiles;

  bool _mergeSameName = false;
  bool get mergeSameName => _mergeSameName;

  void setMergeSameName(bool value) {
    _mergeSameName = value;
    if (_mergeSameName) {
      _precalculateMergedNumbering();
    }
    notifyListeners();
  }

  SortCriterion _sortCriterion = SortCriterion.nameAsc;
  SortCriterion get sortCriterion => _sortCriterion;

  // 替换规则列表
  final List<ReplaceRule> _replaceRules = [ReplaceRule()];
  // 追加功能相关状态
  String _appendPrefix = '';
  String get appendPrefix => _appendPrefix;

  String _appendSuffix = '';
  String get appendSuffix => _appendSuffix;

  bool _appendAfterFilename = false;
  bool get appendAfterFilename => _appendAfterFilename;
  List<ReplaceRule> get replaceRules => _replaceRules;
  // 自动序号功能相关状态
  String _numberingPrefix = '';
  String get numberingPrefix => _numberingPrefix;

  String _numberingSuffix = '';
  String get numberingSuffix => _numberingSuffix;

  int _startNumber = 1;
  int get startNumber => _startNumber;

  NumberingType _numberingType = NumberingType.arabic;
  NumberingType get numberingType => _numberingType;

  int _fixedDigits = 0;
  int get fixedDigits => _fixedDigits;

  bool _keepOriginalName = false;
  bool get keepOriginalName => _keepOriginalName;

  // EXIF命名相关状态
  String _exifTemplate = '';
  String get exifTemplate => _exifTemplate;

  final Map<String, Map<String, dynamic>> _exifCache = {};
  final Map<String, int> _mergedNumberingCache = {};

  void setExifTemplate(String template) {
    _exifTemplate = template;
    notifyListeners();
  }

  Future<void> loadExifData(File file, {bool notify = true}) async {
    if (_exifCache.containsKey(file.path)) return;
    if (!ExifService.isSupportedImage(file.path)) return;

    try {
      final exifData = await ExifService.readExifFromFile(file.path);
      if (exifData.hasExif) {
        _exifCache[file.path] = exifData.translatedData;
      } else {
        _exifCache[file.path] = {}; // 存一个空map表示没有EXIF
      }
    } catch (e) {
      debugPrint('Failed to load EXIF for ${file.path}: $e');
      _exifCache[file.path] = {}; // 出错也存空map
    }
    // 当EXIF数据加载完成时，通知UI刷新以显示可能更新的预览
    if (notify) {
      notifyListeners();
    }
  }

  // 添加替换规则
  void addReplaceRule() {
    _replaceRules.add(ReplaceRule());
    notifyListeners();
  }

  // 删除替换规则
  void removeReplaceRule(int index) {
    if (_replaceRules.length > 1) {
      _replaceRules.removeAt(index);
      notifyListeners();
    }
  }

  // 更新替换规则的查找文本
  void updateFindText(int index, String text) {
    if (index >= 0 && index < _replaceRules.length) {
      _replaceRules[index] = _replaceRules[index].copyWith(findText: text);
      notifyListeners();
    }
  }

  // 更新替换规则的替换文本
  void updateReplaceText(int index, String text) {
    if (index >= 0 && index < _replaceRules.length) {
      _replaceRules[index] = _replaceRules[index].copyWith(replaceText: text);
      notifyListeners();
    }
  }

  // 更新替换规则的允许替换扩展名选项
  void updateAllowReplaceExtension(int index, bool value) {
    if (index >= 0 && index < _replaceRules.length) {
      _replaceRules[index] = _replaceRules[index].copyWith(
        allowReplaceExtension: value,
      );
      notifyListeners();
    }
  }

  // 更新追加前缀
  void setAppendPrefix(String text) {
    _appendPrefix = text;
    notifyListeners();
  }

  // 更新自动序号前缀
  void setNumberingPrefix(String text) {
    _numberingPrefix = text;
    notifyListeners();
  }

  // 更新自动序号后缀
  void setNumberingSuffix(String text) {
    _numberingSuffix = text;
    notifyListeners();
  }

  // 更新起始序号
  void setStartNumber(int number) {
    _startNumber = number;
    notifyListeners();
  }

  // 更新序号类型
  void setNumberingType(NumberingType type) {
    _numberingType = type;
    notifyListeners();
  }

  // 更新固定位数
  void setFixedDigits(int digits) {
    _fixedDigits = digits;
    notifyListeners();
  }

  // 设置是否保留原文件名
  void setKeepOriginalName(bool value) {
    _keepOriginalName = value;
    notifyListeners();
  }

  // 更新追加后缀
  void setAppendSuffix(String text) {
    _appendSuffix = text;
    notifyListeners();
  }

  // 更新追加模式
  void setAppendAfterFilename(bool value) {
    _appendAfterFilename = value;
    notifyListeners();
  }

  // 预览重命名结果
  String previewRename(FileDetail fileDetail, int index) {
    final fileName = fileDetail.file.uri.pathSegments.last;

    switch (_activeTabIndex) {
      case 0: // 替换
        return _applyReplaceRule(fileName, _replaceRules);
      case 1: // 追加
        return _applyAppendRule(
          fileName,
          _appendPrefix,
          _appendSuffix,
          _appendAfterFilename,
        );
      case 2: // 自动序号
        return _applyAutoNumberingRule(
          fileName,
          index,
          _files,
          _startNumber,
          _mergeSameName,
          _numberingType,
          _fixedDigits,
          _keepOriginalName,
          _numberingPrefix,
          _numberingSuffix,
          _mergedNumberingCache,
        );
      case 3: // EXIF命名
        return _applyExifNamingRule(
          fileDetail,
          index,
          _files,
          _exifTemplate,
          _exifCache,
          _mergeSameName,
          _startNumber,
          _numberingPrefix,
          _numberingSuffix,
          _numberingType,
          _fixedDigits,
          _mergedNumberingCache,
        );
      default:
        return fileName;
    }
  }

  // 格式化序号的辅助方法
  static String _formatNumber(int number, NumberingType type, int digits) {
    String formattedNumber;
    switch (type) {
      case NumberingType.arabic:
        formattedNumber = number.toString();
        break;
      case NumberingType.upperRoman:
        formattedNumber = _convertIntToRoman(number).toUpperCase();
        break;
      case NumberingType.lowerRoman:
        formattedNumber = _convertIntToRoman(number).toLowerCase();
        break;
      case NumberingType.upperLetter:
        formattedNumber = _convertIntToLetter(number).toUpperCase();
        break;
      case NumberingType.lowerLetter:
        formattedNumber = _convertIntToLetter(number).toLowerCase();
        break;
    }
    if (digits > 0) {
      formattedNumber = formattedNumber.padLeft(digits, '0');
    }
    return formattedNumber;
  }

  // 应用替换规则
  static String _applyReplaceRule(
    String fileName,
    List<ReplaceRule> replaceRules,
  ) {
    String result = fileName;
    for (var rule in replaceRules) {
      if (!rule.allowReplaceExtension) {
        int lastDotIndex = result.lastIndexOf('.');
        if (lastDotIndex != -1) {
          String namePart = result.substring(0, lastDotIndex);
          String extensionPart = result.substring(lastDotIndex);
          result =
              namePart.replaceAll(rule.findText, rule.replaceText) +
              extensionPart;
        } else {
          result = result.replaceAll(rule.findText, rule.replaceText);
        }
      } else {
        result = result.replaceAll(rule.findText, rule.replaceText);
      }
    }
    return result;
  }

  // 应用追加规则
  static String _applyAppendRule(
    String fileName,
    String appendPrefix,
    String appendSuffix,
    bool appendAfterFilename,
  ) {
    if (appendPrefix.isNotEmpty || appendSuffix.isNotEmpty) {
      if (!appendAfterFilename) {
        int lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex != -1) {
          String namePart = fileName.substring(0, lastDotIndex);
          String extensionPart = fileName.substring(lastDotIndex);
          return appendPrefix + namePart + appendSuffix + extensionPart;
        } else {
          return appendPrefix + fileName + appendSuffix;
        }
      } else {
        return appendPrefix + fileName + appendSuffix;
      }
    }
    return fileName;
  }

  // 应用自动序号规则
  static String _applyAutoNumberingRule(
    String fileName,
    int index,
    List<FileDetail> files,
    int startNumber,
    bool mergeSameName,
    NumberingType numberingType,
    int fixedDigits,
    bool keepOriginalName,
    String numberingPrefix,
    String numberingSuffix,
    Map<String, int> mergedNumberingCache,
  ) {
    int currentNumber;
    if (mergeSameName) {
      currentNumber =
          startNumber + (mergedNumberingCache[files[index].file.path] ?? 0);
    } else {
      currentNumber = startNumber + index;
    }

    String formattedNumber = _formatNumber(
      currentNumber,
      numberingType,
      fixedDigits,
    );

    if (keepOriginalName) {
      int lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        String namePart = fileName.substring(0, lastDotIndex);
        String extensionPart = fileName.substring(lastDotIndex);
        return '$numberingPrefix$namePart$formattedNumber$numberingSuffix$extensionPart';
      } else {
        return '$numberingPrefix$fileName$formattedNumber$numberingSuffix';
      }
    } else {
      int lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        String extensionPart = fileName.substring(lastDotIndex);
        return '$numberingPrefix$formattedNumber$numberingSuffix$extensionPart';
      } else {
        return '$numberingPrefix$formattedNumber$numberingSuffix';
      }
    }
  }

  // 应用EXIF命名规则
  static String _applyExifNamingRule(
    FileDetail fileDetail,
    int index,
    List<FileDetail> files,
    String exifTemplate,
    Map<String, Map<String, dynamic>> exifCache,
    bool mergeSameName,
    int startNumber,
    String numberingPrefix,
    String numberingSuffix,
    NumberingType numberingType,
    int fixedDigits,
    Map<String, int> mergedNumberingCache,
  ) {
    if (exifTemplate.isEmpty) {
      return fileDetail.file.uri.pathSegments.last;
    }

    final exifData = exifCache[fileDetail.file.path] ?? {};
    String newName = exifTemplate;

    final RegExp placeholderRegex = RegExp(r'\[(.*?)\]');
    const String notFound = 'NaN';

    newName = newName.replaceAllMapped(placeholderRegex, (match) {
      final placeholder = match.group(1);

      if (placeholder == '序号') {
        int currentNumber;
        if (mergeSameName) {
          currentNumber =
              startNumber + (mergedNumberingCache[fileDetail.file.path] ?? 0);
        } else {
          currentNumber = startNumber + index;
        }
        return '$numberingPrefix${_formatNumber(currentNumber, numberingType, fixedDigits)}$numberingSuffix';
      }

      final shotTime = exifData['拍摄时间'] as String?;
      DateTime? parsedDate;
      if (shotTime != null) {
        try {
          // 尝试多种格式解析
          if (shotTime.contains(' ') && shotTime.contains(':')) {
            parsedDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(shotTime);
          } else {
            parsedDate = DateTime.parse(shotTime);
          }
        } catch (e) {
          debugPrint('Failed to parse date: $shotTime, error: $e');
          // Ignore parsing errors
        }
      }

      switch (placeholder) {
        case '快门速度':
          final shutterSpeed =
              (exifData['快门速度'] as String?) ??
              (exifData['曝光时间'] as String?) ??
              notFound;
          return shutterSpeed.replaceAll('/', '-');
        case '年':
          return parsedDate?.year.toString() ?? notFound;
        case '月':
          return parsedDate?.month.toString().padLeft(2, '0') ?? notFound;
        case '日':
          return parsedDate?.day.toString().padLeft(2, '0') ?? notFound;
        case '时':
          return parsedDate?.hour.toString().padLeft(2, '0') ?? notFound;
        case '分':
          return parsedDate?.minute.toString().padLeft(2, '0') ?? notFound;
        case '秒':
          return parsedDate?.second.toString().padLeft(2, '0') ?? notFound;
        case '年月日':
          if (parsedDate == null) return notFound;
          return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        case '时分秒':
          if (parsedDate == null) return notFound;
          return '${parsedDate.hour.toString().padLeft(2, '0')}-${parsedDate.minute.toString().padLeft(2, '0')}-${parsedDate.second.toString().padLeft(2, '0')}';
        default:
          return (exifData[placeholder] as String? ?? notFound).replaceAll(
            '/',
            '-',
          );
      }
    });

    int lastDotIndex = fileDetail.file.uri.pathSegments.last.lastIndexOf('.');
    if (lastDotIndex != -1) {
      String extensionPart = fileDetail.file.uri.pathSegments.last.substring(
        lastDotIndex,
      );
      return newName + extensionPart;
    } else {
      return newName;
    }
  }

  static String _getBaseName(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    final fileName = path.substring(lastSeparator + 1);
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  void _precalculateMergedNumbering() {
    _mergedNumberingCache.clear();
    if (_files.isEmpty) return;

    final uniqueBaseNames = _files
        .map((f) => RenameProvider._getBaseName(f.file.path))
        .toSet()
        .toList();
    uniqueBaseNames.sort();

    for (final fileDetail in _files) {
      final baseName = RenameProvider._getBaseName(fileDetail.file.path);
      final groupIndex = uniqueBaseNames.indexOf(baseName);
      _mergedNumberingCache[fileDetail.file.path] = groupIndex;
    }
  }

  // 检查文件是否已存在（基于文件名和扩展名的一致性）
  bool _isFileAlreadyAdded(String filePath) {
    return _files.any((existingDetail) => existingDetail.file.path == filePath);
  }

  // 公共方法：检查文件是否已存在
  bool isFileAlreadyAdded(String filePath) {
    return _isFileAlreadyAdded(filePath);
  }

  // 添加文件的方法
  Future<void> addFiles(List<XFile> xFiles) async {
    final List<File> allFilePaths = [];

    // 1. 收集所有文件路径，包括子目录
    for (final xFile in xFiles) {
      final fileEntity = FileSystemEntity.typeSync(xFile.path);
      if (fileEntity == FileSystemEntityType.directory) {
        await _addFilesFromDirectory(
          Directory(xFile.path),
          allFilePaths,
          depth: 0,
        );
      } else if (fileEntity == FileSystemEntityType.file) {
        allFilePaths.add(File(xFile.path));
      }
    }

    // 2. 过滤掉已存在的文件
    final newFiles = allFilePaths
        .where((file) => !_isFileAlreadyAdded(file.path))
        .toList();

    if (newFiles.isEmpty) return;

    // 3. 并行获取文件详情，并限制并发数量
    const concurrencyLimit = 20; // 限制并发数量
    final List<FileDetail> newFileDetails = [];
    for (var i = 0; i < newFiles.length; i += concurrencyLimit) {
      final sublist = (i + concurrencyLimit > newFiles.length)
          ? newFiles.sublist(i)
          : newFiles.sublist(i, i + concurrencyLimit);
      await Future.wait(
        sublist.map((file) async {
          try {
            final size = await file.length();
            final lastModified = await file.lastModified();
            newFileDetails.add(
              FileDetail(file: file, size: size, lastModified: lastModified),
            );
          } catch (e) {
            debugPrint("Error reading file details for ${file.path}: $e");
          }
        }),
      );
    }

    if (newFileDetails.isEmpty) return;

    // 4. 添加文件，排序，并异步加载EXIF，最后统一通知UI
    _files.addAll(newFileDetails);
    _sortFiles();
    if (_mergeSameName) {
      _precalculateMergedNumbering();
    }

    // 立即通知UI，让文件列表先显示出来
    notifyListeners();

    // 异步加载EXIF，但不立即通知UI
    final exifFutures = newFileDetails.map(
      (detail) => loadExifData(detail.file, notify: false),
    );
    // 等待所有EXIF加载完成后，再统一通知UI更新
    Future.wait(exifFutures).then((_) => notifyListeners());
  }

  // 递归获取文件夹中的所有文件
  Future<void> _addFilesFromDirectory(
    Directory directory,
    List<File> fileList, {
    int depth = 0,
  }) async {
    // 控制递归层数最多为两层
    if (depth > 2) {
      return;
    }

    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          fileList.add(entity);
        } else if (entity is Directory) {
          // 递归处理子文件夹，深度加1
          await _addFilesFromDirectory(entity, fileList, depth: depth + 1);
        }
      }
    } catch (e) {
      debugPrint('Error reading directory ${directory.path}: $e');
    }
  }

  // 选择文件的方法
  Future<int> selectFiles() async {
    try {
      final List<String>? filePaths =
          await FileSelectorService.selectMultipleFiles(
            allowedExtensions: null,
          );
      if (filePaths == null) return 0;

      final existingFileCount = filePaths
          .where((path) => _isFileAlreadyAdded(path))
          .length;
      final newFilePaths = filePaths
          .where((path) => !_isFileAlreadyAdded(path))
          .toList();

      if (newFilePaths.isEmpty) return existingFileCount;

      const concurrencyLimit = 20; // 限制并发数量
      final List<FileDetail> newFileDetails = [];
      for (var i = 0; i < newFilePaths.length; i += concurrencyLimit) {
        final sublist = (i + concurrencyLimit > newFilePaths.length)
            ? newFilePaths.sublist(i)
            : newFilePaths.sublist(i, i + concurrencyLimit);
        await Future.wait(
          sublist.map((path) async {
            try {
              final file = File(path);
              final size = await file.length();
              final lastModified = await file.lastModified();
              newFileDetails.add(
                FileDetail(file: file, size: size, lastModified: lastModified),
              );
            } catch (e) {
              debugPrint("Error reading file details for $path: $e");
            }
          }),
        );
      }

      if (newFileDetails.isEmpty) return existingFileCount;

      _files.addAll(newFileDetails);
      _sortFiles();
      if (_mergeSameName) {
        _precalculateMergedNumbering();
      }

      // 立即通知UI，让文件列表先显示出来
      notifyListeners();

      final exifFutures = newFileDetails.map(
        (detail) => loadExifData(detail.file, notify: false),
      );
      Future.wait(exifFutures).then((_) => notifyListeners());

      return existingFileCount;
    } catch (e) {
      debugPrint('Error selecting files: $e');
    }
    return 0;
  }

  // 将整数转换为罗马数字
  static String _convertIntToRoman(int number) {
    if (number <= 0) return '';

    final List<Map<String, dynamic>> romanNumerals = [
      {'value': 1000, 'symbol': 'M'},
      {'value': 900, 'symbol': 'CM'},
      {'value': 500, 'symbol': 'D'},
      {'value': 400, 'symbol': 'CD'},
      {'value': 100, 'symbol': 'C'},
      {'value': 90, 'symbol': 'XC'},
      {'value': 50, 'symbol': 'L'},
      {'value': 40, 'symbol': 'XL'},
      {'value': 10, 'symbol': 'X'},
      {'value': 9, 'symbol': 'IX'},
      {'value': 5, 'symbol': 'V'},
      {'value': 4, 'symbol': 'IV'},
      {'value': 1, 'symbol': 'I'},
    ];

    StringBuffer result = StringBuffer();
    for (var numeral in romanNumerals) {
      while (number >= numeral['value']) {
        result.write(numeral['symbol']);
        number -= numeral['value'] as int;
      }
    }

    return result.toString();
  }

  // 将整数转换为字母
  static String _convertIntToLetter(int number) {
    if (number <= 0) return '';

    StringBuffer result = StringBuffer();
    while (number > 0) {
      number--; // 调整为0-based
      result.write(String.fromCharCode('a'.codeUnitAt(0) + (number % 26)));
      number ~/= 26;
    }

    return result.toString().split('').reversed.join('');
  }

  // 选择文件夹的方法
  Future<int> selectFolder() async {
    try {
      final String? folderPath = await FileSelectorService.selectDirectory();
      if (folderPath == null) return 0;

      final List<String> filePaths =
          await FileSelectorService.getFilesInDirectory(folderPath);

      final existingFileCount = filePaths
          .where((path) => _isFileAlreadyAdded(path))
          .length;
      final newFilePaths = filePaths
          .where((path) => !_isFileAlreadyAdded(path))
          .toList();

      if (newFilePaths.isEmpty) return existingFileCount;

      const concurrencyLimit = 20; // 限制并发数量
      final List<FileDetail> newFileDetails = [];
      for (var i = 0; i < newFilePaths.length; i += concurrencyLimit) {
        final sublist = (i + concurrencyLimit > newFilePaths.length)
            ? newFilePaths.sublist(i)
            : newFilePaths.sublist(i, i + concurrencyLimit);
        await Future.wait(
          sublist.map((path) async {
            try {
              final file = File(path);
              final size = await file.length();
              final lastModified = await file.lastModified();
              newFileDetails.add(
                FileDetail(file: file, size: size, lastModified: lastModified),
              );
            } catch (e) {
              debugPrint("Error reading file details for $path: $e");
            }
          }),
        );
      }

      if (newFileDetails.isEmpty) return existingFileCount;

      _files.addAll(newFileDetails);
      _sortFiles();
      if (_mergeSameName) {
        _precalculateMergedNumbering();
      }

      // 立即通知UI，让文件列表先显示出来
      notifyListeners();

      final exifFutures = newFileDetails.map(
        (detail) => loadExifData(detail.file, notify: false),
      );
      Future.wait(exifFutures).then((_) => notifyListeners());

      return existingFileCount;
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    }
    return 0;
  }

  // 清除选择的方法
  void clearSelection() {
    _files.clear();
    _exifCache.clear(); // 清除文件时也要清除EXIF缓存
    _lastRenameLog.clear();
    _lastFailedFiles.clear();
    _mergedNumberingCache.clear();
    notifyListeners();
  }

  // 移除单个文件的方法
  void removeFile(int index) {
    if (index >= 0 && index < _files.length) {
      final removedFile = _files.removeAt(index);
      _exifCache.remove(removedFile.file.path); // 移除文件时也要移除EXIF缓存
      if (_mergeSameName) {
        _precalculateMergedNumbering();
      }
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> executeRename() async {
    _lastRenameLog.clear();
    _lastFailedFiles.clear();
    // 准备要传递给Isolate的参数
    final params = {
      'files': _files.map((f) => f.toJson()).toList(),
      'activeTabIndex': _activeTabIndex,
      'replaceRules': _replaceRules.map((r) => r.toJson()).toList(),
      'appendPrefix': _appendPrefix,
      'appendSuffix': _appendSuffix,
      'appendAfterFilename': _appendAfterFilename,
      'numberingPrefix': _numberingPrefix,
      'numberingSuffix': _numberingSuffix,
      'startNumber': _startNumber,
      'numberingType': _numberingType,
      'fixedDigits': _fixedDigits,
      'keepOriginalName': _keepOriginalName,
      'mergeSameName': _mergeSameName,
      'exifTemplate': _exifTemplate,
      'exifCache': _exifCache,
      'mergedNumberingCache': _mergedNumberingCache,
    };
    // 使用 compute 函数可以简化 Isolate 的调用
    final result = await compute(_renameWorker, params);
    _lastRenameLog = (result['renameLog'] as List)
        .map((e) => Map<String, String>.from(e))
        .toList();
    _lastFailedFiles = (result['failedFiles'] as List)
        .map((e) => Map<String, String>.from(e))
        .toList();

    notifyListeners();
    return result;
  }

  Future<void> undoRename() async {
    if (_lastRenameLog.isEmpty) return;

    for (final log in _lastRenameLog.reversed) {
      final oldPath = log['oldPath'];
      final newPath = log['newPath'];
      if (oldPath != null && newPath != null) {
        try {
          await File(newPath).rename(oldPath);
        } catch (e) {
          debugPrint('Failed to undo rename for $newPath: $e');
        }
      }
    }
    _lastRenameLog.clear();
    notifyListeners();
  }

  // 排序文件的方法
  void sortFiles(SortCriterion criterion) {
    _sortCriterion = criterion;
    _sortFiles();
    if (_mergeSameName) {
      _precalculateMergedNumbering();
    }
    notifyListeners();
  }

  // 内部排序实现
  void _sortFiles() {
    switch (_sortCriterion) {
      case SortCriterion.nameAsc:
        _files.sort((a, b) => a.file.path.compareTo(b.file.path));
        break;
      case SortCriterion.nameDesc:
        _files.sort((a, b) => b.file.path.compareTo(a.file.path));
        break;
      case SortCriterion.dateAsc:
        _files.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case SortCriterion.dateDesc:
        _files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
    }
  }
}
