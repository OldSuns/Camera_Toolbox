import 'package:flutter/material.dart';

/// 响应式布局组件
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget tabletLayout;
  final Widget desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    required this.tabletLayout,
    required this.desktopLayout,
  });

  /// 判断是否为移动端
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  /// 判断是否为平板
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  /// 判断是否为桌面
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktopLayout;
        } else if (constraints.maxWidth >= 600) {
          return tabletLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}
