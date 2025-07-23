import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../rename_provider.dart';

class AppendRenameView extends StatefulWidget {
  const AppendRenameView({super.key});

  @override
  State<AppendRenameView> createState() => _AppendRenameViewState();
}

class _AppendRenameViewState extends State<AppendRenameView> {
  late TextEditingController _prefixController;
  late TextEditingController _suffixController;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController();
    _suffixController = TextEditingController();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RenameProvider>(
      builder: (context, provider, child) {
        // 更新controller的文本（仅当文本不同时才更新）
        if (_prefixController.text != provider.appendPrefix) {
          _prefixController.text = provider.appendPrefix;
        }
        if (_suffixController.text != provider.appendSuffix) {
          _suffixController.text = provider.appendSuffix;
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '追加',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _prefixController,
                  decoration: const InputDecoration(
                    labelText: '前缀',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    provider.setAppendPrefix(value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _suffixController,
                  decoration: const InputDecoration(
                    labelText: '后缀',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    provider.setAppendSuffix(value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('追加模式'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('在文件名后追加'),
                  value: provider.appendAfterFilename,
                  onChanged: (value) {
                    if (value != null) {
                      provider.setAppendAfterFilename(value);
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
