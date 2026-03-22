export 'rename_models.dart';

import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

import '../exif_reader/exif_service.dart';
import '../../shared/services/file_selector_service.dart';
import 'rename_engine.dart';
import 'rename_models.dart';
import 'replace_rule.dart';

class RenameProvider with ChangeNotifier {
  RenameProvider._internal();

  factory RenameProvider() {
    return RenameProvider._internal().._init();
  }

  void _init() {
    _refreshPreviewPlan(notify: false);
  }

  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;
  RenameMode get activeMode => RenameMode.values[_activeTabIndex];

  final List<FileDetail> _files = [];
  List<FileDetail> get files => _files;

  final Set<String> _addedFilePaths = {};

  RenamePlan _previewPlan = const RenamePlan.empty();
  RenamePlan get previewPlan => _previewPlan;

  final List<RenameIssue> _issues = [];
  List<RenameIssue> get issues => _issues;

  List<RenameActionLog> _lastRenameLog = [];
  List<RenameActionLog> get lastRenameLog => _lastRenameLog;

  RenameExecutionResult? _lastExecutionResult;
  RenameExecutionResult? get lastExecutionResult => _lastExecutionResult;

  UndoResult? _lastUndoResult;
  UndoResult? get lastUndoResult => _lastUndoResult;

  bool _mergeSameName = false;
  bool get mergeSameName => _mergeSameName;

  SortCriterion _sortCriterion = SortCriterion.nameAsc;
  SortCriterion get sortCriterion => _sortCriterion;

  final List<ReplaceRule> _replaceRules = [ReplaceRule()];
  List<ReplaceRule> get replaceRules => _replaceRules;

  String _appendPrefix = '';
  String get appendPrefix => _appendPrefix;

  String _appendSuffix = '';
  String get appendSuffix => _appendSuffix;

  AppendMode _appendMode = AppendMode.aroundBaseName;
  AppendMode get appendMode => _appendMode;

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

  String _exifTemplate = '';
  String get exifTemplate => _exifTemplate;

  RenameConflictPolicy _conflictPolicy = RenameConflictPolicy.strict;
  RenameConflictPolicy get conflictPolicy => _conflictPolicy;

  ExifMissingPolicy _exifMissingPolicy =
      ExifMissingPolicy.keepOriginalNameWarning;
  ExifMissingPolicy get exifMissingPolicy => _exifMissingPolicy;

  final Map<String, Map<String, String>> _exifData = {};
  final Map<String, Future<void>> _pendingExifLoads = {};
  bool get hasPendingExifLoads => _pendingExifLoads.isNotEmpty;

  RenamePlanItem? previewItemAt(int index) {
    if (index < 0 || index >= _previewPlan.items.length) {
      return null;
    }
    return _previewPlan.items[index];
  }

  String previewRename(FileDetail fileDetail, int index) {
    return previewItemAt(index)?.targetName ?? fileDetail.fileName;
  }

  bool _isFileAlreadyAdded(String filePath) =>
      _addedFilePaths.contains(filePath);

  bool isFileAlreadyAdded(String filePath) => _isFileAlreadyAdded(filePath);

  void setActiveTabIndex(int index) {
    if (_activeTabIndex == index) {
      return;
    }
    _activeTabIndex = index;
    _refreshPreviewPlan();
  }

  void setMergeSameName(bool value) {
    if (_mergeSameName == value) {
      return;
    }
    _mergeSameName = value;
    _refreshPreviewPlan();
  }

  void setExifTemplate(String template) {
    _exifTemplate = template;
    _refreshPreviewPlan();
  }

  void setConflictPolicy(RenameConflictPolicy policy) {
    if (_conflictPolicy == policy) {
      return;
    }
    _conflictPolicy = policy;
    _refreshPreviewPlan();
  }

  void setExifMissingPolicy(ExifMissingPolicy policy) {
    if (_exifMissingPolicy == policy) {
      return;
    }
    _exifMissingPolicy = policy;
    _refreshPreviewPlan();
  }

  Future<void> loadExifData(File file, {bool notify = true}) async {
    if (_exifData.containsKey(file.path)) {
      return;
    }
    final pending = _pendingExifLoads[file.path];
    if (pending != null) {
      await pending;
      return;
    }

    if (!ExifService.isSupportedImage(file.path)) {
      _exifData[file.path] = const {};
      if (notify) {
        _refreshPreviewPlan();
      }
      return;
    }

    final future = _loadExifDataInternal(file.path, notify: notify);
    _pendingExifLoads[file.path] = future;
    await future;
  }

  Future<void> _loadExifDataInternal(
    String filePath, {
    required bool notify,
  }) async {
    try {
      final exif = await ExifService.readExifFromFile(filePath);
      if (_addedFilePaths.contains(filePath)) {
        _exifData[filePath] = Map<String, String>.from(exif.translatedData);
      }
      if (!exif.hasExif &&
          exif.errorMessage != null &&
          _addedFilePaths.contains(filePath) &&
          exif.errorMessage != '未找到EXIF信息') {
        _issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.warning,
            code: 'exif_read_failed',
            message: exif.errorMessage!,
            sourcePath: filePath,
          ),
        );
      }
    } catch (error) {
      if (_addedFilePaths.contains(filePath)) {
        _exifData[filePath] = const {};
        _issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.warning,
            code: 'exif_read_failed',
            message: '读取 EXIF 失败: $error',
            sourcePath: filePath,
          ),
        );
      }
    } finally {
      _pendingExifLoads.remove(filePath);
      if (notify && _addedFilePaths.contains(filePath)) {
        _refreshPreviewPlan();
      }
    }
  }

  void addReplaceRule() {
    _replaceRules.add(ReplaceRule());
    _refreshPreviewPlan();
  }

  void removeReplaceRule(int index) {
    if (_replaceRules.length <= 1) {
      return;
    }
    if (index < 0 || index >= _replaceRules.length) {
      return;
    }
    _replaceRules.removeAt(index);
    _refreshPreviewPlan();
  }

  void updateFindText(int index, String text) {
    if (index < 0 || index >= _replaceRules.length) {
      return;
    }
    _replaceRules[index] = _replaceRules[index].copyWith(findText: text);
    _refreshPreviewPlan();
  }

  void updateReplaceText(int index, String text) {
    if (index < 0 || index >= _replaceRules.length) {
      return;
    }
    _replaceRules[index] = _replaceRules[index].copyWith(replaceText: text);
    _refreshPreviewPlan();
  }

  void updateAllowReplaceExtension(int index, bool value) {
    if (index < 0 || index >= _replaceRules.length) {
      return;
    }
    _replaceRules[index] = _replaceRules[index].copyWith(
      allowReplaceExtension: value,
    );
    _refreshPreviewPlan();
  }

  void setAppendPrefix(String text) {
    _appendPrefix = text;
    _refreshPreviewPlan();
  }

  void setAppendSuffix(String text) {
    _appendSuffix = text;
    _refreshPreviewPlan();
  }

  void setAppendMode(AppendMode mode) {
    if (_appendMode == mode) {
      return;
    }
    _appendMode = mode;
    _refreshPreviewPlan();
  }

  void setNumberingPrefix(String text) {
    _numberingPrefix = text;
    _refreshPreviewPlan();
  }

  void setNumberingSuffix(String text) {
    _numberingSuffix = text;
    _refreshPreviewPlan();
  }

  void setStartNumber(int number) {
    _startNumber = number <= 0 ? 1 : number;
    _refreshPreviewPlan();
  }

  void setNumberingType(NumberingType type) {
    if (_numberingType == type) {
      return;
    }
    _numberingType = type;
    _refreshPreviewPlan();
  }

  void setFixedDigits(int digits) {
    _fixedDigits = digits < 0 ? 0 : digits;
    _refreshPreviewPlan();
  }

  void setKeepOriginalName(bool value) {
    if (_keepOriginalName == value) {
      return;
    }
    _keepOriginalName = value;
    _refreshPreviewPlan();
  }

  Future<void> addFiles(List<XFile> xFiles) async {
    final allFilePaths = <String>[];
    for (final xFile in xFiles) {
      final type = FileSystemEntity.typeSync(xFile.path);
      if (type == FileSystemEntityType.directory) {
        final children = await FileSelectorService.getFilesInDirectory(
          xFile.path,
        );
        allFilePaths.addAll(children);
      } else if (type == FileSystemEntityType.file) {
        allFilePaths.add(xFile.path);
      }
    }
    await _ingestFilePaths(allFilePaths);
  }

  Future<int> selectFiles() async {
    try {
      final filePaths = await FileSelectorService.selectMultipleFiles(
        allowedExtensions: null,
      );
      if (filePaths == null) {
        return 0;
      }
      return _ingestFilePaths(filePaths);
    } catch (error) {
      _issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'select_files_failed',
          message: '选择文件失败: $error',
        ),
      );
      notifyListeners();
      return 0;
    }
  }

  Future<int> selectFolder() async {
    try {
      final isGranted = await _requestStoragePermission();
      if (!isGranted) {
        return -1;
      }

      final folderPath = await FileSelectorService.selectDirectory();
      if (folderPath == null) {
        return 0;
      }
      final filePaths = await FileSelectorService.getFilesInDirectory(
        folderPath,
      );
      return _ingestFilePaths(filePaths);
    } catch (error) {
      _issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'select_folder_failed',
          message: '选择文件夹失败: $error',
        ),
      );
      notifyListeners();
      return 0;
    }
  }

  Future<int> _ingestFilePaths(List<String> allFilePaths) async {
    final existingFileCount = allFilePaths.where(_isFileAlreadyAdded).length;
    final newFilePaths = allFilePaths
        .where((path) => !_isFileAlreadyAdded(path))
        .toList();
    if (newFilePaths.isEmpty) {
      return existingFileCount;
    }

    final newFileDetails = await _loadFileDetails(newFilePaths);
    if (newFileDetails.isEmpty) {
      return existingFileCount;
    }

    _files.addAll(newFileDetails);
    for (final detail in newFileDetails) {
      _addedFilePaths.add(detail.file.path);
    }
    _sortFiles();
    _refreshPreviewPlan();

    for (final detail in newFileDetails) {
      unawaited(loadExifData(detail.file, notify: true));
    }
    return existingFileCount;
  }

  Future<List<FileDetail>> _loadFileDetails(List<String> filePaths) async {
    const concurrencyLimit = 20;
    final newFileDetails = <FileDetail>[];
    for (var i = 0; i < filePaths.length; i += concurrencyLimit) {
      final sublist = filePaths.sublist(
        i,
        i + concurrencyLimit > filePaths.length
            ? filePaths.length
            : i + concurrencyLimit,
      );
      await Future.wait(
        sublist.map((filePath) async {
          try {
            final file = File(filePath);
            final size = await file.length();
            final lastModified = await file.lastModified();
            newFileDetails.add(
              FileDetail(file: file, size: size, lastModified: lastModified),
            );
          } catch (error) {
            _issues.add(
              RenameIssue(
                severity: RenameIssueSeverity.error,
                code: 'file_read_failed',
                message: '读取文件信息失败: $error',
                sourcePath: filePath,
              ),
            );
          }
        }),
      );
    }
    return newFileDetails;
  }

  void clearSelection() {
    _files.clear();
    _addedFilePaths.clear();
    _exifData.clear();
    _pendingExifLoads.clear();
    _lastRenameLog = [];
    _lastExecutionResult = null;
    _lastUndoResult = null;
    _issues.clear();
    _refreshPreviewPlan();
  }

  void removeFile(int index) {
    if (index < 0 || index >= _files.length) {
      return;
    }
    final removed = _files.removeAt(index);
    _addedFilePaths.remove(removed.file.path);
    _exifData.remove(removed.file.path);
    _pendingExifLoads.remove(removed.file.path);
    _refreshPreviewPlan();
  }

  void reorderFiles(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _files.length ||
        newIndex < 0 ||
        newIndex >= _files.length) {
      return;
    }
    final item = _files.removeAt(oldIndex);
    _files.insert(newIndex, item);
    _refreshPreviewPlan();
  }

  Future<RenameExecutionResult> executeRename() async {
    if (activeMode == RenameMode.exif) {
      await _ensureExifReadyForCurrentFiles();
    }

    _refreshPreviewPlan(notify: false);
    final result = await RenameEngine.executePlan(_previewPlan);
    _lastExecutionResult = result;
    _lastUndoResult = null;
    _lastRenameLog = result.renameLog;
    _issues.addAll(result.issues);

    if (result.failedCount == 0 && result.renameLog.isNotEmpty) {
      _applyPathChanges(result.renameLog);
    }

    _refreshPreviewPlan();
    return result;
  }

  Future<UndoResult> undoRename() async {
    if (_lastRenameLog.isEmpty) {
      return const UndoResult(
        successCount: 0,
        failedCount: 0,
        revertedLog: [],
        issues: [],
      );
    }

    final result = await RenameEngine.undo(_lastRenameLog);
    _lastUndoResult = result;
    _issues.addAll(result.issues);

    if (result.failedCount == 0 && result.revertedLog.isNotEmpty) {
      _applyPathChanges(result.revertedLog);
      _lastRenameLog = [];
      _lastExecutionResult = null;
    }

    _refreshPreviewPlan();
    return result;
  }

  void sortFiles(SortCriterion criterion) {
    _sortCriterion = criterion;
    _sortFiles();
    _refreshPreviewPlan();
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  void _sortFiles() {
    switch (_sortCriterion) {
      case SortCriterion.nameAsc:
        _files.sort(
          (a, b) =>
              path.basename(a.file.path).compareTo(path.basename(b.file.path)),
        );
        break;
      case SortCriterion.nameDesc:
        _files.sort(
          (a, b) =>
              path.basename(b.file.path).compareTo(path.basename(a.file.path)),
        );
        break;
      case SortCriterion.dateAsc:
        _files.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case SortCriterion.dateDesc:
        _files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
    }
  }

  Future<void> _ensureExifReadyForCurrentFiles() async {
    final futures = <Future<void>>[];
    for (final file in _files) {
      futures.add(loadExifData(file.file, notify: false));
    }
    if (futures.isEmpty) {
      return;
    }
    await Future.wait(futures);
  }

  void _applyPathChanges(List<RenameActionLog> logs) {
    final pathMap = <String, String>{
      for (final log in logs) log.oldPath: log.newPath,
    };

    for (var index = 0; index < _files.length; index++) {
      final oldPath = _files[index].file.path;
      final newPath = pathMap[oldPath];
      if (newPath == null) {
        continue;
      }
      _files[index] = _files[index].copyWithPath(newPath);
      _addedFilePaths.remove(oldPath);
      _addedFilePaths.add(newPath);

      final exif = _exifData.remove(oldPath);
      if (exif != null) {
        _exifData[newPath] = exif;
      }
      _pendingExifLoads.remove(oldPath);
    }
  }

  void _refreshPreviewPlan({bool notify = true}) {
    _previewPlan = RenameEngine.buildPlan(
      RenamePlanRequest(
        files: List.unmodifiable(_files),
        mode: activeMode,
        replaceRules: List.unmodifiable(_replaceRules),
        appendPrefix: _appendPrefix,
        appendSuffix: _appendSuffix,
        appendMode: _appendMode,
        numberingPrefix: _numberingPrefix,
        numberingSuffix: _numberingSuffix,
        startNumber: _startNumber,
        numberingType: _numberingType,
        fixedDigits: _fixedDigits,
        keepOriginalName: _keepOriginalName,
        mergeSameName: _mergeSameName,
        exifTemplate: _exifTemplate,
        exifData: Map.unmodifiable(_exifData),
        pendingExifPaths: Set.unmodifiable(_pendingExifLoads.keys.toSet()),
        conflictPolicy: _conflictPolicy,
        exifMissingPolicy: _exifMissingPolicy,
        isWindowsLike: Platform.isWindows,
      ),
    );
    if (notify) {
      notifyListeners();
    }
  }
}
