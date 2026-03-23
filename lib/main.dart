import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'src/shared/providers/theme_provider.dart';
import 'src/shared/providers/navigation_provider.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/local_picker/local_picker_provider.dart';
import 'src/features/rename/rename_provider.dart';
import 'src/features/photo_watermark/photo_watermark_provider.dart';
import 'src/features/settings/services/cache_management_service.dart';

const _desktopWindowOptions = WindowOptions(
  size: Size(1200, 800),
  center: true,
  skipTaskbar: false,
  titleBarStyle: TitleBarStyle.normal,
);

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

String? _platformFontFamily() {
  if (Platform.isWindows) {
    return 'Microsoft YaHei';
  }
  return null;
}

/// 应用程序的主入口点。
void main() async {
  // 确保Flutter绑定已初始化，这是调用平台通道所必需的。
  WidgetsFlutterBinding.ensureInitialized();

  // 如果是桌面平台（Windows、macOS、Linux），则初始化窗口管理器。
  if (_isDesktopPlatform) {
    await windowManager.ensureInitialized();

    // 等待窗口准备好后显示并获取焦点。
    windowManager.waitUntilReadyToShow(_desktopWindowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 初始化主题提供者，并加载用户的主题偏好。
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // 在后台启动缓存清理检查，不阻塞UI线程
  final cacheService = CacheManagementService();
  await cacheService.initialize();

  // 使用MultiProvider启动应用程序，以便在小部件树中提供各种服务。
  runApp(
    MultiProvider(
      providers: [
        // 提供ThemeProvider以管理应用主题。
        ChangeNotifierProvider(create: (_) => themeProvider),
        // 提供NavigationProvider以管理导航状态。
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        // 提供LocalPickerProvider以管理本地选片功能
        ChangeNotifierProvider(create: (_) => LocalPickerProvider()),
        // 提供RenameProvider以管理重命名功能
        ChangeNotifierProvider(create: (_) => RenameProvider()),
        // 提供PhotoWatermarkProvider以管理照片水印功能
        ChangeNotifierProvider(create: (_) => PhotoWatermarkProvider()),
      ],
      child: const CameraToolboxApp(),
    ),
  );
}

/// 应用程序的根小部件。
class CameraToolboxApp extends StatelessWidget {
  const CameraToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fontFamily = _platformFontFamily();

    // 使用Consumer来监听ThemeProvider的变化，并根据其状态构建UI。
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // 如果主题正在加载中，显示一个加载指示器。
        if (themeProvider.isLoading) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // 主题加载完成后，构建MaterialApp。
        return MaterialApp(
          title: '相机工具箱',
          debugShowCheckedModeBanner: false, // 隐藏调试横幅
          builder: (context, child) {
            final appChild = child ?? const SizedBox.shrink();
            if (Platform.isWindows) {
              return ExcludeSemantics(child: appChild);
            }
            return appChild;
          },
          theme: themeProvider.lightTheme.copyWith(
            textTheme: themeProvider.lightTheme.textTheme.apply(
              fontFamily: fontFamily,
            ),
          ), // 设置浅色主题
          darkTheme: themeProvider.darkTheme.copyWith(
            textTheme: themeProvider.darkTheme.textTheme.apply(
              fontFamily: fontFamily,
            ),
          ), // 设置深色主题
          themeMode: themeProvider.themeMode, // 根据提供者设置主题模式
          home: const HomeScreen(), // 设置主屏幕
        );
      },
    );
  }
}
