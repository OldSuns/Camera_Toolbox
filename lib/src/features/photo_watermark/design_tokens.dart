import 'package:flutter/material.dart';

/// 设计令牌系统 - 定义统一的设计规范
class DesignTokens {
  // 防止实例化
  DesignTokens._();

  // ===== 间距系统 =====
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // ===== 圆角系统 =====
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusRound = 24.0;

  // ===== 阴影系统 =====
  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get shadowXLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  // ===== 布局尺寸 =====
  static const double sidebarWidth = 360.0;
  static const double rightPanelWidth = 400.0;
  static const double minWindowWidth = 1200.0;
  static const double minWindowHeight = 800.0;

  // 组件高度
  static const double buttonHeight = 48.0;
  static const double inputHeight = 40.0;
  static const double toolbarHeight = 56.0;

  // ===== 动画时长 =====
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ===== 颜色系统 =====
  static const Color backgroundPrimary = Color(0xFFF5F5F5);
  static const Color backgroundSecondary = Colors.white;
  static const Color backgroundTertiary = Color(0xFFFAFAFA);

  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color borderColorLight = Color(0xFFF0F0F0);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);

  // 棋盘背景颜色
  static const Color checkerboardLight = Color(0xFFF5F5F5);
  static const Color checkerboardDark = Color(0xFFE0E0E0);

  // ===== 文字样式 =====
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ===== 装饰器 =====
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: backgroundSecondary,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: shadowSmall,
  );

  static BoxDecoration get sectionDecoration => BoxDecoration(
    color: backgroundSecondary,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: borderColorLight),
  );

  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacing12,
        vertical: spacing8,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ===== 按钮样式 =====
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: spacing16),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    side: const BorderSide(color: borderColor),
    padding: const EdgeInsets.symmetric(horizontal: spacing16),
  );

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    padding: const EdgeInsets.symmetric(horizontal: spacing16),
  );

  // ===== 工具方法 =====
  /// 创建带有过渡动画的容器
  static Widget animatedContainer({
    required Widget child,
    Duration? duration,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BoxDecoration? decoration,
    double? width,
    double? height,
    AlignmentGeometry? alignment,
  }) {
    return AnimatedContainer(
      duration: duration ?? animationNormal,
      padding: padding,
      margin: margin,
      decoration: decoration,
      width: width,
      height: height,
      alignment: alignment,
      curve: Curves.easeInOut,
      child: child,
    );
  }

  /// 创建分隔线
  static Widget divider({
    double? height,
    double? thickness,
    Color? color,
    double? indent,
    double? endIndent,
  }) {
    return Divider(
      height: height ?? 1,
      thickness: thickness ?? 1,
      color: color ?? borderColorLight,
      indent: indent,
      endIndent: endIndent,
    );
  }

  /// 创建垂直分隔线
  static Widget verticalDivider({
    double? width,
    double? thickness,
    Color? color,
    double? indent,
    double? endIndent,
  }) {
    return VerticalDivider(
      width: width ?? 1,
      thickness: thickness ?? 1,
      color: color ?? borderColorLight,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
