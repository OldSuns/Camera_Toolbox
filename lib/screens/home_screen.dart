import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/navigation/adaptive_navigation.dart';
import '../providers/navigation_provider.dart';
import 'exif_reader/exif_reader_screen.dart';
import 'quick_split/quick_split_screen.dart';
import 'settings/settings_screen.dart';
import 'about/about_screen.dart';

/// 主页面框架
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _pages = [
    const ExifReaderScreen(),
    const QuickSplitScreen(),
    const SettingsScreen(),
    const AboutScreen(),
  ];

  final List<String> _pageTitles = ['EXIF读取', '快速分片', '设置', 'OldSun相机工具箱'];

  void _onDestinationSelected(int index) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.setTitle(_pageTitles[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        return AdaptiveNavigation(
          currentIndex: navigationProvider.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          child: _pages[navigationProvider.currentIndex],
        );
      },
    );
  }
}
