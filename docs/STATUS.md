# 已完成与待办

## 已完成

- HarmonyOS NEXT Stage 工程：`AppScope`、`entry` HAP、`core` HAR、hvigor、`module.json5`、中文应用名「卷舒 PDF」。
- 首页工具宫格和最近文件；扫描、编辑、转换识别、文档四个页面。
- 可移植核心，且不引用鸿蒙套件：
  - 文档找边、四角校正、灰度 / 黑白 / 色彩增强
  - 多页扫描会话可以生成 PDF
  - 文字、高亮、下划线、手写、矩形、椭圆、批注、签名的数据模型和 PDF 外观
  - 合并、拆分、调序、旋转、删除页面、降采样压缩
  - 图片转 PDF、文字转 PDF、导出正文和 PNG
  - 中文文本写入 PDF（`STSong-Light`）
  - 文件索引、搜索、最近使用、页码范围、OCR 行框阅读顺序
- 平台端口：`FilePort`、`NativePdfPort`、`OcrPort`、`CapturePort`。
- 工程 SDK 为 HarmonyOS `26.0.0`（`compileSdkVersion` / `compatibleSdkVersion` / `targetSdkVersion`）。包名 `com.juanshu.pdf`。
- 鸿蒙适配：
  - PDF Kit：打开、合并、拆分、删除、移动、旋转、批注、加文字、转图片
  - Camera Kit：`cameraPicker` 和应用内 `CameraManager` 取景。拍照结果 `photo.main` 是 `image.Image`，先取 JPEG 再解码成像素。
  - 相册 `PhotoViewPicker`，文件选择器导入 PDF
  - Vision Kit `DocumentScanner`（设备有该能力时）
  - Core Vision Kit `textRecognition`（中英文等系统支持的语言）
- 无相机时可用「示例页」走完找边、校正、滤镜和生成 PDF。
- `npm test` 覆盖找边、透视、滤镜、PDF 往返、页面操作、索引和 PNG。

## 待办

- 在 DevEco Studio 和真机上完整编译、签名、安装。本环境没有鸿蒙 SDK，套件调用没有上机验证。
- 第三方 PDF 的可移植解析。现在只保证卷舒写出的文件；外部文件依赖 PDF Kit。
- PDF 压缩改为 JPEG 或 Flate。现在是降低分辨率，可选转灰度。
- 把中文字体子集嵌进 PDF，而不是引用 `STSong-Light`。
- OCR 使用识别块的坐标。阅读顺序函数已经写好，适配器目前采用接口稳定返回的整段文字。
- 撤销栈、表单、密码 PDF、批注导出成标准注释面板都能在其他 App 里继续编辑（卷舒文件主要把外观画进内容流；外部文件才写 PDF Kit 批注）。
- 分享面板、云同步、多窗口和 2in1 的键盘布局。
- iOS、Android、桌面和 Web 壳。边界和顺序见 `docs/ARCHITECTURE.md`。
- 手写识别。签名目前只保存笔迹图。

## 验证

| 项目 | 结果 |
| --- | --- |
| `npm test` 可移植核心 | 在本仓库的 Node 环境执行 |
| hvigor / `assembleHap` | 未执行，没有 DevEco 与 HarmonyOS SDK |
| 真机相机、扫描控件、OCR、PDF 预览 | 未执行 |
