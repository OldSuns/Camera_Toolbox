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
**状态:** 已完成---### 决策 (2025-07-21T16:44:40Z)
**决策:** 在 `quick_split_service.dart` 的 `_handleFileConflict` 方法中，执行任何文件系统操作（如 `file.exists()`）之前，必须先确保目标文件的父目录存在。
**理由:** `error-debugger` 的分析指出，当目标文件的父目录不存在时，`file.exists()` 会触发 `PathNotFoundException`。为了防止此错误，需要在操作前递归创建目录。
**执行者:** `code-developer`
**状态:** 待执行
