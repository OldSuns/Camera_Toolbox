import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:oldsun_camera_toolbox/src/features/exif_reader/exif_data.dart';
import 'package:oldsun_camera_toolbox/src/features/local_picker/local_picker_provider.dart';
import 'package:oldsun_camera_toolbox/src/shared/utils/conflict_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validImageBytes = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0xF0,
    0x1F,
    0x00,
    0x05,
    0x00,
    0x01,
    0xFF,
    0x89,
    0x99,
    0x3D,
    0x1D,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  Future<LocalPickerProvider> createProvider(
    Directory sandbox, {
    Future<ExifData> Function(String path)? exifReader,
  }) async {
    final cacheDir = await Directory(p.join(sandbox.path, 'cache')).create();
    final provider = LocalPickerProvider(
      cacheDirectoryProvider: () async => cacheDir,
      exifReader: exifReader ?? (path) async => ExifData.empty(path),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return provider;
  }

  Future<void> writeFile(String filePath, List<int> bytes) async {
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  test('falls back to file modified time for HEIC metadata', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'camera_toolbox_local_picker_metadata_',
    );
    final provider = await createProvider(sandbox);
    addTearDown(() async {
      provider.dispose();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final image = File(p.join(sandbox.path, 'sample.heic'));
    await image.writeAsBytes(validImageBytes);
    final modified = DateTime(2024, 1, 2, 3, 4, 5);
    await image.setLastModified(modified);

    await provider.loadDirectory(sandbox.path);
    provider.setShowCaptureInfo(true);
    await provider.ensureMetadataLoaded(image.path);

    final metadata = provider.metadataForPath(image.path);
    expect(metadata, isNotNull);
    expect(metadata!.captureTimeSource, CaptureTimeSource.fileModified);
    expect(metadata.captureTime, modified);
  });

  test('export rename strategy creates suffixed image and raw files', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'camera_toolbox_local_picker_export_rename_',
    );
    final inputDir = await Directory(p.join(sandbox.path, 'input')).create();
    final outputDir = await Directory(p.join(sandbox.path, 'output')).create();
    final provider = await createProvider(sandbox);
    addTearDown(() async {
      provider.dispose();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    await writeFile(p.join(inputDir.path, 'photo.jpg'), validImageBytes);
    await writeFile(p.join(inputDir.path, 'photo.cr3'), const [4, 5, 6]);
    await writeFile(p.join(outputDir.path, 'photo.jpg'), validImageBytes);
    await writeFile(p.join(outputDir.path, 'photo.cr3'), const [8]);

    await provider.loadDirectory(inputDir.path);
    provider.selectAll();

    final result = await provider.exportSelectedToDirectory(
      LocalPickerExportOptions(
        targetDirectory: outputDir.path,
        conflictAction: ConflictAction.rename,
        includeRaw: true,
      ),
    );

    expect(result.exportedImageCount, 1);
    expect(result.exportedRawCount, 1);
    expect(result.renamedCount, 1);
    expect(result.skippedCount, 0);
    expect(result.failedCount, 0);
    expect(File(p.join(outputDir.path, 'photo_1.jpg')).existsSync(), isTrue);
    expect(File(p.join(outputDir.path, 'photo_1.cr3')).existsSync(), isTrue);
  });

  test('export skip strategy reports skipped target path', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'camera_toolbox_local_picker_export_skip_',
    );
    final inputDir = await Directory(p.join(sandbox.path, 'input')).create();
    final outputDir = await Directory(p.join(sandbox.path, 'output')).create();
    final provider = await createProvider(sandbox);
    addTearDown(() async {
      provider.dispose();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    await writeFile(p.join(inputDir.path, 'photo.jpg'), validImageBytes);
    await writeFile(p.join(outputDir.path, 'photo.jpg'), validImageBytes);

    await provider.loadDirectory(inputDir.path);
    provider.selectAll();

    final result = await provider.exportSelectedToDirectory(
      LocalPickerExportOptions(
        targetDirectory: outputDir.path,
        conflictAction: ConflictAction.skip,
      ),
    );

    expect(result.exportedImageCount, 0);
    expect(result.skippedCount, 1);
    expect(result.failedCount, 0);
    expect(
      result.issues.single.targetPath,
      p.join(outputDir.path, 'photo.jpg'),
    );
  });

  test('export overwrite strategy replaces existing outputs', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'camera_toolbox_local_picker_export_overwrite_',
    );
    final inputDir = await Directory(p.join(sandbox.path, 'input')).create();
    final outputDir = await Directory(p.join(sandbox.path, 'output')).create();
    final provider = await createProvider(sandbox);
    addTearDown(() async {
      provider.dispose();
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final imagePath = p.join(inputDir.path, 'photo.jpg');
    final rawPath = p.join(inputDir.path, 'photo.cr3');
    final outputImagePath = p.join(outputDir.path, 'photo.jpg');
    final outputRawPath = p.join(outputDir.path, 'photo.cr3');

    await writeFile(imagePath, validImageBytes);
    await writeFile(rawPath, const [4, 5, 6]);
    await writeFile(outputImagePath, validImageBytes);
    await writeFile(outputRawPath, const [8]);

    await provider.loadDirectory(inputDir.path);
    provider.selectAll();

    final result = await provider.exportSelectedToDirectory(
      LocalPickerExportOptions(
        targetDirectory: outputDir.path,
        conflictAction: ConflictAction.overwrite,
        includeRaw: true,
      ),
    );

    expect(result.exportedImageCount, 1);
    expect(result.exportedRawCount, 1);
    expect(result.skippedCount, 0);
    expect(result.failedCount, 0);
    expect(await File(outputImagePath).readAsBytes(), validImageBytes);
    expect(await File(outputRawPath).readAsBytes(), const [4, 5, 6]);
  });

  test(
    'export overwrite skips self-overwrite when target directory matches source directory',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'camera_toolbox_local_picker_export_self_overwrite_',
      );
      final inputDir = await Directory(p.join(sandbox.path, 'input')).create();
      final provider = await createProvider(sandbox);
      addTearDown(() async {
        provider.dispose();
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      final imagePath = p.join(inputDir.path, 'photo.jpg');
      final rawPath = p.join(inputDir.path, 'photo.cr3');
      await writeFile(imagePath, validImageBytes);
      await writeFile(rawPath, const [4, 5, 6]);

      await provider.loadDirectory(inputDir.path);
      provider.selectAll();

      final result = await provider.exportSelectedToDirectory(
        LocalPickerExportOptions(
          targetDirectory: inputDir.path,
          conflictAction: ConflictAction.overwrite,
          includeRaw: true,
        ),
      );

      expect(result.exportedImageCount, 0);
      expect(result.exportedRawCount, 0);
      expect(result.skippedCount, 2);
      expect(result.failedCount, 0);
      expect(await File(imagePath).readAsBytes(), validImageBytes);
      expect(await File(rawPath).readAsBytes(), const [4, 5, 6]);
    },
  );
}
