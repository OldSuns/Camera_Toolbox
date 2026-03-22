import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../rename_provider.dart';

class AppendRenameView extends StatefulWidget {
  const AppendRenameView({super.key});

  @override
  State<AppendRenameView> createState() => _AppendRenameViewState();
}

class _AppendRenameViewState extends State<AppendRenameView> {
  late final TextEditingController _prefixController;
  late final TextEditingController _suffixController;

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
      builder: (context, provider, _) {
        if (_prefixController.text != provider.appendPrefix) {
          _prefixController.text = provider.appendPrefix;
        }
        if (_suffixController.text != provider.appendSuffix) {
          _suffixController.text = provider.appendSuffix;
        }

        return Padding(
          padding: const EdgeInsets.all(16),
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
                  onChanged: provider.setAppendPrefix,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _suffixController,
                  decoration: const InputDecoration(
                    labelText: '后缀',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setAppendSuffix,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AppendMode>(
                  initialValue: provider.appendMode,
                  decoration: const InputDecoration(
                    labelText: '追加位置',
                    border: OutlineInputBorder(),
                  ),
                  items: AppendMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.setAppendMode(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  provider.appendMode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
