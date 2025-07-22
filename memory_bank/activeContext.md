# 本地选片功能优化方案

**分析日期:** 2025-07-22T09:25:30Z

## 1. 现有实现分析

- **优点:**
  - 使用 `Isolate` 进行后台缩略图生成，避免UI阻塞。
  - 使用 `Provider` 和 `Selector` 进行高效的状态管理。
  - `GridView.builder` 和 `Selector` 在UI层保证了较好的渲染性能。
- **瓶颈:**
  - **无磁盘缓存:** 缩略图仅存于内存，关闭应用后失效，需要重复生成。
  - **一次性加载:** `selectFolder` 一次性读取目录下所有图片文件，对于大文件夹会导致启动慢和内存占用高。
  - **文件列表构建阻塞:** `dir.list()` 可能在文件过多时阻塞主线程。

## 2. 优化方案设计

### 方案 A: 磁盘缓存 + 分页加载 (首选实施方案)

#### a. 缩略图磁盘缓存

- **目标:** 持久化缩略图，避免重复计算。
- **实现:**
  1.  **依赖:** 添加 `path_provider` (获取缓存目录) 和 `crypto` (生成哈希文件名)。
  2.  **缓存路径:** 在 `getApplicationCacheDirectory()` 下创建 `thumbnails` 子目录。
  3.  **文件名:** 使用原图路径的 MD5 哈希值作为缓存文件名，如 `md5(image.path).jpg`。
  4.  **生成逻辑 (`_thumbnailGenerator` Isolate):**
     - 生成缩略图 `Uint8List`。
     - 将 `Uint8List` 写入磁盘缓存文件。
     - 通过 `SendPort` 将生成的 `Uint8List` 发回主 Isolate。
  5.  **读取逻辑 (`LocalPickerProvider`):**
     - 检查内存缓存 (`_thumbnailCache`)。
     - **[新]** 若未命中，检查磁盘缓存。
       - 若磁盘缓存存在，读取文件内容 (`Uint8List`)，存入内存缓存，并返回。
     - 若磁盘缓存未命中，才向 `Isolate` 发送生成请求。

#### b. 图片列表分页加载

- **目标:** 降低初始加载时间和内存占用。
- **实现:**
  1.  **状态变更:** `LocalPickerProvider` 不再持有 `List<File> _images`，而是 `List<String> _imagePaths` 和 `String _currentDirectory`。
  2.  **加载逻辑:**
     - `selectFolder` 只保存目录路径，并触发加载第一页。
     - 创建 `loadMoreImages({int pageSize = 50})` 方法。
     - 该方法使用 `Directory(_currentDirectory).list()` 流，使用 `skip()` 和 `take()` 来获取特定页的文件路径。
     - 将获取的路径添加到 `_imagePaths` 列表中。
  3.  **UI 触发:**
     - 在 `LocalPickerScreen` 的 `GridView` 上附加一个 `ScrollController`。
     - 监听滚动事件，当滚动到列表末尾时，调用 `provider.loadMoreImages()`。

### 方案 B: 引入数据库 (长期演进方向)

- **目标:** 更健壮、高效地管理图片元数据和缓存状态。
- **实现:**
  - 使用 `sqflite`。
  - **数据表结构:** `(id, original_path, thumbnail_path, last_modified, width, height)`。
  - **流程:**
    - 选择文件夹时，扫描并与数据库比对（基于路径和 `last_modified`），同步文件信息。
    - 加载图片列表变为简单的数据库分页查询。
    - 极大提升了后续加载速度和数据一致性。

## 3. 初步实施计划

将首先实施 **方案 A**，因为它可以在不引入新数据库依赖的情况下快速解决核心性能问题。
