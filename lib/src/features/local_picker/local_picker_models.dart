import 'package:flutter/foundation.dart';

import '../../shared/utils/conflict_action.dart';

enum FolderScanScope {
  currentOnly,
  recursive;

  String get displayName {
    switch (this) {
      case FolderScanScope.currentOnly:
        return '当前目录';
      case FolderScanScope.recursive:
        return '递归子目录';
    }
  }
}

enum LocalPickerSortMode {
  nameAsc,
  nameDesc,
  modifiedNewest,
  modifiedOldest;

  String get displayName {
    switch (this) {
      case LocalPickerSortMode.nameAsc:
        return '文件名升序';
      case LocalPickerSortMode.nameDesc:
        return '文件名降序';
      case LocalPickerSortMode.modifiedNewest:
        return '修改时间最新';
      case LocalPickerSortMode.modifiedOldest:
        return '修改时间最早';
    }
  }
}

enum LocalPickerFilterMode {
  all,
  selected,
  withRaw;

  String get displayName {
    switch (this) {
      case LocalPickerFilterMode.all:
        return '全部';
      case LocalPickerFilterMode.selected:
        return '已选';
      case LocalPickerFilterMode.withRaw:
        return '有 RAW';
    }
  }
}

@immutable
class LocalImageEntry {
  final String path;
  final String fileName;
  final String directoryPath;
  final int size;
  final DateTime lastModified;
  final String? rawPath;

  const LocalImageEntry({
    required this.path,
    required this.fileName,
    required this.directoryPath,
    required this.size,
    required this.lastModified,
    this.rawPath,
  });

  bool get hasRaw => rawPath != null && rawPath!.isNotEmpty;
}

enum CaptureTimeSource {
  exif,
  fileModified;

  String get label {
    switch (this) {
      case CaptureTimeSource.exif:
        return '拍摄时间';
      case CaptureTimeSource.fileModified:
        return '文件时间';
    }
  }
}

enum MetadataLoadState { idle, loading, loaded }

@immutable
class LocalImageMetadata {
  final DateTime captureTime;
  final CaptureTimeSource captureTimeSource;
  final MetadataLoadState loadState;
  final String? cameraModel;
  final String? aperture;
  final String? shutterSpeed;
  final String? iso;
  final String? focalLength;

  const LocalImageMetadata({
    required this.captureTime,
    required this.captureTimeSource,
    required this.loadState,
    this.cameraModel,
    this.aperture,
    this.shutterSpeed,
    this.iso,
    this.focalLength,
  });

  factory LocalImageMetadata.fallback(
    DateTime fileModified, {
    MetadataLoadState loadState = MetadataLoadState.loaded,
  }) {
    return LocalImageMetadata(
      captureTime: fileModified,
      captureTimeSource: CaptureTimeSource.fileModified,
      loadState: loadState,
    );
  }

  bool get isLoading => loadState == MetadataLoadState.loading;

  String get captureTimeLabel => captureTimeSource.label;

  String? get exposureSummary {
    final parts = [
      iso,
      shutterSpeed,
      aperture,
      focalLength,
    ].where((value) => value?.trim().isNotEmpty ?? false).cast<String>();

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }
}

@immutable
class LocalPickerExportOptions {
  final String targetDirectory;
  final ConflictAction conflictAction;
  final bool includeRaw;

  const LocalPickerExportOptions({
    required this.targetDirectory,
    this.conflictAction = ConflictAction.rename,
    this.includeRaw = false,
  });
}

@immutable
class LocalPickerExportIssue {
  final String sourcePath;
  final String message;
  final String? targetPath;
  final bool isRaw;

  const LocalPickerExportIssue({
    required this.sourcePath,
    required this.message,
    this.targetPath,
    this.isRaw = false,
  });
}

@immutable
class LocalPickerExportResult {
  final int exportedImageCount;
  final int exportedRawCount;
  final int renamedCount;
  final int skippedCount;
  final int failedCount;
  final List<LocalPickerExportIssue> issues;

  const LocalPickerExportResult({
    required this.exportedImageCount,
    required this.exportedRawCount,
    required this.renamedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.issues,
  });
}

@immutable
class LocalPickerUserMessage {
  final int id;
  final String message;

  const LocalPickerUserMessage({required this.id, required this.message});
}
