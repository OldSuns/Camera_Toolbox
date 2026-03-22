import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../shared/widgets/adaptive_navigation.dart';
import '../../shared/providers/navigation_provider.dart';
import '../exif_reader/exif_reader_screen.dart';
import '../local_picker/local_picker_screen.dart';
import '../quick_split/quick_split_screen.dart';
import '../settings/settings_screen.dart';
import '../about/about_screen.dart';
import '../rename/rename_screen.dart';
import '../photo_watermark/photo_watermark_screen.dart';
import '../image_compress/image_compress_screen.dart';

/// 主页面框架
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<int, Widget> _pageCache = {};
  final Set<int> _visitedPages = {0};

  void _onDestinationSelected(int index) {
    _visitedPages.add(index);
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 从 AppPage 枚举动态获取标题，确保一致性
      windowManager.setTitle('相机工具箱 - ${AppPage.values[index].title}');
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const ExifReaderScreen();
      case 1:
        return const LocalPickerScreen();
      case 2:
        return const QuickSplitScreen();
      case 3:
        return const RenameScreen();
      case 4:
        return const PhotoWatermarkScreen();
      case 5:
        return const ImageCompressScreen();
      case 6:
        return const SettingsScreen();
      case 7:
        return const AboutScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pageForIndex(int index) {
    return _pageCache.putIfAbsent(index, () => _buildPage(index));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        return AdaptiveNavigation(
          currentIndex: navigationProvider.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          child: Stack(
            children: List.generate(AppPage.values.length, (index) {
              if (!_visitedPages.contains(index)) {
                return const SizedBox.shrink();
              }

              final isCurrent = navigationProvider.currentIndex == index;
              return Visibility(
                visible: isCurrent,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: false,
                maintainSemantics: false,
                maintainInteractivity: false,
                child: TickerMode(
                  enabled: isCurrent,
                  child: _pageForIndex(index),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
