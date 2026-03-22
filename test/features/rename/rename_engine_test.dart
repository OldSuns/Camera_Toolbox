import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import 'package:oldsun_camera_toolbox/src/features/rename/rename_engine.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/rename_provider.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/rename_screen.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/replace_rule.dart';
import 'package:oldsun_camera_toolbox/src/features/rename/widgets/replace_rename_view.dart';

void main() {
  group('RenameEngine', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rename_engine_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'applies replace rule without touching extension by default',
      () async {
        final file = await _createFile(tempDir, 'IMG_test.jpg');
        final plan = RenameEngine.buildPlan(
          _request(
            files: [file],
            mode: RenameMode.replace,
            replaceRules: [ReplaceRule(findText: 'IMG_', replaceText: 'DSC_')],
          ),
        );

        expect(plan.items.single.targetName, 'DSC_test.jpg');
        expect(plan.canExecute, isTrue);
      },
    );

    test(
      'marks duplicate targets as blocking conflicts in strict mode',
      () async {
        final first = await _createFile(tempDir, 'a.txt');
        final second = await _createFile(tempDir, 'b.txt');

        final plan = RenameEngine.buildPlan(
          _request(
            files: [first, second],
            mode: RenameMode.exif,
            exifTemplate: 'SAME',
            conflictPolicy: RenameConflictPolicy.strict,
          ),
        );

        expect(plan.summary.conflictCount, 2);
        expect(plan.summary.blockedCount, 2);
        expect(plan.canExecute, isFalse);
      },
    );

    test('auto resolves duplicate targets with numbered suffixes', () async {
      final first = await _createFile(tempDir, 'a.txt');
      final second = await _createFile(tempDir, 'b.txt');

      final plan = RenameEngine.buildPlan(
        _request(
          files: [first, second],
          mode: RenameMode.exif,
          exifTemplate: 'SAME',
          conflictPolicy: RenameConflictPolicy.autoRename,
        ),
      );

      expect(plan.canExecute, isTrue);
      expect(plan.items.map((item) => item.targetName).toSet(), {
        'SAME.txt',
        'SAME_1.txt',
      });
      expect(plan.summary.warningCount, 1);
    });

    test('skip-conflicts policy remains executable', () async {
      final first = await _createFile(tempDir, 'a.txt');
      final second = await _createFile(tempDir, 'b.txt');

      final plan = RenameEngine.buildPlan(
        _request(
          files: [first, second],
          mode: RenameMode.exif,
          exifTemplate: 'SAME',
          conflictPolicy: RenameConflictPolicy.skipConflicts,
        ),
      );

      expect(plan.summary.conflictCount, 2);
      expect(plan.summary.blockedCount, 0);
      expect(plan.canExecute, isFalse);
      expect(plan.summary.renameCount, 0);
      expect(plan.summary.skippedCount, 2);
    });

    test(
      'keeps original name with warning when EXIF fields are missing',
      () async {
        final file = await _createFile(tempDir, 'photo.jpg');

        final plan = RenameEngine.buildPlan(
          _request(
            files: [file],
            mode: RenameMode.exif,
            exifTemplate: 'IMG_[年月日]',
            exifMissingPolicy: ExifMissingPolicy.keepOriginalNameWarning,
          ),
        );

        final item = plan.items.single;
        expect(item.action, RenamePlanAction.skip);
        expect(item.status, RenamePreviewStatus.warning);
        expect(item.targetName, 'photo.jpg');
      },
    );

    test(
      'uses placeholder output when EXIF is pending and policy allows it',
      () async {
        final file = await _createFile(tempDir, 'photo.jpg');

        final plan = RenameEngine.buildPlan(
          _request(
            files: [file],
            mode: RenameMode.exif,
            exifTemplate: '[年]',
            pendingExifPaths: {file.file.path},
            exifMissingPolicy: ExifMissingPolicy.keepPlaceholder,
          ),
        );

        final item = plan.items.single;
        expect(item.status, RenamePreviewStatus.warning);
        expect(item.targetName, 'NaN.jpg');
      },
    );

    test(
      'executes swap rename with two-phase transaction and supports undo',
      () async {
        final first = await _createFile(tempDir, 'a.txt', content: 'A');
        final second = await _createFile(tempDir, 'b.txt', content: 'B');

        final plan = RenamePlan(
          items: [
            RenamePlanItem(
              index: 0,
              fileDetail: first,
              originalName: 'a.txt',
              targetName: 'b.txt',
              targetPath: path.join(tempDir.path, 'b.txt'),
              action: RenamePlanAction.rename,
              status: RenamePreviewStatus.normal,
              issues: const [],
            ),
            RenamePlanItem(
              index: 1,
              fileDetail: second,
              originalName: 'b.txt',
              targetName: 'a.txt',
              targetPath: path.join(tempDir.path, 'a.txt'),
              action: RenamePlanAction.rename,
              status: RenamePreviewStatus.normal,
              issues: const [],
            ),
          ],
          summary: const RenamePlanSummary(
            renameCount: 2,
            unchangedCount: 0,
            skippedCount: 0,
            conflictCount: 0,
            blockedCount: 0,
            warningCount: 0,
          ),
        );

        final executeResult = await RenameEngine.executePlan(plan);
        expect(executeResult.failedCount, 0);
        expect(
          await File(path.join(tempDir.path, 'a.txt')).readAsString(),
          'B',
        );
        expect(
          await File(path.join(tempDir.path, 'b.txt')).readAsString(),
          'A',
        );

        final undoResult = await RenameEngine.undo(executeResult.renameLog);
        expect(undoResult.failedCount, 0);
        expect(
          await File(path.join(tempDir.path, 'a.txt')).readAsString(),
          'A',
        );
        expect(
          await File(path.join(tempDir.path, 'b.txt')).readAsString(),
          'B',
        );
      },
    );
  });

  group('RenameProvider', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rename_provider_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('updates provider paths after execute and undo', () async {
      final firstPath = path.join(tempDir.path, 'first.txt');
      final secondPath = path.join(tempDir.path, 'second.txt');
      await File(firstPath).writeAsString('1');
      await File(secondPath).writeAsString('2');

      final provider = RenameProvider();
      await provider.addFiles([XFile(firstPath), XFile(secondPath)]);
      provider.setActiveTabIndex(RenameMode.append.index);
      provider.setAppendPrefix('renamed_');

      final result = await provider.executeRename();
      expect(result.failedCount, 0);
      expect(
        provider.files.map((file) => path.basename(file.file.path)).toSet(),
        {'renamed_first.txt', 'renamed_second.txt'},
      );

      final undoResult = await provider.undoRename();
      expect(undoResult.failedCount, 0);
      expect(
        provider.files.map((file) => path.basename(file.file.path)).toSet(),
        {'first.txt', 'second.txt'},
      );
      expect(provider.lastRenameLog, isEmpty);
    });
  });

  testWidgets('replace view toggles extension option per rule', (tester) async {
    final provider = RenameProvider();
    provider.addReplaceRule();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: ReplaceRenameView())),
      ),
    );

    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pumpAndSettle();

    expect(provider.replaceRules.first.allowReplaceExtension, isFalse);
    expect(provider.replaceRules[1].allowReplaceExtension, isTrue);
  });

  testWidgets('rename screen shows conflict preview and confirmation summary', (
    tester,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'rename_screen_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final firstPath = path.join(tempDir.path, 'first.txt');
    final secondPath = path.join(tempDir.path, 'second.txt');
    await File(firstPath).writeAsString('1');
    await File(secondPath).writeAsString('2');

    final provider = RenameProvider();
    await provider.addFiles([XFile(firstPath), XFile(secondPath)]);
    provider.setActiveTabIndex(RenameMode.exif.index);
    provider.setExifTemplate('SAME');
    provider.setConflictPolicy(RenameConflictPolicy.strict);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: RenameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('冲突'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, '确定重命名'));
    await tester.pumpAndSettle();

    expect(find.text('确认重命名'), findsOneWidget);
    expect(find.textContaining('冲突 2'), findsOneWidget);

    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '确认'),
    );
    expect(confirmButton.onPressed, isNull);
  });
}

Future<FileDetail> _createFile(
  Directory directory,
  String name, {
  String content = 'data',
}) async {
  final file = File(path.join(directory.path, name));
  await file.writeAsString(content);
  return FileDetail(
    file: file,
    size: await file.length(),
    lastModified: await file.lastModified(),
  );
}

RenamePlanRequest _request({
  required List<FileDetail> files,
  RenameMode mode = RenameMode.replace,
  List<ReplaceRule>? replaceRules,
  String appendPrefix = '',
  String appendSuffix = '',
  AppendMode appendMode = AppendMode.aroundBaseName,
  String numberingPrefix = '',
  String numberingSuffix = '',
  int startNumber = 1,
  NumberingType numberingType = NumberingType.arabic,
  int fixedDigits = 0,
  bool keepOriginalName = false,
  bool mergeSameName = false,
  String exifTemplate = '',
  Map<String, Map<String, String>> exifData = const {},
  Set<String> pendingExifPaths = const {},
  RenameConflictPolicy conflictPolicy = RenameConflictPolicy.strict,
  ExifMissingPolicy exifMissingPolicy =
      ExifMissingPolicy.keepOriginalNameWarning,
}) {
  return RenamePlanRequest(
    files: files,
    mode: mode,
    replaceRules: replaceRules ?? [ReplaceRule()],
    appendPrefix: appendPrefix,
    appendSuffix: appendSuffix,
    appendMode: appendMode,
    numberingPrefix: numberingPrefix,
    numberingSuffix: numberingSuffix,
    startNumber: startNumber,
    numberingType: numberingType,
    fixedDigits: fixedDigits,
    keepOriginalName: keepOriginalName,
    mergeSameName: mergeSameName,
    exifTemplate: exifTemplate,
    exifData: exifData,
    pendingExifPaths: pendingExifPaths,
    conflictPolicy: conflictPolicy,
    exifMissingPolicy: exifMissingPolicy,
    isWindowsLike: Platform.isWindows,
  );
}
