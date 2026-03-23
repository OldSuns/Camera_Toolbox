import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:oldsun_camera_toolbox/src/features/image_compress/image_compress_screen.dart';
import 'package:oldsun_camera_toolbox/src/features/image_compress/image_compress_service.dart';

void main() {
  test('compression results are matched by file path, not file name', () async {
    final service = ImageCompressService();
    addTearDown(service.dispose);

    final first = ImageFile(
      name: 'same.jpg',
      filePath: '/input/a/same.jpg',
      sizeInBytes: 100,
      width: 100,
      height: 100,
    );
    final second = ImageFile(
      name: 'same.jpg',
      filePath: '/input/b/same.jpg',
      sizeInBytes: 200,
      width: 200,
      height: 200,
    );

    service.replaceSelectedImagesForTesting([first, second]);
    await service.applyCompressionResultForTesting(
      filePath: second.filePath,
      fileName: second.name,
      success: true,
      compressedFilePath: '/output/b/same_compressed.jpg',
      compressedSize: 80,
    );

    expect(service.selectedImages[0].isCompleted, isFalse);
    expect(service.selectedImages[1].isCompleted, isTrue);
    expect(
      service.selectedImages[1].compressedFilePath,
      '/output/b/same_compressed.jpg',
    );
  });

  testWidgets('row selection survives item instance replacement', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ImageCompressScreen()));

    final context = Platform.isWindows
        ? tester.element(find.widgetWithText(ElevatedButton, '添加').first)
        : tester.element(find.byType(DataTable2).first);
    final service = Provider.of<ImageCompressService>(context, listen: false);
    final file = ImageFile(
      name: 'selected.jpg',
      filePath: '/input/selected.jpg',
      sizeInBytes: 120,
      width: 100,
      height: 100,
    );

    service.replaceSelectedImagesForTesting([file]);
    await tester.pumpAndSettle();

    if (Platform.isWindows) {
      expect(find.byType(DataTable2), findsNothing);
    } else {
      expect(find.byType(DataTable2), findsOneWidget);
    }

    final rowCheckbox = Platform.isWindows
        ? find.byKey(const ValueKey('compress_select_/input/selected.jpg'))
        : find.byType(Checkbox).last;
    await tester.tap(rowCheckbox);
    await tester.pumpAndSettle();

    final removeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '移除'),
    );
    expect(removeButton.onPressed, isNotNull);

    await service.applyCompressionResultForTesting(
      filePath: file.filePath,
      fileName: file.name,
      success: true,
      compressedFilePath: '/output/selected_compressed.jpg',
      compressedSize: 60,
    );
    await tester.pumpAndSettle();

    final removeButtonAfterUpdate = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '移除'),
    );
    expect(removeButtonAfterUpdate.onPressed, isNotNull);
  });

  testWidgets('output settings toggles update immediately', (tester) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return;
    }

    await tester.pumpWidget(const MaterialApp(home: ImageCompressScreen()));

    final outputToOriginalTile = find.widgetWithText(
      CheckboxListTile,
      '输出到原目录',
    );
    expect(outputToOriginalTile, findsOneWidget);
    expect(find.text('选择输出目录'), findsOneWidget);
    expect(find.text('未勾选输出到原目录时，需要先选择输出目录。'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, '覆盖原文件'), findsNothing);

    await tester.tap(outputToOriginalTile);
    await tester.pumpAndSettle();

    expect(find.text('选择输出目录'), findsNothing);
    expect(find.text('未勾选输出到原目录时，需要先选择输出目录。'), findsNothing);

    final outputEnabledTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '输出到原目录'),
    );
    expect(outputEnabledTile.value, isTrue);
    expect(find.widgetWithText(CheckboxListTile, '覆盖原文件'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '覆盖原文件'));
    await tester.pumpAndSettle();

    final overwriteTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '覆盖原文件'),
    );
    expect(overwriteTile.value, isTrue);

    await tester.tap(find.widgetWithText(CheckboxListTile, '输出到原目录'));
    await tester.pumpAndSettle();

    final outputDisabledTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '输出到原目录'),
    );
    expect(outputDisabledTile.value, isFalse);
    expect(find.widgetWithText(CheckboxListTile, '覆盖原文件'), findsNothing);
    expect(find.text('选择输出目录'), findsOneWidget);
    expect(find.text('未勾选输出到原目录时，需要先选择输出目录。'), findsOneWidget);
  });

  test(
    'failed compression still advances overall completion and finishes batch',
    () async {
      final service = ImageCompressService();
      addTearDown(service.dispose);

      final first = ImageFile(
        name: 'a.jpg',
        filePath: '/input/a.jpg',
        sizeInBytes: 100,
        width: 100,
        height: 100,
      );
      final second = ImageFile(
        name: 'b.jpg',
        filePath: '/input/b.jpg',
        sizeInBytes: 200,
        width: 200,
        height: 200,
      );

      service.replaceSelectedImagesForTesting([first, second]);

      await service.applyCompressionResultForTesting(
        filePath: first.filePath,
        fileName: first.name,
        success: false,
        errorMessage: 'boom',
      );

      expect(service.overallProgress, 0.5);
      expect(service.selectedImages[0].status, 'error');
      expect(service.selectedImages[0].errorMessage, 'boom');
      expect(service.isCompressing, isTrue);

      await service.applyCompressionResultForTesting(
        filePath: second.filePath,
        fileName: second.name,
        success: true,
        compressedFilePath: '/output/b_compressed.jpg',
        compressedSize: 120,
      );

      expect(service.overallProgress, 1.0);
      expect(service.isCompressing, isFalse);
      expect(service.statusMessage, contains('失败 1'));
    },
  );

  test(
    'desktop compression requires output directory when not writing to original directory',
    () async {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        return;
      }

      final service = ImageCompressService();
      addTearDown(service.dispose);

      service.replaceSelectedImagesForTesting([
        ImageFile(
          name: 'needs_output.jpg',
          filePath: '/input/needs_output.jpg',
          sizeInBytes: 100,
          width: 100,
          height: 100,
        ),
      ]);

      await service.startCompression(
        CompressionConfig(
          quality: 90,
          outputToOriginalDir: false,
          outputDirectory: null,
        ),
      );

      expect(service.isCompressing, isFalse);
      expect(service.statusMessage, contains('请先选择输出目录'));
    },
  );
}
