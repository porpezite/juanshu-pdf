# 卷舒 PDF 架构

卷舒 PDF 的第一版是 HarmonyOS NEXT 应用。界面、相机、文件选择和系统 AI 留在鸿蒙壳里；找边、透视、滤镜、文档模型和一份可用的 PDF 读写留在不引用 `@kit` 的核心里。以后加 iOS、Android、桌面或 Web 时，重做壳，复用核心和同一组测试。

## 为什么不是一套 UI 打全部平台

HarmonyOS NEXT 的 PDF Kit、Camera Kit、Vision Kit 文档扫描和 Core Vision Kit 文字识别没有等价的跨平台插件。V1 要先把这些能力用上，所以 UI 用 ArkUI，系统调用留在 `entry`。Flutter、React Native 或 Kotlin Multiplatform 可以以后做壳，但不应该挡住现在的系统套件。

ArkTS 不能直接拿去编译 iOS 或 Android。可共享的是一份刻意写成可移植 TypeScript 子集的核心：有类型、没有 `any`、没有对象解构和展开、不依赖 DOM，也不引用鸿蒙包。

## 模块

```text
entry (HAP, ArkUI)
  pages/            首页、扫描、编辑、转换识别、文档
  platform/         实现下面四个端口，内部才能 import @kit
        |
        v
core (HAR, juanshu_core)
  model/            图像、页面、批注、文件摘要
  scan/             找边、透视、滤镜、手写栅格
  pdf/              PDF 编解码、合并拆分旋转压缩、预览合成
  library/          搜索、最近文件、页码范围、阅读顺序
  ports/            FilePort、NativePdfPort、OcrPort、CapturePort
```

依赖只允许从上往下。`core` 不能引用 `entry`，也不能引用 `@kit.*`、`@ohos.*`。页面不直接调用 PDF Kit 或相机，除了两处必须由 ArkUI 承载的控件：Vision Kit 的 `DocumentScanner`，以及外部 PDF 的 `PdfView`。即使这两处，结果仍然交回 `AppHost` 入库。

`AppHost` 是页面用的门面。它根据文件种类选择引擎：

- 文件带有卷舒元数据（`/Type /JuanshuMeta`）时，用核心编解码器。合并、拆分、旋转、删除、调序、压缩、批注都在内存模型上完成，再写回一份合法 PDF。
- 外部 PDF 走 `NativePdfPort`。HarmonyOS 实现是 PDF Kit 的 `pdfService`：`loadDocument`、`insertPageFromDocument`、`deletePage`、`movePage`、`setRotation`、`addAnnotation`、`addTextObject`、`convertToImage`。
- OCR 走 `OcrPort`。HarmonyOS 实现是 Core Vision Kit 的 `textRecognition.recognizeText`。识别语言由系统能力决定，包含简体中文和英文，应用不另传语言码。
- 拍照和读图走 `CapturePort`。系统相机用 Camera Kit 的 `cameraPicker`，应用内取景用 `CameraManager` 和 `XComponent`，相册用 `PhotoViewPicker`。

## 一份文档的数据

`PdfDocumentModel` 是页面列表。每一页有点大小、旋转、可选的 RGBA 扫描图、正文、OCR 文本和批注。批注坐标相对页面宽高，原点在左上角。

写成 PDF 1.4 时：

- 扫描图是未压缩的 DeviceRGB 图像。
- 正文在没有扫描图时可见；有扫描图时用文本渲染模式 3 写成可搜索的隐藏文字层。
- 高亮、下划线、形状、手写和签名画进内容流。签名带软遮罩。
- 中文使用 `STSong-Light` + `UniGB-UTF16-H`，由阅读器替换字体，不把字库打进文件。
- 同一份结构化数据再写入 `JuanshuMeta` 流。重新打开时以它为准，不反解内容流。

这样「卷舒生成的文件」在鸿蒙、桌面阅读器和其他平台的核心之间可以往返。第三方 PDF 不经过这个编码器解析。

## 扫描流水线

1. 得到 RGBA 图（相机、相册、示例页，或文档扫描控件返回的文件）。
2. `detectDocumentQuad`：缩小到长边 180，用边框亮度分离纸张，填上文字孔洞，取凸包，再删掉共线点直到剩下四个角。失败时退回略微内缩的整页，用户仍可拖角。
3. 四个角可以改。`warpPerspective` 用目标矩形到源四角的单应矩阵做双线性采样。
4. 滤镜：原图、灰度、Otsu 黑白、提高饱和度的色彩增强。
5. 多页交给 `createImageDocument`，再由 `encodePdf` 写文件。

## 推荐的跨平台路线

不要把 ArkUI 页面翻译到别的平台。按下面的顺序加平台：

1. **把 `core/src/main/ets` 视为规范实现。** 它已经能被普通 TypeScript 编译器编译。发布时可以再包一层 npm 包（例如 `@juanshu/core`），HarmonyOS HAR 继续直接引用同一份源码，避免两套算法。
2. **每个平台实现同样的四个端口。** 测试向量用现在的 `npm test`。平台只替换 IO 和系统引擎。
3. **iOS：** SwiftUI 或 UIKit 壳。端口分别接到 PDFKit / VisionKit 文档扫描、Vision 文字识别和相机。核心先机械移植到 Swift，或嵌一个很小的 JS 运行时只跑 `core`。V1 更推荐移植核心并共用测试，而不是在 iOS 里跑 ArkTS。
4. **Android：** Kotlin 壳。端口接到 PdfRenderer 或 PdfBox、ML Kit 文字识别和 CameraX。第三方 PDF 如果要编辑批注，再考虑把 PDFium 放进原生层，接口仍然是 `NativePdfPort`。
5. **桌面（Windows / macOS）：** 原生壳或 Tauri。可移植核心可以直接当库用。外部 PDF 用 PDFium。
6. **Web：** 核心几乎可以原样进浏览器。外部 PDF 用 pdf.js 实现 `NativePdfPort`。扫描用 `getUserMedia` 和 canvas，找边和校正仍调用核心。

不建议为了“一套代码”把 V1 改成 Flutter。那会丢掉已经接上的鸿蒙套件，而且扫描和批注的手感要在各端单独做。

如果以后核心里的 PDF 写入不够用，再把「外部文档引擎」收成 C++（PDFium 一类），四个端口保持不变。HarmonyOS 上优先继续用 PDF Kit，因为它能写系统认可的批注；PDFium 只作为没有 PDF Kit 的平台的实现。

## 页面

| 页面 | 路径 | 职责 |
| --- | --- | --- |
| 首页 | `pages/Index` | `Navigation` + 底部 `Tabs`：文档、工具、扫描、我的。大屏内容用 `GridRow` |
| 扫描 | `pages/ScanPage` | 全屏 Vision Kit `DocumentScanner`，配置同官方 DocDemoPage |
| 编辑 | `pages/EditPage` | PDF Kit `PdfView`，按宽度适配并可滚动 |
| 转换识别 | `pages/ConvertPage` | OCR、导出文字和图片、反向生成 PDF |
| 文档 | `pages/ManagePage` | 搜索、导入、合并、拆分、旋转、压缩 |

首页最近文件和文档列表打开同一份编辑页，避免两套状态。

## 构建形态

Stage 模型，hvigor `modelVersion` 26.0.0，HarmonyOS SDK `26.0.0`（`compileSdkVersion` / `compatibleSdkVersion` / `targetSdkVersion`）。`core` 是 HAR，`entry` 是 HAP。包名 `com.juanshu.pdf`。设备类型是 phone、tablet、2in1。签名不进仓库。
