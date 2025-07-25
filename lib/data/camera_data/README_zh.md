# 相机数据库

用于研究和应用开发的开源相机规格和图像数据库。

## 概述

本仓库包含来自各制造商的3,586款数码相机的详细规格。


## 仓库结构

```
camera_data/               # 数据目录
│   ├── camera_data.csv    # CSV格式的相机规格数据
│   ├── camera_data.json   # JSON格式的相机规格数据
│   ├── README_zh.md       # 中文文档 （本文件）
```


## 数据文件

- `data/camera_data.csv`: CSV格式的相机规格数据（37列）
- `data/camera_data.json`: JSON格式的相机规格数据（与CSV数据相同）


## 数据结构

数据集包含以下字段：

| 英文字段 | 中文翻译 | 描述 |
|---------|----------|------|
| Brand | 品牌 | 相机制造商 |
| Model | 型号 | 相机型号名称 |
| Year | 年份 | 发布年份 |
| image_file | 图像文件 | 相机图像的路径 |
| Total megapixels | 总像素 | 总百万像素数 |
| Exposure Compensation | 曝光补偿 | 可用的曝光补偿范围 |
| Normal focus range | 正常对焦范围 | 常规对焦距离范围 |
| Battery | 电池 | 电池类型 |
| Sensor resolution | 传感器分辨率 | 分辨率（像素宽 x 高） |
| Crop factor | 裁切系数 | 传感器裁切系数 |
| Sensor type | 传感器类型 | 图像传感器类型（CCD、CMOS等） |
| Dimensions | 尺寸 | 物理尺寸（毫米） |
| Max aperture | 最大光圈 | 最大光圈值 |
| Min. shutter speed | 最慢快门速度 | 最慢快门速度 |
| White balance presets | 白平衡预设 | 白平衡预设数量 |
| Macro focus range | 微距对焦范围 | 微距摄影的最小对焦距离 |
| Optical zoom | 光学变焦 | 是否具有光学变焦功能 |
| USB | USB接口 | USB接口类型 |
| Weight | 重量 | 相机重量（克） |
| Max. aperture (35mm equiv.) | 最大光圈（35mm等效） | 35mm等效的最大光圈 |
| Focal length (35mm equiv.) | 焦距（35mm等效） | 35mm等效的焦距范围 |
| Also known as | 又称为 | 替代名称或型号 |
| Aperture priority | 光圈优先 | 是否具有光圈优先模式 |
| Max. image resolution | 最大图像分辨率 | 最大图像分辨率（像素） |
| Max. shutter speed | 最快快门速度 | 最快快门速度 |
| Storage types | 存储类型 | 兼容的存储介质 |
| Effective megapixels | 有效像素 | 用于图像捕获的有效百万像素 |
| Megapixels | 百万像素 | 营销百万像素计数 |
| Max. video resolution | 最大视频分辨率 | 最大视频分辨率 |
| Screen size | 屏幕尺寸 | 液晶屏幕尺寸（英寸） |
| Metering | 测光 | 可用的测光模式 |
| Digital zoom | 数码变焦 | 是否具有数码变焦功能 |
| Shutter priority | 快门优先 | 是否具有快门优先模式 |
| Sensor size | 传感器尺寸 | 物理传感器尺寸（毫米） |
| Viewfinder | 取景器 | 取景器类型 |
| Screen resolution | 屏幕分辨率 | 液晶屏幕分辨率（点） |
| ISO | ISO感光度 | 可用的ISO感光度范围 |

## 数据格式

数据以两种格式提供：

1. **CSV**：适用于电子表格应用程序和数据分析工具的简单表格格式
2. **JSON**：适用于Web应用程序和编程的结构化格式

### JSON示例

```json
{
    "Brand": "Canon",
    "Model": "EOS R5 Mark II",
    "Year": "2024",
    "image_file": "data/images/canon_eos-r5-mark-ii.jpg",
    "Total megapixels": "50.3",
    "Exposure Compensation": "\u00b13 EV (in 1/3 EV, 1/2 EV steps)",
    "Normal focus range": null,
    "Battery": "LP-E6P lithium-ion battery",
    "Sensor resolution": "8216 x 5477",
    "Crop factor": "1.0",
    "Sensor type": "CMOS",
    "Dimensions": "138.5 x 101.2 x 93.5 mm",
    "Max aperture": null,
    "Min. shutter speed": "30 sec",
    "White balance presets": "8.0",
    "Macro focus range": null,
    "Optical zoom": null,
    "USB": "USB 3.2 (10 GBit/sec)",
    "Weight": "746 g",
    "Max. aperture (35mm equiv.)": null,
    "Focal length (35mm equiv.)": null,
    "Also known as": null,
    "Aperture priority": "Yes",
    "Max. image resolution": "8192 x 5464",
    "Max. shutter speed": "1/8000 sec",
    "Storage types": "SD/SDHC/SDXC, CFexpress Type B",
    "Effective megapixels": "45.0",
    "Megapixels": null,
    "Max. video resolution": "8192x4320 (60/50/30p/\u200b25p/24p)",
    "Screen size": "3.2\"",
    "Metering": "Multi, Center-weighted, Spot, Partial",
    "Digital zoom": null,
    "Shutter priority": "Yes",
    "Sensor size": "36 x 24 mm",
    "Viewfinder": "Electronic",
    "Screen resolution": "2,100,000 dots",
    "ISO": "Auto, 100-51200 (extends to 50-102400)"
  }
```
