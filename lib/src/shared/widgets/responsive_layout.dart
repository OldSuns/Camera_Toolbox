import 'package:flutter/material.dart';

enum AppLayoutMode { mobile, tablet, desktop }

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

  static AppLayoutMode resolveMode(double width) {
    if (width >= 1200) {
      return AppLayoutMode.desktop;
    }
    if (width >= 600) {
      return AppLayoutMode.tablet;
    }
    return AppLayoutMode.mobile;
  }

  /// 判断是否为移动端
  static bool isMobile(BuildContext context) =>
      resolveMode(MediaQuery.sizeOf(context).width) == AppLayoutMode.mobile;

  /// 判断是否为平板
  static bool isTablet(BuildContext context) =>
      resolveMode(MediaQuery.sizeOf(context).width) == AppLayoutMode.tablet;

  /// 判断是否为桌面
  static bool isDesktop(BuildContext context) =>
      resolveMode(MediaQuery.sizeOf(context).width) == AppLayoutMode.desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (resolveMode(constraints.maxWidth)) {
          case AppLayoutMode.desktop:
            return desktopLayout;
          case AppLayoutMode.tablet:
            return tabletLayout;
          case AppLayoutMode.mobile:
            return mobileLayout;
        }
      },
    );
  }
}

class StableWidthBuilder<T extends Object> extends StatefulWidget {
  const StableWidthBuilder({
    super.key,
    required this.resolve,
    required this.builder,
    this.cacheKey,
  });

  final T Function(double width) resolve;
  final Widget Function(BuildContext context, T value) builder;
  final Object? cacheKey;

  @override
  State<StableWidthBuilder<T>> createState() => _StableWidthBuilderState<T>();
}

class _StableWidthBuilderState<T extends Object>
    extends State<StableWidthBuilder<T>> {
  T? _cachedValue;
  Object? _cachedKey;
  Widget? _cachedChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedValue = widget.resolve(constraints.maxWidth);
        final shouldRebuild =
            _cachedChild == null ||
            _cachedValue != resolvedValue ||
            _cachedKey != widget.cacheKey;

        if (shouldRebuild) {
          _cachedValue = resolvedValue;
          _cachedKey = widget.cacheKey;
          _cachedChild = widget.builder(context, resolvedValue);
        }

        return _cachedChild!;
      },
    );
  }
}
