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
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '替换',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.replaceRules.length,
                  itemBuilder: (context, index) {
                    final rule = provider.replaceRules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '规则 ${index + 1}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                if (provider.replaceRules.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        provider.removeReplaceRule(index),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey('find_$index'),
                              initialValue: rule.findText,
                              decoration: const InputDecoration(
                                labelText: '查找',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) =>
                                  provider.updateFindText(index, value),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: ValueKey('replace_$index'),
                              initialValue: rule.replaceText,
                              decoration: const InputDecoration(
                                labelText: '替换为',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) =>
                                  provider.updateReplaceText(index, value),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('允许替换文件扩展名'),
                              value: rule.allowReplaceExtension,
                              onChanged: (value) {
                                if (value != null) {
                                  provider.updateAllowReplaceExtension(
                                    index,
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
                ),
                ElevatedButton.icon(
                  onPressed: provider.addReplaceRule,
                  icon: const Icon(Icons.add),
                  label: const Text('添加一个规则'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
