# ImageJ 免疫荧光计数宏

[中文](#中文) | [English](#english)

## 中文

用 DAPI 定位细胞核，在核周区域判断 marker 阳性，统计单阳性和多阳性细胞。先校准，再批处理。

### 文件

| 文件 | 用途 |
| --- | --- |
| [IF_DAPI_calibrate_simple_EN.ijm](IF_DAPI_calibrate_simple_EN.ijm) | 预览、调整参数并保存校准文件 |
| [IF_DAPI_batch_simple_EN.ijm](IF_DAPI_batch_simple_EN.ijm) | 批量计数，导出结果 |
| [IF_review_saved.ijm](IF_review_saved.ijm) | 重开核查图，放大并按编号定位 |

需要 ImageJ 1.54g 或以上版本，无需额外插件。通过 `Plugins > Macros > Run...` 运行。

### 准备图像

每个通道单独保存为单平面 TIFF，支持 8-bit 灰度和 24-bit RGB，不直接支持 16-bit 或图像堆栈。文件放在同一目录，按“样本-通道-视野”命名：

```text
S01-dapi-1.tif
S01-yellow-1.tif
S01-aqua-1.tif
S01-red-1.tif
S01-green-1.tif
```

同一视野各通道须尺寸一致、位置对齐，不能有重复文件。支持 `.tif` / `.tiff`，不读取子目录。

### 使用

1. 修改校准宏顶部的 `MARKER_SETUP`，设置通道对应和初始阈值。
2. 运行校准宏，选择输入、输出目录，在 `Nuclei and Field` 和 `Marker Thresholds` 中调整参数。
3. 检查预览。选择 `Finish review → Adjust and Preview Again` 可继续调整或更换视野。检查多个代表视野后，选 `Confirm and Save`。
4. 运行批处理宏，选择生成的 `calibration_confirmed.txt` 和图像目录。

校准配置示例：

```javascript
var MARKER_SETUP = newArray(
    "CD8|yellow|27|2|5",
    "GZMK|aqua|21|2|5",
    "TIM3|red|27|2|5",
    "PD1|green|30|2|5"
);
```

每行格式为 `marker|通道|灰度阈值|最小阳性面积(px²)|最小阳性比例(%)`。例如第一行要求 CD8 阈上像素面积 ≥2 px²，且占核周区域 ≥5%；阈上像素指灰度 ≥27 的像素。这些数值只是起点，需要自行校准。

核面积默认 8–500 px²，核周半径 3 px，排除触边对象。面积和距离均按原图像素计算。

### 分割与计数组合

当前默认分割为 `GrayPeakWatershed`，sigma 为 0.8、prominence 为 5。需要原来的分割时，在校准界面选择 `BinaryWatershedLegacy`，重新确认并保存参数。旧模式忽略这两个新参数。

批处理从校准文件读取分割参数；V2 文件使用原分割，V3 文件使用其中记录的模式。

在批处理宏顶部选择计数目标：

```javascript
var COMBINATIONS="ALL";                 // 全部组合
// 或：
// var COMBINATIONS="CD8+GZMK";         // 双阳性
// 或：
// var COMBINATIONS="CD8;CD8+GZMK";     // 多个目标
```

`+` 表示指定 marker 均阳性，其余 marker 不受限制。各组合可重叠，不能相加当作总细胞数。4 个 marker 的 `ALL` 共输出 15 种组合。

### 结果与核查

| 输出 | 内容 |
| --- | --- |
| `positive_counts.csv` | 每个视野的核数、有效细胞数和阳性计数 |
| `cells.csv` | 逐细胞测量、阳性判定及排除原因 |
| `parameters_used.txt` | 本次使用的参数 |
| `reviews/样本-视野/` | 核查 TIFF、核标签、ROI 和分割诊断 |

逐细胞统计请筛选 `Included=1`。用 `Group + Cell_ID` 识别对象；编号只在当前视野内有效。没有有效细胞时计数留空，应检查 `Status`。

运行 `IF_review_saved.ijm`，选择一个视野的核查目录。用放大镜或 `+ / -` 缩放，点击提示中的 `OK` 打开菜单：

- `Show cell IDs`：显示编号。
- `Locate cell by ID`：按编号定位，默认 400%。
- `Label size and locate zoom`：调整字号和定位倍率。
- `Hide all marks`：隐藏标注，查看原灰度图。

DAPI 图中青色为纳入、橙色为排除；marker 图中绿色为阳性、红色为阴性。标注独立于图像像素，请用 ImageJ 查看。修改显示不会重新计算 CSV。

### 使用范围

核周区域由核向外扩展并按 Voronoi 分区，扣除核本体，是细胞范围的近似。结果需要人工核查。

RGB 按 `(R+G+B)/3` 转为 8-bit。转换不能撤销截图前的亮度、对比度调整；分别调过的图像，即使使用相同阈值，也未必能直接比较阳性率。

## English

Detect DAPI nuclei, classify markers in perinuclear regions, and count single- and multiple-positive cells. Calibrate first, then process the batch.

### Files

| File | Purpose |
| --- | --- |
| [IF_DAPI_calibrate_simple_EN.ijm](IF_DAPI_calibrate_simple_EN.ijm) | Preview images, adjust settings, and save calibration |
| [IF_DAPI_batch_simple_EN.ijm](IF_DAPI_batch_simple_EN.ijm) | Process a batch and export counts |
| [IF_review_saved.ijm](IF_review_saved.ijm) | Reopen review images, zoom, and locate cells by ID |

Requires ImageJ 1.54g or later. No extra plugins. Run through `Plugins > Macros > Run...`.

### Input

Save each channel as a separate, single-plane TIFF. Supported: 8-bit grayscale and 24-bit RGB. Native 16-bit images and stacks are not supported.

Keep files in one directory and name them `sample-channel-field.tif`:

```text
S01-dapi-1.tif
S01-yellow-1.tif
S01-aqua-1.tif
S01-red-1.tif
S01-green-1.tif
```

Channels for a field must have identical dimensions and aligned coordinates, with no duplicate files. Both `.tif` and `.tiff` work; subdirectories are not scanned.

### Usage

1. Edit `MARKER_SETUP` at the top of the calibration macro to set channel mappings and starting thresholds.
2. Run calibration, select input/output folders, and adjust `Nuclei and Field` and `Marker Thresholds`.
3. Inspect the preview. Use `Finish review → Adjust and Preview Again` to adjust settings or inspect another field. Review representative fields, then choose `Confirm and Save`.
4. Run the batch macro and select the generated `calibration_confirmed.txt` and image directory.

Example configuration:

```javascript
var MARKER_SETUP = newArray(
    "CD8|yellow|27|2|5",
    "GZMK|aqua|21|2|5",
    "TIM3|red|27|2|5",
    "PD1|green|30|2|5"
);
```

Each row is `marker|channel|gray threshold|min positive area (px²)|min positive percentage (%)`. The first row requires CD8 intensity ≥27 over both ≥2 px² and ≥5% of the perinuclear region. These are starting values, not universal thresholds.

Defaults: nuclear area 8–500 px², perinuclear radius 3 px, edge objects excluded. Areas and distances use native image pixels.

### Segmentation and combinations

The current default is `GrayPeakWatershed`, with sigma 0.8 and prominence 5. To use the original segmentation, select `BinaryWatershedLegacy` during calibration, then confirm and save again. Legacy mode ignores the two new parameters.

Batch segmentation settings come from the calibration file. V2 files use legacy segmentation; V3 files use the recorded mode.

Set counting targets at the top of the batch macro:

```javascript
var COMBINATIONS="ALL";                 // Every combination
// Or:
// var COMBINATIONS="CD8+GZMK";         // Double positive
// Or:
// var COMBINATIONS="CD8;CD8+GZMK";     // Multiple targets
```

`+` requires all named markers to be positive; other markers are unrestricted. Combinations overlap and must not be summed as a total cell count. With four markers, `ALL` exports 15 combinations.

### Results and review

| Output | Contents |
| --- | --- |
| `positive_counts.csv` | Nuclear counts, valid cell counts, and positive counts per field |
| `cells.csv` | Individual-cell measurements, positivity, and exclusion reasons |
| `parameters_used.txt` | Settings used for the run |
| `reviews/sample-field/` | Review TIFFs, nuclear labels, ROIs, and segmentation diagnostics |

Filter individual-cell analyses to `Included=1`. Identify objects by `Group + Cell_ID`; IDs are local to each field. Counts are blank when no valid cells exist—check `Status`.

Run `IF_review_saved.ijm` and select one field's review directory. Use the magnifier or `+ / -` to zoom. Click `OK` in the prompt to open the controls:

- `Show cell IDs`: show labels.
- `Locate cell by ID`: locate an object, at 400% by default.
- `Label size and locate zoom`: adjust font size and lookup magnification.
- `Hide all marks`: inspect the grayscale image without annotations.

DAPI: cyan = included, orange = excluded. Markers: green = positive, red = negative. Annotations are separate from image pixels; open the TIFFs in ImageJ. Display changes do not recalculate CSV results.

### Scope

Perinuclear regions are limited nuclear expansions, separated by Voronoi partitions with nuclei removed. They approximate a cell’s surroundings. Review the results manually.

RGB is converted using `(R+G+B)/3`. Conversion does not undo prior brightness/contrast adjustments. Images adjusted individually may not yield comparable positive rates even with the same threshold.
