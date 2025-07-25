# OldSun相机工具箱

<img width="1472" height="986" alt="image" src="https://github.com/user-attachments/assets/e21f47bc-435e-4326-bfdd-9ba6b0a3f2f4" />

## 项目概述

**OldSun相机工具箱** 是一款专为摄影爱好者和专业摄影师设计的跨平台桌面应用，提供图片管理、EXIF信息读取、RAW文件分片等功能。

### 核心功能模块

#### 1. 本地选片 (Local Picker)
- **功能描述**: 从本地文件夹批量选择、预览和管理图片
- **核心特性**:
  - 支持JPG、PNG、HEIC等常见格式
  - 缩略图生成与缓存
  - 批量选择与导出
  - 键盘快捷键支持 (F键选择，方向键导航)
  - RAW文件关联检测
- **技术亮点**:
  - 使用Isolate进行缩略图生成，避免UI卡顿
  - 响应式网格布局，支持缩略图大小调节
  - 大图查看器支持缩放和平移

#### 2. EXIF信息读取器 (Exif Reader)
- **功能描述**: 读取并展示图片的详细EXIF元数据
- **核心特性**:
  - 支持多种图片格式包括RAW文件
  - 中文标签翻译
  - 缩略图提取
  - GPS坐标解析
  - 一键分享EXIF信息
- **技术亮点**:
  - 使用Isolate处理大文件，避免主线程阻塞
  - 智能缩略图提取算法
  - 错误处理和降级显示

#### 3. 快速分片 (Quick Split)
- **功能描述**: 根据JPG文件自动匹配并拷贝同名RAW文件
- **核心特性**:
  - 支持多种RAW格式 (CR2, CR3, NEF, ARW, DNG等)
  - 文件名精确匹配
  - 冲突处理策略 (跳过、重命名、覆盖)
  - 批量处理进度显示
- **技术亮点**:
  - 使用Isolate进行文件操作，避免UI冻结
  - 智能文件冲突检测和处理
  - 跨平台权限管理

#### 4. 批量重命名 (Batch Rename)
- **功能描述**: 提供多种策略批量修改文件名
- **核心特性**:
  - **替换**: 查找并替换文件名中的特定字符。
  - **追加**: 在文件名前、后或指定位置添加字符。
  - **自动序号**: 按指定格式（前缀、后缀、起始号、位数）生成递增序号。
  - **EXIF命名**: 使用照片的EXIF信息（如拍摄日期、相机型号）命名。
  - **实时预览**: 在执行前显示命名效果。
  - **灵活排序**: 支持按名称、时间等多种方式对文件排序。

#### 5. 主题系统
- **功能描述**: 支持浅色/深色/系统主题切换
- **核心特性**:
  - Material 3设计风格
  - 自定义主题色
  - 跨平台字体适配
  - 主题配置持久化

## 技术栈

- **框架**: Flutter 3.8.1+
- **语言**: Dart
- **状态管理**: Provider + ChangeNotifier
- **UI框架**: Material 3
- **平台支持**: Windows, macOS, Linux, Android, iOS, Web

## 核心依赖

- `exif_reader`: EXIF信息读取
- `image`: 图片处理
- `file_picker`: 文件选择
- `window_manager`: 桌面窗口管理
- `shared_preferences`: 本地存储
- `provider`: 状态管理

## 安装和运行

### 环境要求

- Flutter 3.8.1+
- Dart 2.19+
- 支持的平台: Windows, macOS, Linux, Android, iOS, Web

### 安装步骤

1. 克隆项目代码:
   ```bash
   git clone <repository-url>
   cd camera_toolbox
   ```

2. 安装依赖:
   ```bash
   flutter pub get
   ```

3. 运行应用:
   ```bash
   flutter run
   ```

### 构建发布版本

- **Windows**:
  ```bash
  flutter build windows
  ```

- **macOS**:
  ```bash
  flutter build macos
  ```

- **Linux**:
  ```bash
  flutter build linux
  ```

- **Android**:
  ```bash
  flutter build apk
  ```

- **iOS**:
  ```bash
  flutter build ios
  ```

- **Web**:
  ```bash
  flutter build web
  ```


## 目标用户

- **摄影爱好者**: 需要管理大量照片，查看拍摄参数
- **专业摄影师**: 需要批量处理RAW文件，管理拍摄项目
- **摄影学习者**: 学习不同拍摄参数的效果

## 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进项目。
