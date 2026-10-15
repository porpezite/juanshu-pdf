# 卷舒 PDF

卷舒，取自「卷舒开合」：把纸页卷起来扫描，再舒展开来编辑。英文拼音品牌名是 Juanshu PDF。

这是一个 HarmonyOS NEXT（Stage 模型，ArkTS + ArkUI）应用，把文档扫描、PDF 编辑、转换识别和文件整理放在一起。界面为简体中文，首页是工具宫格和最近文件。核心算法不依赖鸿蒙套件，方便以后迁到 iOS、Android、桌面和 Web。跨平台策略见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，完成项和未做项见 [docs/STATUS.md](docs/STATUS.md)。

## 功能

- **扫描**：系统相机、应用内取景、相册、示例页；自动找边，可拖动四角；透视校正；原图、灰度、黑白、色彩增强；多页合成 PDF。设备支持时可用 Vision Kit 文档扫描控件。
- **编辑**：预览页面，添加文字、高亮、下划线、手写、矩形、椭圆、批注和签名。卷舒自己生成的 PDF 会把外观写回文件。外部 PDF 在 PDF Kit 可用时用系统预览和批注接口。
- **转换识别**：对页面做 OCR（Core Vision Kit，覆盖中文和英文），导出正文或图片，相册图片转 PDF，文字转 PDF。
- **文档**：搜索、重命名、删除、导入、合并、拆分、调序、旋转、删除页面、压缩。

## 环境

- DevEco Studio 5.0.0 Release 或更高
- HarmonyOS SDK 5.0.0(12)，`compatibleSdkVersion` / `targetSdkVersion` 均为 `5.0.0(12)`
- 手机、平板或 2in1。相机、文档扫描、OCR 和 PDF Kit 需要真机或带对应系统能力的模拟器

本仓库没有携带签名证书。用 DevEco 的自动签名即可。未签名 HAP 可以在模拟器上安装，但部分系统能力仍依赖镜像。

## 用 DevEco Studio 打开

1. 打开本仓库根目录（含 `build-profile.json5` 的那一层，不要只打开 `entry`）。
2. 等待 Sync，或在终端执行 DevEco 自带的 `ohpm install`。
3. `File > Project Structure > Signing Configs` 里勾选自动签名。
4. 选择手机、平板或 2in1 运行配置，点击 Run。入口 Ability 是 `EntryAbility`，包名 `com.juanshu.pdf`，桌面名称是「卷舒 PDF」。

命令行（把路径换成自己的 DevEco 安装目录）：

```bash
export DEVECO_SDK_HOME=/path/to/DevEco-Studio/sdk
/path/to/DevEco-Studio/tools/ohpm/bin/ohpm install
/path/to/DevEco-Studio/tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default -p module=entry@default
```

HAP 一般在 `entry/build` 下面。没有配置签名时，hvigor 会提示 `No signingConfig`，这是预期情况，产物是未签名包。

## 不装 DevEco 时检查核心

扫描找边、透视校正、滤镜、PDF 往返、合并拆分旋转压缩、文件索引和 PNG 导出都可以在普通 Node 环境里跑：

```bash
npm install
npm test
```

这些测试不替代真机。它们证明可移植核心的行为，不证明相机、Vision Kit、Core Vision Kit 或 PDF Kit 在设备上的调用。

## 目录

```text
AppScope/                 应用名、图标、包名
core/                     HAR：可移植核心，不引用 @kit
entry/                    HAP：页面和鸿蒙适配器
entry/src/main/ets/pages 首页、扫描、编辑、转换、文档
docs/ARCHITECTURE.md      模块边界和跨平台策略
docs/STATUS.md            已完成与待办
test/                     核心单元测试
```

## 已知限制

卷舒自己写出的 PDF 用未压缩 RGB 图和 `STSong-Light` 引用中文，阅读器需要能替换这款 CJK 字体。任意第三方 PDF 的解析交给 PDF Kit，不在可移植核心里完成。压缩是降采样，不是 JPEG/Flate 重编码。OCR 行框排序已经在核心里，当前适配器使用识别结果的整段文字。更完整的列表在 `docs/STATUS.md`。
