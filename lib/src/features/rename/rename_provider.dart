import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import '../exif_reader/exif_service.dart';
import '../../shared/services/file_selector_service.dart';
import 'replace_rule.dart';

// Isolate的入口函数必须是顶层函数或静态方法
Future<Map<String, int>> _renameWorker(Map<String, dynamic> params) async {
  // 解包参数
  final filesData = params['files'] as List<Map<String, dynamic>>;
  final files = filesData.map((data) => FileDetail.fromJson(data)).toList();
  final activeTabIndex = params['activeTabIndex'] as int;
  final replaceRules = (params['replaceRules'] as List<Map<String, dynamic>>)
      .map((r) => ReplaceRule.fromJson(r))
      .toList();
  final appendPrefix = params['appendPrefix'] as String;
  final appendSuffix = params['appendSuffix'] as String;
  final appendAfterFilename = params['appendAfterFilename'] as bool;
  final numberingPrefix = params['numberingPrefix'] as String;
  final numberingSuffix = params['numberingSuffix'] as String;
  final startNumber = params['startNumber'] as int;
  final numberingType = params['numberingType'] as NumberingType;
  final fixedDigits = params['fixedDigits'] as int;
  final keepOriginalName = params['keepOriginalName'] as bool;
  final mergeSameName = params['mergeSameName'] as bool;
  final exifTemplate = params['exifTemplate'] as String;
  final exifCache = params['exifCache'] as Map<String, Map<String, dynamic>>;

  int successCount = 0;
  int failedCount = 0;

  final provider = RenameProvider._internal();
  provider._files.addAll(files);
  provider._activeTabIndex = activeTabIndex;
  provider._replaceRules.clear();
  provider._replaceRules.addAll(replaceRules);
  provider._appendPrefix = appendPrefix;
  provider._appendSuffix = appendSuffix;
  provider._appendAfterFilename = appendAfterFilename;
  provider._numberingPrefix = numberingPrefix;
  provider._numberingSuffix = numberingSuffix;
  provider._startNumber = startNumber;
  provider._numberingType = numberingType;
  provider._fixedDigits = fixedDigits;
  provider._keepOriginalName = keepOriginalName;
  provider._mergeSameName = mergeSameName;
  provider._exifTemplate = exifTemplate;
  provider._exifCache.addAll(exifCache);

  for (int i = 0; i < files.length; i++) {
    final fileDetail = files[i];
    final oldPath = fileDetail.file.path;
    try {
      final newName = provider.previewRename(fileDetail, i);
      final newPath =
          '${fileDetail.file.parent.path}${Platform.pathSeparator}$newName';

      if (oldPath != newPath) {
        await fileDetail.file.rename(newPath);
      }
      successCount++;
    } catch (e) {
      debugPrint('Failed to rename ${fileDetail.file.path}: $e');
      failedCount++;
    }
  }

  return {'success': successCount, 'failed': failedCount};
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
  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  void setActiveTabIndex(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  final List<FileDetail> _files = [];
  List<FileDetail> get files => _files;

  bool _mergeSameName = false;
  bool get mergeSameName => _mergeSameName;

  void setMergeSameName(bool value) {
    _mergeSameName = value;
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

  void setExifTemplate(String template) {
    _exifTemplate = template;
    notifyListeners();
  }

  Future<void> loadExifData(File file) async {
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
    notifyListeners();
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
    final file = fileDetail.file;
    String fileName = file.uri.pathSegments.last;

    switch (_activeTabIndex) {
      case 0: // 替换
        return _applyReplaceRule(fileName);
      case 1: // 追加
        return _applyAppendRule(fileName);
      case 2: // 自动序号
        return _applyAutoNumberingRule(fileName, index);
      case 3: // EXIF命名
        return _applyExifNamingRule(fileDetail, index);
      default:
        return fileName;
    }
  }

  // 格式化序号的辅助方法
  String _formatNumber(int number, NumberingType type, int digits) {
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
  String _applyReplaceRule(String fileName) {
    String result = fileName;
    for (var rule in _replaceRules) {
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
  String _applyAppendRule(String fileName) {
    if (_appendPrefix.isNotEmpty || _appendSuffix.isNotEmpty) {
      if (!_appendAfterFilename) {
        int lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex != -1) {
          String namePart = fileName.substring(0, lastDotIndex);
          String extensionPart = fileName.substring(lastDotIndex);
          return _appendPrefix + namePart + _appendSuffix + extensionPart;
        } else {
          return _appendPrefix + fileName + _appendSuffix;
        }
      } else {
        return _appendPrefix + fileName + _appendSuffix;
      }
    }
    return fileName;
  }

  // 应用自动序号规则
  String _applyAutoNumberingRule(String fileName, int index) {
    int currentNumber;
    if (_mergeSameName) {
      final uniqueBaseNames = _files
          .map((f) => _getBaseName(f.file.path))
          .toSet()
          .toList();
      uniqueBaseNames.sort();
      final currentBaseName = _getBaseName(files[index].file.path);
      final groupIndex = uniqueBaseNames.indexOf(currentBaseName);
      currentNumber = _startNumber + groupIndex;
    } else {
      currentNumber = _startNumber + index;
    }

    String formattedNumber = _formatNumber(
      currentNumber,
      _numberingType,
      _fixedDigits,
    );

    if (_keepOriginalName) {
      int lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        String namePart = fileName.substring(0, lastDotIndex);
        String extensionPart = fileName.substring(lastDotIndex);
        return '$_numberingPrefix$namePart$formattedNumber$_numberingSuffix$extensionPart';
      } else {
        return '$_numberingPrefix$fileName$formattedNumber$_numberingSuffix';
      }
    } else {
      int lastDotIndex = fileName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        String extensionPart = fileName.substring(lastDotIndex);
        return '$_numberingPrefix$formattedNumber$_numberingSuffix$extensionPart';
      } else {
        return '$_numberingPrefix$formattedNumber$_numberingSuffix';
      }
    }
  }

  // 应用EXIF命名规则
  String _applyExifNamingRule(FileDetail fileDetail, int index) {
    if (_exifTemplate.isEmpty) {
      return fileDetail.file.uri.pathSegments.last;
    }

    final exifData = _exifCache[fileDetail.file.path] ?? {};
    String newName = _exifTemplate;

    final RegExp placeholderRegex = RegExp(r'\[(.*?)\]');
    newName = newName
        .replaceAllMapped(placeholderRegex, (match) {
          final placeholder = match.group(1);

          if (placeholder == '序号') {
            int currentNumber;
            if (_mergeSameName) {
              final uniqueBaseNames = _files
                  .map((f) => _getBaseName(f.file.path))
                  .toSet()
                  .toList();
              uniqueBaseNames.sort();
              final currentBaseName = _getBaseName(fileDetail.file.path);
              final groupIndex = uniqueBaseNames.indexOf(currentBaseName);
              currentNumber = _startNumber + groupIndex;
            } else {
              currentNumber = _startNumber + index;
            }
            return '$_numberingPrefix${_formatNumber(currentNumber, _numberingType, _fixedDigits)}$_numberingSuffix';
          }

          final shotTime = exifData['拍摄时间'] as String?;
          DateTime? parsedDate;
          if (shotTime != null) {
            try {
              parsedDate = DateTime.parse(shotTime);
            } catch (e) {
              // Ignore parsing errors
            }
          }

          switch (placeholder) {
            case '快门速度':
              return (exifData['快门速度'] as String?) ??
                  (exifData['曝光时间'] as String?) ??
                  'N/A';
            case '年':
              return parsedDate?.year.toString() ?? 'N/A';
            case '月':
              return parsedDate?.month.toString().padLeft(2, '0') ?? 'N/A';
            case '日':
              return parsedDate?.day.toString().padLeft(2, '0') ?? 'N/A';
            case '时':
              return parsedDate?.hour.toString().padLeft(2, '0') ?? 'N/A';
            case '分':
              return parsedDate?.minute.toString().padLeft(2, '0') ?? 'N/A';
            case '秒':
              return parsedDate?.second.toString().padLeft(2, '0') ?? 'N/A';
            case '年月日':
              if (parsedDate == null) return 'N/A';
              return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
            case '时分秒':
              if (parsedDate == null) return 'N/A';
              return '${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}:${parsedDate.second.toString().padLeft(2, '0')}';
            default:
              return exifData[placeholder] as String? ?? 'N/A';
          }
        })
        .replaceAll('N/A', '');

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

  String _getBaseName(String path) {
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    final fileName = path.substring(lastSeparator + 1);
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
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

    final newFiles = allFilePaths
        .where((file) => !_isFileAlreadyAdded(file.path))
        .toList();

    if (newFiles.isNotEmpty) {
      final List<FileDetail> newFileDetails = [];
      for (final file in newFiles) {
        try {
          final size = await file.length();
          final lastModified = await file.lastModified();
          newFileDetails.add(
            FileDetail(file: file, size: size, lastModified: lastModified),
          );
        } catch (e) {
          debugPrint("Error reading file details for ${file.path}: $e");
        }
      }
      _files.addAll(newFileDetails);
      _sortFiles();
      notifyListeners();

      // 异步加载新文件的EXIF数据
      for (final detail in newFileDetails) {
        loadExifData(detail.file);
      }
    }
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
      if (filePaths != null) {
        final existingFileCount = filePaths
            .where((path) => _isFileAlreadyAdded(path))
            .length;
        final newFilePaths = filePaths
            .where((path) => !_isFileAlreadyAdded(path))
            .toList();

        if (newFilePaths.isNotEmpty) {
          final List<FileDetail> newFileDetails = [];
          for (final path in newFilePaths) {
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
          }
          _files.addAll(newFileDetails);
          _sortFiles();
          notifyListeners();

          // 异步加载新文件的EXIF数据
          for (final detail in newFileDetails) {
            loadExifData(detail.file);
          }
        }
        return existingFileCount;
      }
    } catch (e) {
      debugPrint('Error selecting files: $e');
    }
    return 0;
  }

  // 将整数转换为罗马数字
  String _convertIntToRoman(int number) {
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
  String _convertIntToLetter(int number) {
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
      if (folderPath != null) {
        final List<String> filePaths =
            await FileSelectorService.getFilesInDirectory(folderPath);

        final existingFileCount = filePaths
            .where((path) => _isFileAlreadyAdded(path))
            .length;
        final newFilePaths = filePaths
            .where((path) => !_isFileAlreadyAdded(path))
            .toList();

        if (newFilePaths.isNotEmpty) {
          final List<FileDetail> newFileDetails = [];
          for (final path in newFilePaths) {
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
          }
          _files.addAll(newFileDetails);
          _sortFiles();
          notifyListeners();

          // 异步加载新文件的EXIF数据
          for (final detail in newFileDetails) {
            loadExifData(detail.file);
          }
        }
        return existingFileCount;
      }
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    }
    return 0;
  }

  // 清除选择的方法
  void clearSelection() {
    _files.clear();
    _exifCache.clear(); // 清除文件时也要清除EXIF缓存
    notifyListeners();
  }

  // 移除单个文件的方法
  void removeFile(int index) {
    if (index >= 0 && index < _files.length) {
      final removedFile = _files.removeAt(index);
      _exifCache.remove(removedFile.file.path); // 移除文件时也要移除EXIF缓存
      notifyListeners();
    }
  }

  Future<Map<String, int>> executeRename() async {
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
    };
    // 使用 compute 函数可以简化 Isolate 的调用
    return await compute(_renameWorker, params);
  }

  // 排序文件的方法
  void sortFiles(SortCriterion criterion) {
    _sortCriterion = criterion;
    _sortFiles();
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
