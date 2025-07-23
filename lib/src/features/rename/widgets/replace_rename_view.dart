import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../rename_provider.dart';

class ReplaceRenameView extends StatefulWidget {
  const ReplaceRenameView({super.key});

  @override
  State<ReplaceRenameView> createState() => _ReplaceRenameViewState();
}

class _ReplaceRenameViewState extends State<ReplaceRenameView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RenameProvider>(
      builder: (context, provider, child) {
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.replaceRules.length,
                  itemBuilder: (context, index) {
                    final rule = provider.replaceRules[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              key: ValueKey('find_$index'),
                              initialValue: rule.findText,
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
                            child: TextFormField(
                              key: ValueKey('replace_$index'),
                              initialValue: rule.replaceText,
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
                                provider.removeReplaceRule(index);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
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
                if (provider.replaceRules.isNotEmpty)
                  CheckboxListTile(
                    title: const Text('允许替换文件扩展名'),
                    value: provider.replaceRules.last.allowReplaceExtension,
                    onChanged: (value) {
                      if (value != null) {
                        provider.updateAllowReplaceExtension(
                          provider.replaceRules.length - 1,
                          value,
                        );
                      }
                    },
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
