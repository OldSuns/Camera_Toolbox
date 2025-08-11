import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cache_config.dart';
import '../services/cache_management_service.dart';
import '../../local_picker/local_picker_provider.dart';

/// 缓存管理设置组件
class CacheManagementWidget extends StatefulWidget {
  const CacheManagementWidget({super.key});

  @override
  State<CacheManagementWidget> createState() => _CacheManagementWidgetState();
}

class _CacheManagementWidgetState extends State<CacheManagementWidget> {
  final CacheManagementService _cacheService = CacheManagementService();
  CacheConfig _config = CacheConfig.defaultConfig();
  CacheStats? _stats;
  bool _isLoading = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _cacheService.initialize();
      _config = _cacheService.config;
      await _refreshStats();
    } catch (e) {
      _showErrorSnackBar('加载缓存信息失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConfig(CacheConfig newConfig) async {
    try {
      await _cacheService.updateConfig(newConfig);
      setState(() => _config = newConfig);
      _showSuccessSnackBar('设置已保存');
    } catch (e) {
      _showErrorSnackBar('保存设置失败: $e');
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await _showConfirmDialog('清理缓存', '确定要清理所有缓存吗？此操作无法撤销。');

    if (!confirmed) return;

    setState(() => _isClearing = true);
    try {
      final success = await _cacheService.clearCache();
      if (success) {
        _showSuccessSnackBar('缓存清理完成');
        await _refreshStats();
      } else {
        _showErrorSnackBar('缓存清理失败');
      }
    } catch (e) {
      _showErrorSnackBar('清理缓存时出错: $e');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _refreshStats() async {
    try {
      // 尝试获取 LocalPickerProvider 的缓存统计
      Map<String, dynamic>? localPickerStats;
      try {
        final localPickerProvider = context.read<LocalPickerProvider>();
        localPickerStats = localPickerProvider.getCacheStats();
      } catch (e) {
        // 如果获取失败，使用空统计
        debugPrint('Failed to get LocalPickerProvider stats: $e');
        localPickerStats = null;
      }

      final stats = await _cacheService.getCacheStats(localPickerStats);
      setState(() => _stats = stats);
    } catch (e) {
      _showErrorSnackBar('刷新统计信息失败: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 1000;

        if (isWideScreen) {
          return _buildWideScreenLayout();
        } else {
          return _buildNormalLayout();
        }
      },
    );
  }

  Widget _buildWideScreenLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：统计信息和手动操作
        Expanded(
          flex: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        '缓存统计',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _refreshStats,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新统计',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  _buildManualClearSection(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 右侧：自动清理策略和限制设置
        Expanded(
          flex: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '缓存设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAutoClearStrategySection(),
                  const SizedBox(height: 16),
                  if (_config.autoClearStrategy ==
                          CacheAutoClearStrategy.fileCountBased ||
                      _config.autoClearStrategy ==
                          CacheAutoClearStrategy.sizeBased)
                    _buildLimitSettings(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalLayout() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '缓存管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshStats,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新统计',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 缓存统计信息
            _buildStatsSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 自动清理策略
            _buildAutoClearStrategySection(),
            const SizedBox(height: 16),

            // 清理限制设置
            if (_config.autoClearStrategy ==
                    CacheAutoClearStrategy.fileCountBased ||
                _config.autoClearStrategy == CacheAutoClearStrategy.sizeBased)
              _buildLimitSettings(),

            const SizedBox(height: 16),

            // 手动清理按钮
            _buildManualClearSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) {
      return const Text('统计信息加载中...');
    }

    final recommendation = _cacheService.getCacheUsageRecommendation(_stats!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '缓存统计',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildStatRow('磁盘缓存文件', '${_stats!.totalFiles} 个'),
              _buildStatRow('磁盘缓存大小', '${_stats!.totalSizeMB} MB'),
              _buildStatRow('内存缓存', '${_stats!.memoryCacheSize} 个'),
              _buildStatRow(
                '缓存命中率',
                '${(_stats!.hitRate * 100).toStringAsFixed(1)}%',
              ),
              if (_stats!.lastCleanTime != null)
                _buildStatRow('上次清理', _formatDateTime(_stats!.lastCleanTime!)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getRecommendationColor(recommendation),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getRecommendationIcon(recommendation),
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoClearStrategySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '自动清理策略',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...CacheAutoClearStrategy.values.map(
          (strategy) => RadioListTile<CacheAutoClearStrategy>(
            title: Text(strategy.title),
            subtitle: Text(
              strategy.description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            value: strategy,
            groupValue: _config.autoClearStrategy,
            onChanged: (value) {
              if (value != null) {
                final newConfig = _config.copyWith(autoClearStrategy: value);
                _updateConfig(newConfig);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLimitSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '清理限制设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        if (_config.autoClearStrategy == CacheAutoClearStrategy.fileCountBased)
          _buildSliderSetting(
            '最大文件数量',
            _config.maxFileCount.toDouble(),
            50,
            1000,
            (value) {
              final newConfig = _config.copyWith(maxFileCount: value.round());
              _updateConfig(newConfig);
            },
            '${_config.maxFileCount} 个',
          ),

        if (_config.autoClearStrategy == CacheAutoClearStrategy.sizeBased)
          _buildSliderSetting('最大缓存大小', _config.maxSizeMB.toDouble(), 10, 500, (
            value,
          ) {
            final newConfig = _config.copyWith(maxSizeMB: value.round());
            _updateConfig(newConfig);
          }, '${_config.maxSizeMB} MB'),
      ],
    );
  }

  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String displayValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 10).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildManualClearSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '手动操作',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isClearing ? null : _clearCache,
            icon: _isClearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep),
            label: Text(_isClearing ? '清理中...' : '清理缓存'),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }

  Color _getRecommendationColor(String recommendation) {
    if (recommendation.contains('建议清理') ||
        recommendation.contains('较大') ||
        recommendation.contains('较多')) {
      return Colors.orange;
    } else if (recommendation.contains('较低')) {
      return Colors.amber;
    } else {
      return Colors.green;
    }
  }

  IconData _getRecommendationIcon(String recommendation) {
    if (recommendation.contains('建议清理') ||
        recommendation.contains('较大') ||
        recommendation.contains('较多')) {
      return Icons.warning;
    } else if (recommendation.contains('较低') ||
        recommendation.contains('未使用')) {
      return Icons.info;
    } else {
      return Icons.check_circle;
    }
  }
}
