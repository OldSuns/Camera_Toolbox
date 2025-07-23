import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../rename_provider.dart';

class ReplaceRenameView extends StatefulWidget {
  const ReplaceRenameView({super.key});

  @override
  State<ReplaceRenameView> createState() => _ReplaceRenameViewState();
}

class _ReplaceRenameViewState extends State<ReplaceRenameView> {
  // 用于保存每个规则的TextEditingController
  final List<TextEditingController> _findControllers = [];
  final List<TextEditingController> _replaceControllers = [];

  @override
  void dispose() {
    // 释放所有controller
    for (var controller in _findControllers) {
      controller.dispose();
    }
    for (var controller in _replaceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RenameProvider>(
      builder: (context, provider, child) {
        // 确保controller数量与规则数量一致
        while (_findControllers.length > provider.replaceRules.length) {
          _findControllers.removeLast().dispose();
        }
        while (_replaceControllers.length > provider.replaceRules.length) {
          _replaceControllers.removeLast().dispose();
        }
        while (_findControllers.length < provider.replaceRules.length) {
          _findControllers.add(TextEditingController());
        }
        while (_replaceControllers.length < provider.replaceRules.length) {
          _replaceControllers.add(TextEditingController());
        }

        // 更新controller的文本（仅当文本不同时才更新）
        for (int i = 0; i < provider.replaceRules.length; i++) {
          if (_findControllers[i].text != provider.replaceRules[i].findText) {
            _findControllers[i].text = provider.replaceRules[i].findText;
          }
          if (_replaceControllers[i].text !=
              provider.replaceRules[i].replaceText) {
            _replaceControllers[i].text = provider.replaceRules[i].replaceText;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '替换',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // 动态规则列表
                ...List.generate(provider.replaceRules.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _findControllers[index],
                            decoration: const InputDecoration(
                              labelText: '查找',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              provider.updateFindText(index, value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _replaceControllers[index],
                            decoration: const InputDecoration(
                              labelText: '替换为',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              provider.updateReplaceText(index, value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 删除按钮
                        if (provider.replaceRules.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              // 在删除前先释放对应的controller
                              if (index < _findControllers.length) {
                                _findControllers.removeAt(index).dispose();
                              }
                              if (index < _replaceControllers.length) {
                                _replaceControllers.removeAt(index).dispose();
                              }
                              provider.removeReplaceRule(index);
                            },
                          ),
                      ],
                    ),
                  );
                }),
                // 添加规则按钮
                ElevatedButton.icon(
                  onPressed: () {
                    provider.addReplaceRule();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加一个规则'),
                ),
                const SizedBox(height: 16),
                // 允许替换文件扩展名复选框
                CheckboxListTile(
                  title: const Text('允许替换文件扩展名'),
                  value: provider.replaceRules.isNotEmpty
                      ? provider.replaceRules.last.allowReplaceExtension
                      : false,
                  onChanged: provider.replaceRules.isNotEmpty
                      ? (value) {
                          if (value != null) {
                            provider.updateAllowReplaceExtension(
                              provider.replaceRules.length - 1,
                              value,
                            );
                          }
                        }
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
