# 决策日志
记录架构和实现决策。

---
### 决策 (2025-07-21T16:37:14Z)
**决策:** 优化跨平台字体以提升原生体验。
**理由:** 不同操作系统的默认字体渲染效果最佳。为了在 Windows 上获得更好的中文显示效果，同时保持其他平台的原生观感，决定进行平台特定的字体配置。
**实施:**
- **Windows:** 明确指定使用 "Microsoft YaHei" 字体。
- **其他平台 (macOS, Linux, Android, iOS):** 不指定 `fontFamily`，以使用各自的系统默认字体。
**执行者:** `code-developer`
**状态:** 已完成
---
### 决策 (2025-07-22T07:09:57Z)
**决策:** 使用 `IndexedStack` 和 `AutomaticKeepAliveClientMixin` 解决页面状态丢失问题。
**理由:** 在调整窗口大小或切换导航时，页面会重新构建，导致状态丢失。`IndexedStack` 可以保持所有子 Widget 的状态，而 `AutomaticKeepAliveClientMixin` 则能防止 State 被销毁。
**实施:**
- 在 `lib/src/features/home/home_screen.dart` 中，使用 `IndexedStack` 替换直接的页面索引访问。
- 为 `_HomeScreenState` 添加 `AutomaticKeepAliveClientMixin`。
- 重构 `lib/src/shared/widgets/adaptive_navigation.dart` 以在所有布局中使用单一 `Scaffold`，确保 `IndexedStack` 不会因布局变化而重建。
**执行者:** `code-developer`
**状态:** 已完成
