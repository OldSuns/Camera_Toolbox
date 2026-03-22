# Flutter SDK 升级兼容记录

## 当前仓库基线
- Dart SDK 约束：`^3.8.1`
- Android Gradle Plugin：`8.7.3`
- Kotlin：`2.1.0`
- Gradle Wrapper：`8.12`
- Android NDK：`27.0.12077973`

## 当前直接依赖基线
- `desktop_drop`: `0.6.1`
- `device_info_plus`: `11.5.0`
- `file_picker`: `10.2.0`
- `gal`: `2.3.2`
- `permission_handler`: `12.0.1`
- `simple_native_image_compress`: `3.0.2`
- `url_launcher`: `6.3.2`
- `window_manager`: `0.5.1`

## 已确认的升级建议
- `desktop_drop` 可升级到 `0.7.0`
  - 目的：减少旧版 Android 构建脚本带来的兼容噪声。
- `file_picker` 可升级到 `10.3.10`
  - 目的：跟进新版 Flutter/Android 构建链兼容修复。

## 暂不升级的依赖
- `device_info_plus`
  - 新版 `12.3.0` 要求：
    - Flutter `>= 3.29.0`
    - AGP `>= 8.12.1`
    - Gradle `>= 8.13`
    - Kotlin `2.2.0`
  - 当前仓库 Android 工具链未同步到该要求，直接升级风险较高。

## Android 构建链排查规则
1. 先运行本地构建并生成 `problems-report.html`。
2. 若告警来自当前仓库直接依赖，优先升级依赖版本。
3. 若告警仅来自三方插件内部 Gradle/Groovy DSL，且当前版本已是可接受上限，则记录为外部风险，不修改 pub cache。
4. 只有当多个核心插件要求更高 AGP/Gradle/Kotlin 时，才整体升级 Android 工具链。

## 推荐本地验证命令
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

## 观察重点
- Windows：启动、切页、窗口缩放时是否还有 AXTree 报错或闪退。
- Android：`build/reports/problems/problems-report.html` 中是否仍有 direct dependency 级别的构建告警。
