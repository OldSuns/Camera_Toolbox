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
import '../camera_database/camera_database_screen.dart';

/// 主页面框架
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final List<Widget> _pages = [
    const ExifReaderScreen(),
    const LocalPickerScreen(),
    const QuickSplitScreen(),
    const RenameScreen(),
    const PhotoWatermarkScreen(),
    const CameraDatabaseScreen(),
    const SettingsScreen(),
    const AboutScreen(),
  ];

  void _onDestinationSelected(int index) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 从 AppPage 枚举动态获取标题，确保一致性
      windowManager.setTitle('OldSun相机工具箱 - ${AppPage.values[index].title}');
    }
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
          child: IndexedStack(
            index: navigationProvider.currentIndex,
            children: _pages,
          ),
        );
      },
    );
  }
}
