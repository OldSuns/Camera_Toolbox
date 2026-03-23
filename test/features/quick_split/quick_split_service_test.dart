import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:oldsun_camera_toolbox/src/features/quick_split/quick_split_exception.dart';
import 'package:oldsun_camera_toolbox/src/features/quick_split/quick_split_service.dart';
import 'package:oldsun_camera_toolbox/src/shared/utils/conflict_action.dart';

void main() {
  test('cancel stops copy and removes partial output file', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'camera_toolbox_quick_split_test_',
    );
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final imageDir = await Directory(p.join(sandbox.path, 'jpg')).create();
    final rawDir = await Directory(p.join(sandbox.path, 'raw')).create();
    final outputDir = await Directory(p.join(sandbox.path, 'out')).create();

    await File(
      p.join(imageDir.path, 'photo.jpg'),
    ).writeAsBytes(const [1, 2, 3]);
    await File(
      p.join(rawDir.path, 'photo.cr3'),
    ).writeAsBytes(List<int>.filled(8 * 1024 * 1024, 7));

    final service = QuickSplitService(
      perChunkDelay: const Duration(milliseconds: 1),
    );

    final future = service.processFiles(
      imageDirectory: imageDir.path,
      rawDirectory: rawDir.path,
      outputDirectory: outputDir.path,
      conflictAction: ConflictAction.rename,
      onProgress: (processed, total) {},
    );

    Future<void>.delayed(const Duration(milliseconds: 5), service.cancel);

    await expectLater(future, throwsA(isA<QuickSplitCancelledException>()));
    expect(File(p.join(outputDir.path, 'photo.cr3')).existsSync(), isFalse);
  });

  test(
    'overwrite skips same-path copies instead of deleting source raw files',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'camera_toolbox_quick_split_same_path_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      final imageDir = await Directory(p.join(sandbox.path, 'jpg')).create();
      final rawDir = await Directory(p.join(sandbox.path, 'raw')).create();

      await File(p.join(imageDir.path, 'photo.jpg')).writeAsBytes(const [1]);
      final rawPath = p.join(rawDir.path, 'photo.cr3');
      await File(rawPath).writeAsBytes(const [7, 7, 7]);

      final service = QuickSplitService();
      final result = await service.processFiles(
        imageDirectory: imageDir.path,
        rawDirectory: rawDir.path,
        outputDirectory: rawDir.path,
        conflictAction: ConflictAction.overwrite,
        onProgress: (processed, total) {},
      );

      expect(result.matchedCount, 1);
      expect(result.copiedCount, 0);
      expect(result.skippedCount, 1);
      expect(File(rawPath).existsSync(), isTrue);
      expect(await File(rawPath).readAsBytes(), const [7, 7, 7]);
    },
  );

  test(
    'matching prefers higher-priority raw extension when duplicates exist',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'camera_toolbox_quick_split_priority_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      final imageDir = await Directory(p.join(sandbox.path, 'jpg')).create();
      final rawDir = await Directory(p.join(sandbox.path, 'raw')).create();
      final outputDir = await Directory(p.join(sandbox.path, 'out')).create();

      await File(p.join(imageDir.path, 'photo.jpg')).writeAsBytes(const [1]);
      await File(p.join(rawDir.path, 'photo.dng')).writeAsBytes(const [3]);
      await File(p.join(rawDir.path, 'photo.cr3')).writeAsBytes(const [9]);

      final service = QuickSplitService();
      final result = await service.processFiles(
        imageDirectory: imageDir.path,
        rawDirectory: rawDir.path,
        outputDirectory: outputDir.path,
        conflictAction: ConflictAction.rename,
        onProgress: (processed, total) {},
      );

      expect(result.copiedCount, 1);
      expect(File(p.join(outputDir.path, 'photo.cr3')).existsSync(), isTrue);
      expect(File(p.join(outputDir.path, 'photo.dng')).existsSync(), isFalse);
    },
  );
}
