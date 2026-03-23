import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:oldsun_camera_toolbox/src/features/rename/rename_engine.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/rename_models.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/replace_rule.dart';

void main() {
  FileDetail createFile(String path) {
    return FileDetail(
      file: File(path),
      size: 1,
      lastModified: DateTime(2024, 1, 1),
    );
  }

  RenamePlanRequest createRequest({
    required List<FileDetail> files,
    required RenameMode mode,
    List<ReplaceRule> replaceRules = const [],
    String exifTemplate = '',
    Map<String, Map<String, String>> exifData = const {},
    ExifMissingPolicy exifMissingPolicy =
        ExifMissingPolicy.keepOriginalNameWarning,
  }) {
    return RenamePlanRequest(
      files: files,
      mode: mode,
      replaceRules: replaceRules,
      appendPrefix: '',
      appendSuffix: '',
      appendMode: AppendMode.aroundBaseName,
      numberingPrefix: '',
      numberingSuffix: '',
      startNumber: 1,
      numberingType: NumberingType.arabic,
      fixedDigits: 0,
      keepOriginalName: false,
      mergeSameName: false,
      exifTemplate: exifTemplate,
      exifData: exifData,
      pendingExifPaths: const {},
      conflictPolicy: RenameConflictPolicy.strict,
      exifMissingPolicy: exifMissingPolicy,
      isWindowsLike: Platform.isWindows,
    );
  }

  test('empty replace find text is ignored and reported as warning', () {
    final file = createFile('/photos/IMG_0001.jpg');
    final plan = RenameEngine.buildPlan(
      createRequest(
        files: [file],
        mode: RenameMode.replace,
        replaceRules: [ReplaceRule(findText: '', replaceText: 'trip_')],
      ),
    );

    expect(plan.items.single.targetName, 'IMG_0001.jpg');
    expect(plan.items.single.action, RenamePlanAction.unchanged);
    expect(plan.items.single.issues, isNotEmpty);
    expect(plan.items.single.issues.single.code, 'empty_replace_find_text');
  });

  test('keep original name warning stays unchanged instead of skipped', () {
    final file = createFile('/photos/IMG_0001.jpg');
    final plan = RenameEngine.buildPlan(
      createRequest(
        files: [file],
        mode: RenameMode.exif,
        exifTemplate: '[拍摄时间]',
        exifData: const {},
        exifMissingPolicy: ExifMissingPolicy.keepOriginalNameWarning,
      ),
    );

    expect(plan.items.single.targetName, 'IMG_0001.jpg');
    expect(plan.items.single.action, RenamePlanAction.unchanged);
    expect(plan.summary.unchangedCount, 1);
    expect(plan.summary.skippedCount, 0);
    expect(plan.items.single.issues.single.code, 'missing_exif_keep_original');
  });
}
