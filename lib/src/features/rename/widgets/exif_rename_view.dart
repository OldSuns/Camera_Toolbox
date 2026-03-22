import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../rename_provider.dart';

class ExifRenameView extends StatefulWidget {
  const ExifRenameView({super.key});

  @override
  State<ExifRenameView> createState() => _ExifRenameViewState();
}

class _ExifRenameViewState extends State<ExifRenameView> {
  final TextEditingController _controller = TextEditingController();
  late TextEditingController _prefixController;
  late TextEditingController _suffixController;
  late TextEditingController _startNumberController;
  late TextEditingController _fixedDigitsController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RenameProvider>();
    // 同步Provider中的模板到本地控制器
    _controller.text = provider.exifTemplate;
    _controller.addListener(() {
      // 当文本变化时，更新Provider中的模板
      context.read<RenameProvider>().setExifTemplate(_controller.text);
    });

    _prefixController = TextEditingController(text: provider.numberingPrefix);
    _suffixController = TextEditingController(text: provider.numberingSuffix);
    _startNumberController = TextEditingController(
      text: provider.startNumber.toString(),
    );
    _fixedDigitsController = TextEditingController(
      text: provider.fixedDigits.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _startNumberController.dispose();
    _fixedDigitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RenameProvider>();

    // 当Provider中的值变化时，同步更新TextEditingController
    if (_prefixController.text != provider.numberingPrefix) {
      _prefixController.text = provider.numberingPrefix;
    }
    if (_suffixController.text != provider.numberingSuffix) {
      _suffixController.text = provider.numberingSuffix;
    }
    if (_startNumberController.text != provider.startNumber.toString()) {
      _startNumberController.text = provider.startNumber.toString();
    }
    if (_fixedDigitsController.text != provider.fixedDigits.toString()) {
      _fixedDigitsController.text = provider.fixedDigits.toString();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 命名模板输入框
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '命名模板',
                hintText: '例如：IMG_[年月日]_[序号]',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 可用的EXIF标签
            Text('可用标签', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: exifTags.entries.map((entry) {
                return ActionChip(
                  label: Text(entry.key),
                  onPressed: () {
                    _insertTag(entry.value);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text('自动序号设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildAutoNumberingControls(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoNumberingControls(RenameProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // 窄屏使用Wrap布局
          return _buildNarrowLayout(provider);
        } else {
          // 宽屏使用Row/Column布局
          return _buildWideLayout(provider);
        }
      },
    );
  }

  Widget _buildWideLayout(RenameProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _prefixController,
                decoration: const InputDecoration(
                  labelText: '前置字符',
                  border: OutlineInputBorder(),
                ),
                onChanged: provider.setNumberingPrefix,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _suffixController,
                decoration: const InputDecoration(
                  labelText: '后置字符',
                  border: OutlineInputBorder(),
                ),
                onChanged: provider.setNumberingSuffix,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '开始序号',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    provider.setStartNumber(int.tryParse(value) ?? 1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _fixedDigitsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '固定位数',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    provider.setFixedDigits(int.tryParse(value) ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<NumberingType>(
          initialValue: provider.numberingType,
          decoration: const InputDecoration(
            labelText: '序号类型',
            border: OutlineInputBorder(),
          ),
          items: NumberingType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              provider.setNumberingType(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(RenameProvider provider) {
    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      children: [
        TextField(
          controller: _prefixController,
          decoration: const InputDecoration(
            labelText: '前置字符',
            border: OutlineInputBorder(),
          ),
          onChanged: provider.setNumberingPrefix,
        ),
        TextField(
          controller: _suffixController,
          decoration: const InputDecoration(
            labelText: '后置字符',
            border: OutlineInputBorder(),
          ),
          onChanged: provider.setNumberingSuffix,
        ),
        TextField(
          controller: _startNumberController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '开始序号',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              provider.setStartNumber(int.tryParse(value) ?? 1),
        ),
        TextField(
          controller: _fixedDigitsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '固定位数',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) =>
              provider.setFixedDigits(int.tryParse(value) ?? 0),
        ),
        DropdownButtonFormField<NumberingType>(
          initialValue: provider.numberingType,
          decoration: const InputDecoration(
            labelText: '序号类型',
            border: OutlineInputBorder(),
          ),
          items: NumberingType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              provider.setNumberingType(value);
            }
          },
        ),
      ],
    );
  }

  void _insertTag(String tag) {
    final selection = _controller.selection;
    if (selection.isValid) {
      final newText = _controller.text.replaceRange(
        selection.start,
        selection.end,
        tag,
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: selection.start + tag.length),
        ),
      );
    } else {
      // 如果没有有效的选区（例如输入框未聚焦），则在末尾追加
      final newText = _controller.text + tag;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        ),
      );
    }
  }
}

// 定义所有可用的EXIF标签及其占位符
// 注意：这里的key必须与ExifTranslator翻译后的key完全一致
const Map<String, String> exifTags = {
  '序号': '[序号]',
  '_': '_',
  '相机制造商': '[相机制造商]',
  '相机型号': '[相机型号]',
  '光圈值': '[光圈值]',
  '快门速度': '[快门速度]',
  '焦距': '[焦距]',
  'ISO感光度': '[ISO感光度]',
  '年': '[年]',
  '月': '[月]',
  '日': '[日]',
  '时': '[时]',
  '分': '[分]',
  '秒': '[秒]',
  '年月日': '[年月日]',
  '时分秒': '[时分秒]',
};
