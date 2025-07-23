import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../rename_provider.dart';

class AutoNumberingView extends StatefulWidget {
  const AutoNumberingView({super.key});

  @override
  State<AutoNumberingView> createState() => _AutoNumberingViewState();
}

class _AutoNumberingViewState extends State<AutoNumberingView> {
  late TextEditingController _prefixController;
  late TextEditingController _suffixController;
  late TextEditingController _startNumberController;
  late TextEditingController _fixedDigitsController;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController();
    _suffixController = TextEditingController();
    _startNumberController = TextEditingController();
    _fixedDigitsController = TextEditingController();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _suffixController.dispose();
    _startNumberController.dispose();
    _fixedDigitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RenameProvider>(
      builder: (context, provider, child) {
        // 更新controller的文本（仅当文本不同时才更新）
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 当屏幕宽度小于500时，使用Wrap布局
              if (constraints.maxWidth < 500) {
                return SingleChildScrollView(
                  child: _buildNarrowLayout(provider),
                );
              } else {
                // 否则，使用原始的Row + Expanded布局
                return _buildWideLayout(provider);
              }
            },
          ),
        );
      },
    );
  }

  /// 宽屏布局
  Widget _buildWideLayout(RenameProvider provider) {
    return Column(
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
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<NumberingType>(
                value: provider.numberingType,
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('保留文件名'),
                  Switch(
                    value: provider.keepOriginalName,
                    onChanged: provider.setKeepOriginalName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 窄屏布局
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
          controller: _suffixController,
          decoration: const InputDecoration(
            labelText: '后置字符',
            border: OutlineInputBorder(),
          ),
          onChanged: provider.setNumberingSuffix,
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
          value: provider.numberingType,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('保留文件名'),
            Switch(
              value: provider.keepOriginalName,
              onChanged: provider.setKeepOriginalName,
            ),
          ],
        ),
      ],
    );
  }
}
