# 系统模式

## 架构模式

### 1. 分层架构 (Layered Architecture)
```
┌─────────────────────────────────────┐
│           表示层 (UI Layer)          │
│  - Screens (页面)                   │
│  - Widgets (组件)                   │
│  - Dialogs (对话框)                 │
├─────────────────────────────────────┤
│         业务逻辑层 (Business Layer)  │
│  - Providers (状态管理)             │
│  - Services (业务服务)              │
│  - Models (数据模型)                │
├─────────────────────────────────────┤
│         数据访问层 (Data Layer)      │
│  - File I/O (文件操作)              │
│  - Shared Preferences (本地存储)    │
│  - Platform Channels (平台通道)     │
└─────────────────────────────────────┘
```

### 2. 状态管理模式
- **Provider + ChangeNotifier**: 轻量级状态管理
- **Scoped State**: 每个功能模块独立管理状态
- **Reactive Updates**: 自动UI更新机制

### 3. 并发处理模式

#### Isolate使用模式
```dart
// 模式1: 计算密集型任务
Future<ExifData> _parseExifDataInIsolate(String filePath) async {
  return await compute(_parseExifDataInIsolate, filePath);
}

// 模式2: 长时间运行任务
Isolate? _isolate;
SendPort? _sendPort;
final _receivePort = ReceivePort();
```

#### 异步处理模式
- **Future/await**: 标准异步操作
- **Stream**: 文件列表和进度更新
- **Completer**: 复杂异步流程控制

## 设计模式

### 1. 单例模式 (Singleton)
- `ThemeProvider`: 全局主题管理
- `NavigationProvider`: 全局导航状态

### 2. 工厂模式 (Factory)
- `ThemeConfig.defaultConfig()`: 默认配置创建
- `ExifData.empty()`: 空数据对象创建

### 3. 策略模式 (Strategy)
- `ConflictAction`: 文件冲突处理策略
- `AppThemeMode`: 主题模式策略

### 4. 观察者模式 (Observer)
- `ChangeNotifier`: 状态变化通知
- `Consumer`: UI响应式更新

## 数据流模式

### 1. 单向数据流
```
User Action → Provider → Service → Data → Provider → UI Update
```

### 2. 事件驱动架构
- 用户交互触发事件
- Provider处理业务逻辑
- Service执行具体操作
- UI自动响应状态变化

## 错误处理模式

### 1. 异常分类
- **业务异常**: `QuickSplitException`
- **系统异常**: `FileSystemException`
- **网络异常**: 权限相关异常

### 2. 错误传播
```dart
try {
  // 业务操作
} on SpecificException catch (e) {
  // 特定异常处理
} catch (e) {
  // 通用异常处理
}
```

### 3. 用户友好错误提示
- 错误信息本地化
- 可操作的建议
- 恢复选项提供

## 性能优化模式

### 1. 懒加载模式
- 缩略图按需生成
- 图片预缓存策略
- 分页加载机制

### 2. 缓存策略
- **内存缓存**: 缩略图缓存
- **磁盘缓存**: 主题配置持久化
- **智能清理**: 基于使用频率的缓存清理

### 3. 资源管理
- **Isolate生命周期管理**: 及时销毁避免内存泄漏
- **文件句柄管理**: 及时关闭文件流
- **图片内存管理**: 及时释放大图片内存

## 跨平台适配模式

### 1. 平台检测
```dart
if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
  // 桌面平台特定逻辑
}
```

### 2. 响应式设计
- **自适应布局**: 根据屏幕尺寸调整
- **平台特定UI**: 桌面vs移动端差异
- **字体适配**: Windows使用微软雅黑

### 3. 权限管理
- **平台特定权限**: Android存储权限
- **优雅降级**: 无权限时的用户体验
- **用户引导**: 权限申请说明

## 代码组织模式

### 1. 功能模块化
```
lib/
├── src/
│   ├── features/
│   │   ├── [feature_name]/
│   │   │   ├── *_screen.dart      # 页面
│   │   │   ├── *_provider.dart    # 状态管理
│   │   │   ├── *_service.dart     # 业务逻辑
│   │   │   └── *_exception.dart   # 异常定义
│   ├── shared/
│   │   ├── providers/             # 全局状态
│   │   ├── services/              # 通用服务
│   │   └── widgets/               # 通用组件
│   └── config/                    # 配置管理
```

### 2. 命名规范
- **文件命名**: snake_case
- **类命名**: PascalCase
- **变量命名**: camelCase
- **常量命名**: UPPER_SNAKE_CASE

### 3. 依赖注入
- **构造函数注入**: 服务依赖
- **Provider注入**: 状态管理
- **上下文注入**: 主题和导航

### 4. 分页加载与多级缓存模式 (Paginated Loading with Multi-Level Cache Pattern)

- **模式描述**: 此模式旨在解决移动端或桌面端应用在需要显示大量数据（特别是需要昂贵计算才能渲染的媒体文件，如图片、视频）时的常见性能瓶颈。它通过结合“按需分页加载”和“多级缓存”策略，实现了快速的初始加载、流畅的滚动体验和高效的资源利用。

- **核心组件**:
    - **UI Controller (e.g., `ScrollController`)**: 监听用户的交互（如滚动），当达到预设的阈值（如列表末尾）时，触发数据加载事件。这是用户驱动数据获取的起点。
    - **Data Provider (e.g., `LocalPickerProvider`)**: 系统的核心协调者。它负责：
        - 维护当前的分页状态（已加载的页数或项目数）。
        - 持有已加载的数据列表（通常是轻量级的数据，如文件路径或ID，而非完整数据）。
        - 封装和管理多级缓存的访问逻辑。
        - 调用后台工作单元执行耗时操作。
    - **Multi-Level Cache**: 一个分层的缓存系统，用于最小化延迟和计算开销。
        - **内存缓存 (Memory Cache)**: 提供最快的访问速度，通常使用 `Map` 实现。用于存放最常用或最近访问的数据。生命周期通常与应用会话或特定页面绑定。
        - **磁盘缓存 (Disk Cache)**: 提供持久化存储，避免应用重启后重复生成数据。速度慢于内存缓存但快于重新计算。
    - **Background Worker (e.g., `Isolate`)**: 在独立的后台线程或进程中执行耗时操作（如图片解码、缩略图生成、文件压缩等），避免阻塞UI主线程，确保界面流畅。

- **适用场景**:
    - **相册应用**: 如本项目中的“本地选片”功能，需要展示设备上成百上千张图片。
    - **社交媒体Feed流**: 无限滚动加载新的帖子、图片或视频。
    - **文件管理器**: 显示包含大量文件的目录。
    - **电商应用**: 商品列表的无限滚动加载。
    - **新闻或文章列表**: 按需加载更多条目。