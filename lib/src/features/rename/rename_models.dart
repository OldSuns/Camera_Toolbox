import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

enum RenameMode { replace, append, autoNumbering, exif }

enum SortCriterion { nameAsc, nameDesc, dateAsc, dateDesc }

enum AppendMode {
  aroundBaseName,
  aroundFullName;

  String get displayName {
    switch (this) {
      case AppendMode.aroundBaseName:
        return '仅文件名';
      case AppendMode.aroundFullName:
        return '完整名称';
    }
  }

  String get description {
    switch (this) {
      case AppendMode.aroundBaseName:
        return '前后缀只作用于扩展名前的文件名部分';
      case AppendMode.aroundFullName:
        return '前后缀直接作用于完整名称，包含扩展名';
    }
  }
}

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

enum RenameConflictPolicy {
  strict,
  autoRename,
  skipConflicts;

  String get displayName {
    switch (this) {
      case RenameConflictPolicy.strict:
        return '严格拦截';
      case RenameConflictPolicy.autoRename:
        return '自动消解';
      case RenameConflictPolicy.skipConflicts:
        return '跳过冲突';
    }
  }

  String get description {
    switch (this) {
      case RenameConflictPolicy.strict:
        return '检测到冲突时阻止执行';
      case RenameConflictPolicy.autoRename:
        return '自动追加 _1、_2 解决冲突';
      case RenameConflictPolicy.skipConflicts:
        return '冲突文件跳过，其余文件继续';
    }
  }
}

enum ExifMissingPolicy {
  keepOriginalNameWarning,
  skipFile,
  keepPlaceholder;

  String get displayName {
    switch (this) {
      case ExifMissingPolicy.keepOriginalNameWarning:
        return '保留原名警告';
      case ExifMissingPolicy.skipFile:
        return '跳过该文件';
      case ExifMissingPolicy.keepPlaceholder:
        return '继续占位';
    }
  }

  String get description {
    switch (this) {
      case ExifMissingPolicy.keepOriginalNameWarning:
        return '缺少 EXIF 时保留原名并提示';
      case ExifMissingPolicy.skipFile:
        return '缺少 EXIF 时不参与本次重命名';
      case ExifMissingPolicy.keepPlaceholder:
        return '缺少 EXIF 时继续使用 NaN 占位';
    }
  }
}

enum RenamePreviewStatus { normal, unchanged, warning, conflict }

enum RenamePlanAction { rename, unchanged, skip, blocked }

enum RenameIssueSeverity { info, warning, error }

extension RenamePreviewStatusX on RenamePreviewStatus {
  String get label {
    switch (this) {
      case RenamePreviewStatus.normal:
        return '正常';
      case RenamePreviewStatus.unchanged:
        return '未变化';
      case RenamePreviewStatus.warning:
        return '警告';
      case RenamePreviewStatus.conflict:
        return '冲突';
    }
  }
}

extension RenamePlanActionX on RenamePlanAction {
  String get label {
    switch (this) {
      case RenamePlanAction.rename:
        return '重命名';
      case RenamePlanAction.unchanged:
        return '未变化';
      case RenamePlanAction.skip:
        return '跳过';
      case RenamePlanAction.blocked:
        return '阻止执行';
    }
  }
}

@immutable
class FileDetail {
  final File file;
  final int size;
  final DateTime lastModified;

  const FileDetail({
    required this.file,
    required this.size,
    required this.lastModified,
  });

  String get fileName => path.basename(file.path);

  factory FileDetail.fromJson(Map<String, dynamic> json) {
    return FileDetail(
      file: File(json['path'] as String),
      size: json['size'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': file.path,
      'size': size,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  FileDetail copyWithPath(String newPath) {
    return FileDetail(
      file: File(newPath),
      size: size,
      lastModified: lastModified,
    );
  }
}

@immutable
class RenameIssue {
  final RenameIssueSeverity severity;
  final String code;
  final String message;
  final String? sourcePath;
  final String? targetPath;

  const RenameIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.sourcePath,
    this.targetPath,
  });

  bool get isWarning => severity == RenameIssueSeverity.warning;

  bool get isError => severity == RenameIssueSeverity.error;

  String? get fileName {
    if (sourcePath == null || sourcePath!.isEmpty) {
      return null;
    }
    return path.basename(sourcePath!);
  }
}

@immutable
class RenameActionLog {
  final String oldPath;
  final String newPath;
  final String? temporaryPath;

  const RenameActionLog({
    required this.oldPath,
    required this.newPath,
    this.temporaryPath,
  });
}

@immutable
class RenamePlanItem {
  final int index;
  final FileDetail fileDetail;
  final String originalName;
  final String targetName;
  final String targetPath;
  final RenamePlanAction action;
  final RenamePreviewStatus status;
  final List<RenameIssue> issues;
  final bool caseOnlyRename;

  const RenamePlanItem({
    required this.index,
    required this.fileDetail,
    required this.originalName,
    required this.targetName,
    required this.targetPath,
    required this.action,
    required this.status,
    required this.issues,
    this.caseOnlyRename = false,
  });

  bool get willRename => action == RenamePlanAction.rename;

  bool get isSkipped => action == RenamePlanAction.skip;

  bool get isBlocked => action == RenamePlanAction.blocked;

  bool get hasWarnings => issues.any((issue) => issue.isWarning);

  bool get hasErrors => issues.any((issue) => issue.isError);

  String get primaryMessage {
    if (issues.isEmpty) {
      return action.label;
    }
    return issues.first.message;
  }
}

@immutable
class RenamePlanSummary {
  final int renameCount;
  final int unchangedCount;
  final int skippedCount;
  final int conflictCount;
  final int blockedCount;
  final int warningCount;

  const RenamePlanSummary({
    required this.renameCount,
    required this.unchangedCount,
    required this.skippedCount,
    required this.conflictCount,
    required this.blockedCount,
    required this.warningCount,
  });

  bool get hasBlockingConflicts => blockedCount > 0;
}

@immutable
class RenamePlan {
  final List<RenamePlanItem> items;
  final RenamePlanSummary summary;

  const RenamePlan({required this.items, required this.summary});

  const RenamePlan.empty()
    : items = const [],
      summary = const RenamePlanSummary(
        renameCount: 0,
        unchangedCount: 0,
        skippedCount: 0,
        conflictCount: 0,
        blockedCount: 0,
        warningCount: 0,
      );

  bool get canExecute =>
      summary.renameCount > 0 && !summary.hasBlockingConflicts;
}

@immutable
class RenameExecutionResult {
  final RenamePlan plan;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final int warningCount;
  final List<RenameActionLog> renameLog;
  final List<RenameIssue> issues;

  const RenameExecutionResult({
    required this.plan,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.warningCount,
    required this.renameLog,
    required this.issues,
  });
}

@immutable
class UndoResult {
  final int successCount;
  final int failedCount;
  final List<RenameActionLog> revertedLog;
  final List<RenameIssue> issues;

  const UndoResult({
    required this.successCount,
    required this.failedCount,
    required this.revertedLog,
    required this.issues,
  });
}
