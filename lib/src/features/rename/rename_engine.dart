import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import 'rename_models.dart';
import 'replace_rule.dart';

class RenamePlanRequest {
  final List<FileDetail> files;
  final RenameMode mode;
  final List<ReplaceRule> replaceRules;
  final String appendPrefix;
  final String appendSuffix;
  final AppendMode appendMode;
  final String numberingPrefix;
  final String numberingSuffix;
  final int startNumber;
  final NumberingType numberingType;
  final int fixedDigits;
  final bool keepOriginalName;
  final bool mergeSameName;
  final String exifTemplate;
  final Map<String, Map<String, String>> exifData;
  final Set<String> pendingExifPaths;
  final RenameConflictPolicy conflictPolicy;
  final ExifMissingPolicy exifMissingPolicy;
  final bool isWindowsLike;

  const RenamePlanRequest({
    required this.files,
    required this.mode,
    required this.replaceRules,
    required this.appendPrefix,
    required this.appendSuffix,
    required this.appendMode,
    required this.numberingPrefix,
    required this.numberingSuffix,
    required this.startNumber,
    required this.numberingType,
    required this.fixedDigits,
    required this.keepOriginalName,
    required this.mergeSameName,
    required this.exifTemplate,
    required this.exifData,
    required this.pendingExifPaths,
    required this.conflictPolicy,
    required this.exifMissingPolicy,
    required this.isWindowsLike,
  });
}

class RenameEngine {
  static const _notFoundPlaceholder = 'NaN';
  static final RegExp _placeholderRegex = RegExp(r'\[(.*?)\]');
  static final RegExp _invalidWindowsChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static const Set<String> _reservedWindowsNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  static RenamePlan buildPlan(RenamePlanRequest request) {
    if (request.files.isEmpty) {
      return const RenamePlan.empty();
    }

    final numberingOffsets = _buildNumberingOffsets(
      request.files,
      mergeSameName: request.mergeSameName,
      isWindowsLike: request.isWindowsLike,
    );
    final drafts = <_PlanDraft>[];

    for (int index = 0; index < request.files.length; index++) {
      final fileDetail = request.files[index];
      final derived = _deriveTargetName(
        request: request,
        fileDetail: fileDetail,
        index: index,
        numberingOffset: numberingOffsets[fileDetail.file.path] ?? index,
      );
      final draft = _PlanDraft.fromDerived(
        index: index,
        fileDetail: fileDetail,
        targetName: derived.targetName,
        action: derived.action,
        issues: derived.issues,
        isWindowsLike: request.isWindowsLike,
      );
      _validateDraftName(draft, isWindowsLike: request.isWindowsLike);
      drafts.add(draft);
    }

    _resolveConflicts(drafts, request);

    final items = drafts
        .map((draft) => draft.toPlanItem())
        .toList(growable: false);
    final summary = RenamePlanSummary(
      renameCount: items
          .where((item) => item.action == RenamePlanAction.rename)
          .length,
      unchangedCount: items
          .where((item) => item.action == RenamePlanAction.unchanged)
          .length,
      skippedCount: items
          .where((item) => item.action == RenamePlanAction.skip)
          .length,
      conflictCount: items
          .where((item) => item.status == RenamePreviewStatus.conflict)
          .length,
      blockedCount: items
          .where((item) => item.action == RenamePlanAction.blocked)
          .length,
      warningCount: items.where((item) => item.hasWarnings).length,
    );
    return RenamePlan(items: items, summary: summary);
  }

  static _DerivedTargetName _deriveTargetName({
    required RenamePlanRequest request,
    required FileDetail fileDetail,
    required int index,
    required int numberingOffset,
  }) {
    final originalName = path.basename(fileDetail.file.path);
    switch (request.mode) {
      case RenameMode.replace:
        return _applyReplaceRulesWithValidation(
          originalName,
          request.replaceRules,
          fileDetail.file.path,
        );
      case RenameMode.append:
        return _DerivedTargetName(
          targetName: _applyAppendRule(
            originalName,
            request.appendPrefix,
            request.appendSuffix,
            request.appendMode,
          ),
        );
      case RenameMode.autoNumbering:
        return _DerivedTargetName(
          targetName: _applyAutoNumberingRule(
            originalName,
            startNumber: request.startNumber,
            numberingOffset: numberingOffset,
            numberingType: request.numberingType,
            fixedDigits: request.fixedDigits,
            keepOriginalName: request.keepOriginalName,
            numberingPrefix: request.numberingPrefix,
            numberingSuffix: request.numberingSuffix,
          ),
        );
      case RenameMode.exif:
        return _applyExifRule(
          fileDetail: fileDetail,
          originalName: originalName,
          exifTemplate: request.exifTemplate,
          exifData: request.exifData[fileDetail.file.path],
          isPending: request.pendingExifPaths.contains(fileDetail.file.path),
          numberingValue: request.startNumber + numberingOffset,
          numberingPrefix: request.numberingPrefix,
          numberingSuffix: request.numberingSuffix,
          numberingType: request.numberingType,
          fixedDigits: request.fixedDigits,
          missingPolicy: request.exifMissingPolicy,
        );
    }
  }

  static void _resolveConflicts(
    List<_PlanDraft> drafts,
    RenamePlanRequest request,
  ) {
    final renameDrafts = drafts
        .where((draft) => draft.action == RenamePlanAction.rename)
        .toList();
    if (renameDrafts.isEmpty) {
      _syncStatuses(drafts);
      return;
    }

    switch (request.conflictPolicy) {
      case RenameConflictPolicy.autoRename:
        _autoResolveConflicts(
          drafts: drafts,
          renameDrafts: renameDrafts,
          isWindowsLike: request.isWindowsLike,
        );
        break;
      case RenameConflictPolicy.strict:
        _markConflicts(
          drafts: drafts,
          renameDrafts: renameDrafts,
          isWindowsLike: request.isWindowsLike,
          convertToSkip: false,
        );
        break;
      case RenameConflictPolicy.skipConflicts:
        _markConflicts(
          drafts: drafts,
          renameDrafts: renameDrafts,
          isWindowsLike: request.isWindowsLike,
          convertToSkip: true,
        );
        break;
    }

    _syncStatuses(drafts);
  }

  static void _autoResolveConflicts({
    required List<_PlanDraft> drafts,
    required List<_PlanDraft> renameDrafts,
    required bool isWindowsLike,
  }) {
    final movingSources = renameDrafts
        .map(
          (draft) => _normalizePath(draft.fileDetail.file.path, isWindowsLike),
        )
        .toSet();
    final stationaryPaths = drafts
        .where((draft) => draft.action != RenamePlanAction.rename)
        .map(
          (draft) => _normalizePath(draft.fileDetail.file.path, isWindowsLike),
        )
        .toSet();
    final assignedTargets = <String>{};
    final existingCache = <String, bool>{};

    for (final draft in renameDrafts) {
      if (draft.action != RenamePlanAction.rename) {
        continue;
      }
      final originalTargetName = draft.targetName;
      final originalTargetPath = draft.targetPath;
      var candidateName = originalTargetName;
      var candidatePath = originalTargetPath;
      var candidateNorm = _normalizePath(candidatePath, isWindowsLike);
      var suffixCounter = 1;

      while (_hasOccupancyConflict(
        candidatePath: candidatePath,
        candidateNorm: candidateNorm,
        draft: draft,
        movingSources: movingSources,
        stationaryPaths: stationaryPaths,
        assignedTargets: assignedTargets,
        existingCache: existingCache,
        isWindowsLike: isWindowsLike,
      )) {
        candidateName = _appendConflictSuffix(
          originalTargetName,
          suffixCounter,
        );
        candidatePath = path.join(
          path.dirname(draft.fileDetail.file.path),
          candidateName,
        );
        candidateNorm = _normalizePath(candidatePath, isWindowsLike);
        suffixCounter++;
      }

      if (candidateName != originalTargetName) {
        draft.targetName = candidateName;
        draft.targetPath = candidatePath;
        draft.caseOnlyRename = _isCaseOnlyRename(
          draft.fileDetail.file.path,
          draft.targetPath,
          isWindowsLike,
        );
        draft.issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.warning,
            code: 'auto_resolved_conflict',
            message: '目标名称冲突，已自动调整为 $candidateName',
            sourcePath: draft.fileDetail.file.path,
            targetPath: candidatePath,
          ),
        );
      }

      assignedTargets.add(_normalizePath(draft.targetPath, isWindowsLike));
    }
  }

  static void _markConflicts({
    required List<_PlanDraft> drafts,
    required List<_PlanDraft> renameDrafts,
    required bool isWindowsLike,
    required bool convertToSkip,
  }) {
    final movingSources = renameDrafts
        .map(
          (draft) => _normalizePath(draft.fileDetail.file.path, isWindowsLike),
        )
        .toSet();
    final stationaryPaths = drafts
        .where((draft) => draft.action != RenamePlanAction.rename)
        .map(
          (draft) => _normalizePath(draft.fileDetail.file.path, isWindowsLike),
        )
        .toSet();
    final duplicateGroups = <String, List<_PlanDraft>>{};
    final existingCache = <String, bool>{};

    for (final draft in renameDrafts) {
      duplicateGroups
          .putIfAbsent(
            _normalizePath(draft.targetPath, isWindowsLike),
            () => [],
          )
          .add(draft);
    }

    for (final entry in duplicateGroups.entries) {
      if (entry.value.length <= 1) {
        continue;
      }
      for (final draft in entry.value) {
        _applyConflictOutcome(
          draft,
          convertToSkip: convertToSkip,
          issue: RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'duplicate_target',
            message: '批量预览中存在重复目标名称',
            sourcePath: draft.fileDetail.file.path,
            targetPath: draft.targetPath,
          ),
        );
      }
    }

    for (final draft in renameDrafts) {
      if (draft.action != RenamePlanAction.rename) {
        continue;
      }

      final sourceNorm = _normalizePath(
        draft.fileDetail.file.path,
        isWindowsLike,
      );
      final targetNorm = _normalizePath(draft.targetPath, isWindowsLike);
      if (sourceNorm != targetNorm && stationaryPaths.contains(targetNorm)) {
        _applyConflictOutcome(
          draft,
          convertToSkip: convertToSkip,
          issue: RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'selected_target_occupied',
            message: '目标名称已被当前列表中未移动的文件占用',
            sourcePath: draft.fileDetail.file.path,
            targetPath: draft.targetPath,
          ),
        );
        continue;
      }

      if (sourceNorm == targetNorm) {
        continue;
      }

      final exists = existingCache.putIfAbsent(targetNorm, () {
        if (movingSources.contains(targetNorm)) {
          return false;
        }
        return File(draft.targetPath).existsSync();
      });
      if (exists) {
        _applyConflictOutcome(
          draft,
          convertToSkip: convertToSkip,
          issue: RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'external_target_exists',
            message: '目标文件已存在',
            sourcePath: draft.fileDetail.file.path,
            targetPath: draft.targetPath,
          ),
        );
      }
    }
  }

  static void _applyConflictOutcome(
    _PlanDraft draft, {
    required bool convertToSkip,
    required RenameIssue issue,
  }) {
    final alreadyRecorded = draft.issues.any(
      (existing) =>
          existing.code == issue.code &&
          existing.targetPath == issue.targetPath,
    );
    if (!alreadyRecorded) {
      draft.issues.add(issue);
    }
    draft.action = convertToSkip
        ? RenamePlanAction.skip
        : RenamePlanAction.blocked;
  }

  static void _syncStatuses(List<_PlanDraft> drafts) {
    for (final draft in drafts) {
      if (draft.issues.any((issue) => issue.isError) ||
          draft.action == RenamePlanAction.blocked) {
        draft.status = RenamePreviewStatus.conflict;
      } else if (draft.issues.any((issue) => issue.isWarning)) {
        draft.status = RenamePreviewStatus.warning;
      } else if (draft.action == RenamePlanAction.unchanged) {
        draft.status = RenamePreviewStatus.unchanged;
      } else {
        draft.status = RenamePreviewStatus.normal;
      }
    }
  }

  static void _validateDraftName(
    _PlanDraft draft, {
    required bool isWindowsLike,
  }) {
    if (draft.action == RenamePlanAction.skip ||
        draft.action == RenamePlanAction.blocked) {
      return;
    }

    final trimmed = draft.targetName.trim();
    if (trimmed.isEmpty) {
      draft.action = RenamePlanAction.blocked;
      draft.issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'empty_name',
          message: '生成的文件名为空',
          sourcePath: draft.fileDetail.file.path,
          targetPath: draft.targetPath,
        ),
      );
      return;
    }

    if (draft.targetName == '.' || draft.targetName == '..') {
      draft.action = RenamePlanAction.blocked;
      draft.issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'invalid_relative_name',
          message: '文件名不能为 . 或 ..',
          sourcePath: draft.fileDetail.file.path,
          targetPath: draft.targetPath,
        ),
      );
      return;
    }

    if (isWindowsLike && _invalidWindowsChars.hasMatch(draft.targetName)) {
      draft.action = RenamePlanAction.blocked;
      draft.issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'invalid_windows_chars',
          message: '文件名包含 Windows 不允许的字符',
          sourcePath: draft.fileDetail.file.path,
          targetPath: draft.targetPath,
        ),
      );
      return;
    }

    if (isWindowsLike &&
        (draft.targetName.endsWith('.') || draft.targetName.endsWith(' '))) {
      draft.action = RenamePlanAction.blocked;
      draft.issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'invalid_windows_suffix',
          message: 'Windows 文件名不能以空格或句点结尾',
          sourcePath: draft.fileDetail.file.path,
          targetPath: draft.targetPath,
        ),
      );
      return;
    }

    if (isWindowsLike) {
      final baseName = path
          .basenameWithoutExtension(draft.targetName)
          .toUpperCase();
      if (_reservedWindowsNames.contains(baseName)) {
        draft.action = RenamePlanAction.blocked;
        draft.issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'reserved_windows_name',
            message: '文件名命中了 Windows 保留名称',
            sourcePath: draft.fileDetail.file.path,
            targetPath: draft.targetPath,
          ),
        );
      }
    }
  }

  static _DerivedTargetName _applyExifRule({
    required FileDetail fileDetail,
    required String originalName,
    required String exifTemplate,
    required Map<String, String>? exifData,
    required bool isPending,
    required int numberingValue,
    required String numberingPrefix,
    required String numberingSuffix,
    required NumberingType numberingType,
    required int fixedDigits,
    required ExifMissingPolicy missingPolicy,
  }) {
    if (exifTemplate.isEmpty) {
      return _DerivedTargetName(targetName: originalName);
    }

    final messages = <RenameIssue>[];
    final resolvedExif = exifData ?? const <String, String>{};
    final extension = path.extension(originalName);
    final templateMessages = <String>[];
    final isExifReady = resolvedExif.isNotEmpty || !isPending;
    final shotTime = resolvedExif['拍摄时间'];
    final parsedDate = _tryParseShotTime(shotTime);
    var missingPlaceholder = false;

    final renamed = exifTemplate.replaceAllMapped(_placeholderRegex, (match) {
      final placeholder = match.group(1) ?? '';
      if (placeholder == '序号') {
        return '$numberingPrefix${_formatNumber(numberingValue, numberingType, fixedDigits)}$numberingSuffix';
      }

      final resolved = _resolveExifPlaceholder(
        placeholder: placeholder,
        exifData: resolvedExif,
        parsedDate: parsedDate,
      );
      if (resolved != null) {
        return resolved;
      }
      missingPlaceholder = true;
      templateMessages.add(placeholder);
      return _notFoundPlaceholder;
    });

    if (missingPlaceholder || !isExifReady) {
      final missingReason = !isExifReady
          ? 'EXIF 信息仍在加载或不存在'
          : '缺少字段：${templateMessages.join('、')}';
      switch (missingPolicy) {
        case ExifMissingPolicy.keepOriginalNameWarning:
          messages.add(
            RenameIssue(
              severity: RenameIssueSeverity.warning,
              code: 'missing_exif_keep_original',
              message: '$missingReason，已保留原文件名',
              sourcePath: fileDetail.file.path,
            ),
          );
          return _DerivedTargetName(
            targetName: originalName,
            action: RenamePlanAction.rename,
            issues: messages,
          );
        case ExifMissingPolicy.skipFile:
          messages.add(
            RenameIssue(
              severity: RenameIssueSeverity.warning,
              code: 'missing_exif_skip',
              message: '$missingReason，已按策略跳过',
              sourcePath: fileDetail.file.path,
            ),
          );
          return _DerivedTargetName(
            targetName: originalName,
            action: RenamePlanAction.skip,
            issues: messages,
          );
        case ExifMissingPolicy.keepPlaceholder:
          messages.add(
            RenameIssue(
              severity: RenameIssueSeverity.warning,
              code: 'missing_exif_placeholder',
              message: '$missingReason，已使用 NaN 占位',
              sourcePath: fileDetail.file.path,
            ),
          );
          return _DerivedTargetName(
            targetName: '$renamed$extension',
            issues: messages,
          );
      }
    }

    return _DerivedTargetName(
      targetName: '$renamed$extension',
      issues: messages,
    );
  }

  static String? _resolveExifPlaceholder({
    required String placeholder,
    required Map<String, String> exifData,
    required DateTime? parsedDate,
  }) {
    switch (placeholder) {
      case '快门速度':
        final shutterSpeed = exifData['快门速度'] ?? exifData['曝光时间'];
        return shutterSpeed?.replaceAll('/', '-');
      case '年':
        return parsedDate?.year.toString();
      case '月':
        return parsedDate?.month.toString().padLeft(2, '0');
      case '日':
        return parsedDate?.day.toString().padLeft(2, '0');
      case '时':
        return parsedDate?.hour.toString().padLeft(2, '0');
      case '分':
        return parsedDate?.minute.toString().padLeft(2, '0');
      case '秒':
        return parsedDate?.second.toString().padLeft(2, '0');
      case '年月日':
        if (parsedDate == null) {
          return null;
        }
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      case '时分秒':
        if (parsedDate == null) {
          return null;
        }
        return DateFormat('HH-mm-ss').format(parsedDate);
      default:
        return exifData[placeholder]?.replaceAll('/', '-');
    }
  }

  static DateTime? _tryParseShotTime(String? shotTime) {
    if (shotTime == null || shotTime.isEmpty) {
      return null;
    }
    try {
      if (shotTime.contains(' ') && shotTime.contains(':')) {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parseStrict(shotTime);
      }
      return DateTime.tryParse(shotTime);
    } catch (_) {
      return DateTime.tryParse(shotTime);
    }
  }

  static String _applyReplaceRules(
    String fileName,
    List<ReplaceRule> replaceRules,
  ) {
    var result = fileName;
    for (final rule in replaceRules) {
      if (rule.findText.isEmpty) {
        continue;
      }
      if (!rule.allowReplaceExtension) {
        final dotIndex = result.lastIndexOf('.');
        if (dotIndex != -1) {
          final namePart = result.substring(0, dotIndex);
          final extensionPart = result.substring(dotIndex);
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

  static _DerivedTargetName _applyReplaceRulesWithValidation(
    String fileName,
    List<ReplaceRule> replaceRules,
    String sourcePath,
  ) {
    final hasEmptyFindText = replaceRules.any((rule) => rule.findText.isEmpty);
    final issues = <RenameIssue>[];
    if (hasEmptyFindText) {
      issues.add(
        RenameIssue(
          severity: RenameIssueSeverity.warning,
          code: 'empty_replace_find_text',
          message: '存在空的查找内容，已忽略对应替换规则',
          sourcePath: sourcePath,
        ),
      );
    }

    return _DerivedTargetName(
      targetName: _applyReplaceRules(fileName, replaceRules),
      issues: issues,
    );
  }

  static String _applyAppendRule(
    String fileName,
    String appendPrefix,
    String appendSuffix,
    AppendMode appendMode,
  ) {
    if (appendPrefix.isEmpty && appendSuffix.isEmpty) {
      return fileName;
    }

    switch (appendMode) {
      case AppendMode.aroundBaseName:
        final dotIndex = fileName.lastIndexOf('.');
        if (dotIndex == -1) {
          return '$appendPrefix$fileName$appendSuffix';
        }
        final namePart = fileName.substring(0, dotIndex);
        final extensionPart = fileName.substring(dotIndex);
        return '$appendPrefix$namePart$appendSuffix$extensionPart';
      case AppendMode.aroundFullName:
        return '$appendPrefix$fileName$appendSuffix';
    }
  }

  static String _applyAutoNumberingRule(
    String fileName, {
    required int startNumber,
    required int numberingOffset,
    required NumberingType numberingType,
    required int fixedDigits,
    required bool keepOriginalName,
    required String numberingPrefix,
    required String numberingSuffix,
  }) {
    final formatted = _formatNumber(
      startNumber + numberingOffset,
      numberingType,
      fixedDigits,
    );
    if (!keepOriginalName) {
      final extension = path.extension(fileName);
      return '$numberingPrefix$formatted$numberingSuffix$extension';
    }
    final baseName = path.basenameWithoutExtension(fileName);
    final extension = path.extension(fileName);
    return '$numberingPrefix$baseName$formatted$numberingSuffix$extension';
  }

  static String _formatNumber(int number, NumberingType type, int digits) {
    var formatted = switch (type) {
      NumberingType.arabic => number.toString(),
      NumberingType.upperRoman => _convertIntToRoman(number).toUpperCase(),
      NumberingType.lowerRoman => _convertIntToRoman(number).toLowerCase(),
      NumberingType.upperLetter => _convertIntToLetter(number).toUpperCase(),
      NumberingType.lowerLetter => _convertIntToLetter(number).toLowerCase(),
    };
    if (digits > 0) {
      formatted = formatted.padLeft(digits, '0');
    }
    return formatted;
  }

  static String _convertIntToRoman(int number) {
    if (number <= 0) {
      return '';
    }

    final romanNumerals = <MapEntry<int, String>>[
      const MapEntry(1000, 'M'),
      const MapEntry(900, 'CM'),
      const MapEntry(500, 'D'),
      const MapEntry(400, 'CD'),
      const MapEntry(100, 'C'),
      const MapEntry(90, 'XC'),
      const MapEntry(50, 'L'),
      const MapEntry(40, 'XL'),
      const MapEntry(10, 'X'),
      const MapEntry(9, 'IX'),
      const MapEntry(5, 'V'),
      const MapEntry(4, 'IV'),
      const MapEntry(1, 'I'),
    ];

    final buffer = StringBuffer();
    var remaining = number;
    for (final entry in romanNumerals) {
      while (remaining >= entry.key) {
        buffer.write(entry.value);
        remaining -= entry.key;
      }
    }
    return buffer.toString();
  }

  static String _convertIntToLetter(int number) {
    if (number <= 0) {
      return '';
    }

    final buffer = StringBuffer();
    var remaining = number;
    while (remaining > 0) {
      remaining--;
      buffer.write(String.fromCharCode('a'.codeUnitAt(0) + (remaining % 26)));
      remaining ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static Map<String, int> _buildNumberingOffsets(
    List<FileDetail> files, {
    required bool mergeSameName,
    required bool isWindowsLike,
  }) {
    final offsets = <String, int>{};
    if (!mergeSameName) {
      for (int index = 0; index < files.length; index++) {
        offsets[files[index].file.path] = index;
      }
      return offsets;
    }

    final groups = <String, int>{};
    var groupIndex = 0;
    for (final file in files) {
      final baseName = path.basenameWithoutExtension(file.file.path);
      final normalizedBase = isWindowsLike ? baseName.toLowerCase() : baseName;
      final offset = groups.putIfAbsent(normalizedBase, () => groupIndex++);
      offsets[file.file.path] = offset;
    }
    return offsets;
  }

  static Future<RenameExecutionResult> executePlan(RenamePlan plan) async {
    final planIssues = _collectPlanIssues(plan);
    final renameItems = plan.items
        .where((item) => item.willRename)
        .toList(growable: false);
    if (!plan.canExecute) {
      return RenameExecutionResult(
        plan: plan,
        successCount: 0,
        failedCount: plan.summary.conflictCount,
        skippedCount: plan.summary.skippedCount,
        warningCount: plan.summary.warningCount,
        renameLog: const [],
        issues: planIssues,
      );
    }

    final stages = _buildStages(renameItems);
    final outcome = await _runTransaction(stages);
    if (outcome.error != null) {
      return RenameExecutionResult(
        plan: plan,
        successCount: 0,
        failedCount: renameItems.length,
        skippedCount: plan.summary.skippedCount,
        warningCount: plan.summary.warningCount,
        renameLog: const [],
        issues: [...planIssues, outcome.error!, ...outcome.rollbackIssues],
      );
    }

    return RenameExecutionResult(
      plan: plan,
      successCount: renameItems.length,
      failedCount: 0,
      skippedCount: plan.summary.skippedCount,
      warningCount: plan.summary.warningCount,
      renameLog: outcome.renameLog,
      issues: planIssues,
    );
  }

  static Future<UndoResult> undo(List<RenameActionLog> renameLog) async {
    if (renameLog.isEmpty) {
      return const UndoResult(
        successCount: 0,
        failedCount: 0,
        revertedLog: [],
        issues: [],
      );
    }

    final stages = _buildUndoStages(renameLog);
    final outcome = await _runTransaction(stages);
    if (outcome.error != null) {
      return UndoResult(
        successCount: 0,
        failedCount: renameLog.length,
        revertedLog: const [],
        issues: [outcome.error!, ...outcome.rollbackIssues],
      );
    }

    final revertedLog = renameLog
        .map(
          (log) => RenameActionLog(
            oldPath: log.newPath,
            newPath: log.oldPath,
            temporaryPath: log.temporaryPath,
          ),
        )
        .toList(growable: false);
    return UndoResult(
      successCount: renameLog.length,
      failedCount: 0,
      revertedLog: revertedLog,
      issues: const [],
    );
  }

  static List<RenameIssue> _collectPlanIssues(RenamePlan plan) {
    return plan.items.expand((item) => item.issues).toList(growable: false);
  }

  static List<_RenameStage> _buildStages(List<RenamePlanItem> items) {
    final reserved = <String>{};
    for (final item in items) {
      reserved.add(
        _normalizePath(item.fileDetail.file.path, Platform.isWindows),
      );
      reserved.add(_normalizePath(item.targetPath, Platform.isWindows));
    }

    var counter = 0;
    return items
        .map((item) {
          final temporaryPath = _nextTemporaryPath(
            sourcePath: item.fileDetail.file.path,
            reserved: reserved,
            counterSeed: counter++,
            isWindowsLike: Platform.isWindows,
          );
          return _RenameStage(
            sourcePath: item.fileDetail.file.path,
            targetPath: item.targetPath,
            temporaryPath: temporaryPath,
          );
        })
        .toList(growable: false);
  }

  static List<_RenameStage> _buildUndoStages(List<RenameActionLog> renameLog) {
    final reserved = <String>{};
    for (final log in renameLog) {
      reserved.add(_normalizePath(log.oldPath, Platform.isWindows));
      reserved.add(_normalizePath(log.newPath, Platform.isWindows));
    }

    var counter = 0;
    return renameLog
        .map((log) {
          final temporaryPath = _nextTemporaryPath(
            sourcePath: log.newPath,
            reserved: reserved,
            counterSeed: counter++,
            isWindowsLike: Platform.isWindows,
          );
          return _RenameStage(
            sourcePath: log.newPath,
            targetPath: log.oldPath,
            temporaryPath: temporaryPath,
          );
        })
        .toList(growable: false);
  }

  static Future<_TransactionOutcome> _runTransaction(
    List<_RenameStage> stages,
  ) async {
    final tempRenamed = <_RenameStage>[];
    final finalized = <_RenameStage>[];

    try {
      for (final stage in stages) {
        await File(stage.sourcePath).rename(stage.temporaryPath);
        tempRenamed.add(stage);
      }

      for (final stage in stages) {
        await File(stage.temporaryPath).rename(stage.targetPath);
        finalized.add(stage);
      }
    } on FileSystemException catch (error) {
      final rollbackIssues = await _rollbackStages(
        tempRenamed: tempRenamed,
        finalized: finalized,
      );
      return _TransactionOutcome(
        error: RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'filesystem_transaction_error',
          message: error.osError?.message ?? error.message,
          sourcePath: finalized.isNotEmpty
              ? finalized.last.targetPath
              : tempRenamed.isNotEmpty
              ? tempRenamed.last.sourcePath
              : null,
        ),
        rollbackIssues: rollbackIssues,
      );
    } catch (error) {
      final rollbackIssues = await _rollbackStages(
        tempRenamed: tempRenamed,
        finalized: finalized,
      );
      return _TransactionOutcome(
        error: RenameIssue(
          severity: RenameIssueSeverity.error,
          code: 'generic_transaction_error',
          message: error.toString(),
        ),
        rollbackIssues: rollbackIssues,
      );
    }

    final renameLog = stages
        .map(
          (stage) => RenameActionLog(
            oldPath: stage.sourcePath,
            newPath: stage.targetPath,
            temporaryPath: stage.temporaryPath,
          ),
        )
        .toList(growable: false);
    return _TransactionOutcome(renameLog: renameLog);
  }

  static Future<List<RenameIssue>> _rollbackStages({
    required List<_RenameStage> tempRenamed,
    required List<_RenameStage> finalized,
  }) async {
    final issues = <RenameIssue>[];
    final finalizedTemps = finalized
        .map((stage) => stage.temporaryPath)
        .toSet();

    for (final stage in finalized.reversed) {
      try {
        await File(stage.targetPath).rename(stage.sourcePath);
      } catch (error) {
        issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'rollback_finalized_failed',
            message: '回滚最终文件失败: $error',
            sourcePath: stage.targetPath,
            targetPath: stage.sourcePath,
          ),
        );
      }
    }

    for (final stage in tempRenamed.reversed) {
      if (finalizedTemps.contains(stage.temporaryPath)) {
        continue;
      }
      try {
        await File(stage.temporaryPath).rename(stage.sourcePath);
      } catch (error) {
        issues.add(
          RenameIssue(
            severity: RenameIssueSeverity.error,
            code: 'rollback_temp_failed',
            message: '回滚临时文件失败: $error',
            sourcePath: stage.temporaryPath,
            targetPath: stage.sourcePath,
          ),
        );
      }
    }

    return issues;
  }

  static String _nextTemporaryPath({
    required String sourcePath,
    required Set<String> reserved,
    required int counterSeed,
    required bool isWindowsLike,
  }) {
    final directory = path.dirname(sourcePath);
    final extension = path.extension(sourcePath);
    var counter = counterSeed;
    while (true) {
      final candidate = path.join(
        directory,
        '.__camera_toolbox_tmp_${DateTime.now().microsecondsSinceEpoch}_$counter$extension',
      );
      final normalized = _normalizePath(candidate, isWindowsLike);
      if (!reserved.contains(normalized) && !File(candidate).existsSync()) {
        reserved.add(normalized);
        return candidate;
      }
      counter++;
    }
  }

  static bool _hasOccupancyConflict({
    required String candidatePath,
    required String candidateNorm,
    required _PlanDraft draft,
    required Set<String> movingSources,
    required Set<String> stationaryPaths,
    required Set<String> assignedTargets,
    required Map<String, bool> existingCache,
    required bool isWindowsLike,
  }) {
    final sourceNorm = _normalizePath(
      draft.fileDetail.file.path,
      isWindowsLike,
    );
    if (assignedTargets.contains(candidateNorm)) {
      return true;
    }
    if (sourceNorm != candidateNorm &&
        stationaryPaths.contains(candidateNorm)) {
      return true;
    }
    if (sourceNorm == candidateNorm) {
      return false;
    }
    if (movingSources.contains(candidateNorm)) {
      return false;
    }
    return existingCache.putIfAbsent(
      candidateNorm,
      () => File(candidatePath).existsSync(),
    );
  }

  static String _appendConflictSuffix(String fileName, int counter) {
    final extension = path.extension(fileName);
    final baseName = path.basenameWithoutExtension(fileName);
    return '${baseName}_$counter$extension';
  }

  static String _normalizePath(String filePath, bool isWindowsLike) {
    final normalized = path.normalize(filePath);
    return isWindowsLike ? normalized.toLowerCase() : normalized;
  }

  static bool _isCaseOnlyRename(
    String sourcePath,
    String targetPath,
    bool isWindowsLike,
  ) {
    if (sourcePath == targetPath) {
      return false;
    }
    return _normalizePath(sourcePath, isWindowsLike) ==
        _normalizePath(targetPath, isWindowsLike);
  }
}

class _DerivedTargetName {
  final String targetName;
  final RenamePlanAction action;
  final List<RenameIssue> issues;

  const _DerivedTargetName({
    required this.targetName,
    this.action = RenamePlanAction.rename,
    this.issues = const [],
  });
}

class _PlanDraft {
  final int index;
  final FileDetail fileDetail;
  final String originalName;
  String targetName;
  String targetPath;
  RenamePlanAction action;
  RenamePreviewStatus status;
  List<RenameIssue> issues;
  bool caseOnlyRename;

  _PlanDraft({
    required this.index,
    required this.fileDetail,
    required this.originalName,
    required this.targetName,
    required this.targetPath,
    required this.action,
    required this.status,
    required this.issues,
    required this.caseOnlyRename,
  });

  factory _PlanDraft.fromDerived({
    required int index,
    required FileDetail fileDetail,
    required String targetName,
    required RenamePlanAction action,
    required List<RenameIssue> issues,
    required bool isWindowsLike,
  }) {
    final originalName = path.basename(fileDetail.file.path);
    final targetPath = path.join(
      path.dirname(fileDetail.file.path),
      targetName,
    );
    var resolvedAction = action;
    if (resolvedAction == RenamePlanAction.rename &&
        RenameEngine._normalizePath(targetPath, isWindowsLike) ==
            RenameEngine._normalizePath(fileDetail.file.path, isWindowsLike)) {
      resolvedAction = RenamePlanAction.unchanged;
    }
    final caseOnlyRename = RenameEngine._isCaseOnlyRename(
      fileDetail.file.path,
      targetPath,
      isWindowsLike,
    );
    return _PlanDraft(
      index: index,
      fileDetail: fileDetail,
      originalName: originalName,
      targetName: targetName,
      targetPath: targetPath,
      action: resolvedAction,
      status: RenamePreviewStatus.normal,
      issues: [...issues],
      caseOnlyRename: caseOnlyRename,
    );
  }

  RenamePlanItem toPlanItem() {
    return RenamePlanItem(
      index: index,
      fileDetail: fileDetail,
      originalName: originalName,
      targetName: targetName,
      targetPath: targetPath,
      action: action,
      status: status,
      issues: List.unmodifiable(issues),
      caseOnlyRename: caseOnlyRename,
    );
  }
}

class _RenameStage {
  final String sourcePath;
  final String targetPath;
  final String temporaryPath;

  const _RenameStage({
    required this.sourcePath,
    required this.targetPath,
    required this.temporaryPath,
  });
}

class _TransactionOutcome {
  final List<RenameActionLog> renameLog;
  final RenameIssue? error;
  final List<RenameIssue> rollbackIssues;

  const _TransactionOutcome({
    this.renameLog = const [],
    this.error,
    this.rollbackIssues = const [],
  });
}
