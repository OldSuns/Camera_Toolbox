
# 活动上下文：照片边框水印 UI 重构（Windows 优先）
- 启动时间：2025-08-08 17:31 CST
- 目标：在不削减功能的前提下，参考 semi-utils 的布局与配置理念，优化 Flutter 前端界面为更接近 HTML+CSS 风格的三栏布局（左：设置；中：预览画布；右：批处理队列），优先适配 Windows 桌面。
- 关联模块：
  - [photo_watermark_screen.dart](lib/src/features/photo_watermark/photo_watermark_screen.dart)
  - [watermark_settings.dart](lib/src/features/photo_watermark/widgets/watermark_settings.dart)
  - [watermark_preview.dart](lib/src/features/photo_watermark/widgets/watermark_preview.dart)
  - [batch_process_list.dart](lib/src/features/photo_watermark/widgets/batch_process_list.dart)
  - 配置与处理（供参考）：WatermarkConfig、WatermarkProcessor

## semi-utils 关键配置摘录（映射指引）
来源：[README.md](lib/data/semi-utils-main/README.md)
- Global:
  - White Margin: enable + width(%) → Flutter: whiteMarginEnabled + whiteMarginWidth
  - Shadow: enable → Flutter: shadowEnabled
  - Focal Length: use_equivalent_focal_length → Flutter: useEquivalentFocalLength
  - Quality: output quality → Flutter: outputQuality
- Layout:
  - type（watermark_left_logo, watermark_right_logo, dark_*, custom_watermark, square, simple, background_blur, background_blur_with_white_border）
  - elements: left_top/right_top/left_bottom/right_bottom { color, is_bold, name }
  - logo_enable + logo_position(left/right)
- Logo: make → path（与项目 lib/data/logos/ 对齐）

建议新增/对齐：
- 在设置面板加入“布局类型(Layout Type)”下拉；无实现缺口时仅做 UI 侧选择占位，后续与处理器联动。
- 元素 name 列表对齐 README 的可选项（Model/Make/LensModel/Param/Datetime/Date/Custom/None/...）。

## UI 重构要点（HTML+CSS 风格）
- 三栏布局（固定左 320~360px；中自适应；右 360~420px），色块与阴影分层，卡片化分组，密集控件采用 Dense 表单风格。
- 头部工具条：输出目录选择、打开目录、标签切换（单张/批量），视觉统一。
- 预览画布：灰棋盘/中性背景、InteractiveViewer 缩放、尺寸自适应。
- 队列列表：状态徽标、文件大小、副文行、完成后“打开位置”快速操作。
- Token 化（建议新增）：spacing、radius、elevation、palette，集中在 design_tokens.dart 并在各组件复用。

## 完成度定义（本子任务）
- UI 结构重构完成，功能点（拖拽、选择、预览、保存、批处理、输出目录操作）保持可用；
- 设置项与现有 Provider 行为一致，新增“布局类型”选择项不破坏现有逻辑；
- Windows 桌面下视觉与交互提升明显（阴影、分隔、对齐、色彩层次）。
## 配置映射分析完成（2025-08-08 17:47 CST）

### semi-utils → Flutter WatermarkConfig 映射关系：
1. **基础配置**
   - `base.quality` → `outputQuality` ✓
   - `base.font_size` → `fontSize` ✓
   - `base.bold_font_size` → `boldFontSize` ✓

2. **全局设置**
   - `global.focal_length.use_equivalent_focal_length` → `useEquivalentFocalLength` ✓
   - `global.padding_with_original_ratio.enable` → `paddingWithOriginalRatio` ✓
   - `global.shadow.enable` → `shadowEnabled` ✓
   - `global.white_margin.enable` → `whiteMarginEnabled` ✓
   - `global.white_margin.width` → `whiteMarginWidth` ✓

3. **布局配置**
   - `layout.type` → `layoutType` (需扩展枚举值) ✓
   - `layout.background_color` → `backgroundColor` ✓
   - `layout.logo_enable` → `logoEnabled` ✓
   - `layout.logo_position` → `logoPosition` (left/right映射) ✓
   - `layout.elements.*` → 四角元素配置 ✓

4. **Logo映射**
   - semi-utils的logo路径已与Flutter项目`lib/data/logos/`对齐 ✓

### UI设计方案（Windows优先，HTML+CSS风格）

#### 三栏布局结构：
```
┌─────────────────────────────────────────────────────────────────┐
│  AppBar: 照片边框水印 | Tab[单张|批量] | 输出目录 | 打开目录    │
├────────────┬────────────────────────────────┬──────────────────┤
│            │                                │                  │
│   左侧栏    │          中央预览区            │     右侧栏       │
│  (360px)   │         (flex: 2)            │    (400px)       │
│            │                                │                  │
│ ┌────────┐ │  ┌──────────────────────┐    │ ┌──────────────┐ │
│ │布局类型│ │  │                      │    │ │ 批处理队列  │ │
│ │下拉选择│ │  │    预览画布          │    │ │             │ │
│ └────────┘ │  │  (灰色棋盘背景)     │    │ │ ┌──────────┐│ │
│            │  │                      │    │ │ │任务卡片1 ││ │
│ ┌────────┐ │  │  InteractiveViewer  │    │ │ └──────────┘│ │
│ │Logo设置│ │  │                      │    │ │ ┌──────────┐│ │
│ └────────┘ │  └──────────────────────┘    │ │ │任务卡片2 ││ │
│            │                                │ │ └──────────┘│ │
│ ┌────────┐ │  ┌──────────────────────┐    │ │     ...     │ │
│ │文字内容│ │  │ 拖放提示区域         │    │ └──────────────┘ │
│ │(四角)  │ │  └──────────────────────┘    │                  │
│ └────────┘ │                                │ ┌──────────────┐ │
│            │                                │ │ 进度信息     │ │
│ ┌────────┐ │                                │ │ 12/50 24%   │ │
│ │全局设置│ │                                │ └──────────────┘ │
│ └────────┘ │                                │                  │
│            │                                │ ┌──────────────┐ │
│ ┌────────┐ │                                │ │ 批量操作按钮 │ │
│ │操作按钮│ │                                │ │ [清空][开始] │ │
│ └────────┘ │                                │ └──────────────┘ │
└────────────┴────────────────────────────────┴──────────────────┘
```

#### 设计令牌（Design Tokens）：
```dart
// lib/src/features/photo_watermark/widgets/design_tokens.dart
class WatermarkDesignTokens {
  // 间距系统
  static const spacing = (
    xs: 4.0,
    sm: 8.0,
    md: 16.0,
    lg: 24.0,
    xl: 32.0,
  );
  
  // 圆角系统
  static const radius = (
    sm: 4.0,
    md: 8.0,
    lg: 12.0,
    xl: 16.0,
  );
  
  // 阴影系统
  static const elevation = (
    card: BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    hover: BoxShadow(
      color: Color(0x26000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  );
  
  // 布局尺寸
  static const layout = (
    leftPanelWidth: 360.0,
    rightPanelWidth: 400.0,
    minWindowWidth: 1200.0,
  );
}
```

#### 组件样式特征：
1. **卡片化分组**：每个设置区域使用Card包裹，带subtle阴影
2. **密集表单**：使用`isDense: true`和紧凑的`contentPadding`
3. **分隔线**：使用细线Divider分隔功能区
4. **悬浮效果**：鼠标悬停时增强阴影和微调色彩
5. **过渡动画**：使用`AnimatedContainer`实现平滑过渡
## UI重构实施完成（2025-08-08 18:07 CST）

### 已完成的重构内容：
1. **创建设计令牌系统** (`design_tokens.dart`)
   - 定义间距系统（xs: 4, sm: 8, md: 16, lg: 24, xl: 32）
   - 定义圆角系统（sm: 4, md: 8, lg: 12, xl: 16）
   - 定义阴影系统（card, hover, dialog）
   - 定义布局尺寸（leftPanel: 360, rightPanel: 400, minWindow: 1200）

2. **主界面三栏布局重构** (`photo_watermark_screen.dart`)
   - 移除TabBar，改为单页面三栏布局
   - 左侧设置面板（360px固定宽度）
   - 中央预览区域（flex: 2 自适应）
   - 右侧批处理队列（400px固定宽度）
   - 保留拖拽功能和所有原有交互

3. **设置面板优化** (`watermark_settings.dart`)
   - 新增"布局类型"下拉选择（对应semi-utils的layout.type）
   - 使用Card包裹各设置区域，应用统一阴影
   - 实现密集表单样式（isDense: true）
   - 优化颜色选择器和Logo位置选择器的视觉效果

4. **预览组件增强** (`watermark_preview.dart`)
   - 添加灰色棋盘背景（CheckerboardPainter）
   - 保持InteractiveViewer缩放功能
   - 优化图像显示的边界检查

5. **批处理列表改进** (`batch_process_list.dart`)
   - 改为右侧固定栏显示
   - 优化任务卡片样式（悬浮效果、过渡动画）
   - 增强状态图标和进度显示

### 技术亮点：
- 使用`AnimatedContainer`实现平滑过渡效果
- 应用`InkWell`和`Material`组件增强交互反馈
- 统一使用设计令牌系统保证视觉一致性
- 保持与现有Provider状态管理的完全兼容

### 待验证项（自测）：
- [ ] Windows桌面端最小宽度1200px适配
- [ ] 深色/浅色主题切换效果
- [ ] 窗口缩放响应式布局
- [ ] 拖拽、批处理等功能完整性
## 问题修复记录（2025-08-08 18:10 CST）

### 修复的问题：
1. **RenderFlex溢出问题**
   - 位置：`batch_process_list.dart:78` Row组件
   - 原因：当任务状态为completed时，显示两个IconButton导致内容超出容器宽度
   - 解决方案：
     - 为trailing部分添加固定宽度容器（72px）
     - 将IconButton改为InkWell+Container组合，更好控制尺寸
     - 在Row中添加间距控制（SizedBox）
     - 使用mainAxisAlignment.end确保按钮右对齐

### 修复细节：
```dart
// 修复前：使用IconButton可能导致额外padding
IconButton(
  icon: Icon(...),
  onPressed: ...,
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
)

// 修复后：使用InkWell精确控制尺寸
InkWell(
  onTap: ...,
  borderRadius: BorderRadius.circular(16),
  child: Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    child: Icon(...),
  ),
)
```