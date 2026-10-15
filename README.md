# 卷舒 PDF

卷舒，取自「卷舒开合」：把纸页卷起来扫描，再舒展开来编辑。英文拼音品牌名是 Juanshu PDF。

这是一个 HarmonyOS NEXT（Stage 模型，ArkTS + ArkUI）应用，把文档扫描、PDF 编辑、转换识别和文件整理放在一起。界面为简体中文。底部是「文档、工具、扫描、我的」，大屏用栅格收窄内容。扫描使用系统文档扫描控件。打开文档使用系统 PDF 预览。产品优先级、会员规则和多端顺序见 [docs/PRODUCT.md](docs/PRODUCT.md)。跨平台策略见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，完成项和未做项见 [docs/STATUS.md](docs/STATUS.md)。

## 功能

- **扫描**：扫描页是系统 `DocumentScanner`，与官方示例同一套配置（文档和表格、原图、手动拍摄、相册）。找边、透视和滤镜仍在可移植核心里，扫描页不再自绘裁切框。
- **编辑**：打开文档使用 PDF Kit 的 `PdfView`，按页宽适配并可以滚动。文字、高亮、手写、批注和签名仍在可移植核心和 PDF Kit 端口里，打开页不再自绘预览。
- **转换识别**：对页面做 OCR（Core Vision Kit，覆盖中文和英文），导出正文或图片，相册图片转 PDF，文字转 PDF。
- **文档**：搜索、重命名、删除、导入、合并、拆分、调序、旋转、删除页面、压缩。

## 环境

- DevEco Studio，并安装 HarmonyOS SDK 26.0.0（apiVersion 26，例如 26.0.0.105）
- `compileSdkVersion`、`compatibleSdkVersion`、`targetSdkVersion` 均为 `26.0.0`
- 手机、平板或 2in1。相机、文档扫描、OCR 和 PDF Kit 需要真机或带对应系统能力的模拟器

本仓库没有携带签名证书。用 DevEco 的自动签名即可。未签名 HAP 可以在模拟器上安装，但部分系统能力仍依赖镜像。

## 在 HarmonyOS 手机上真机测试

下面按顺序做一遍，就能把「卷舒 PDF」装到系统版本达到 HarmonyOS SDK 26.0.0 的华为手机上。本工程的 `compatibleSdkVersion` 是 `26.0.0`，请使用带 HarmonyOS SDK 26.0.0 的 DevEco Studio。低于该版本的系统装不上这个 HAP。

电脑建议：Windows 10/11 64 位、内存 16 GB；或 macOS 11 及以上。安装 SDK 和签名都需要能访问华为开发者站点。

### 1. 安装 DevEco Studio

1. 打开 [DevEco Studio 下载页](https://developer.huawei.com/consumer/cn/deveco-studio/)，进入下载中心，按系统选择 Windows 或 macOS 安装包。
2. 运行安装程序，按向导装完。首次启动保持联网，让它下载 HarmonyOS SDK 和构建工具。
3. 在 SDK 组件里确认已经安装 HarmonyOS SDK 26.0.0（apiVersion 26）。本工程的 `compatibleSdkVersion` 就是 `26.0.0`。
4. 打开 `Help > About`，确认带的是 HarmonyOS SDK 26.0.0。

### 2. 克隆仓库

```bash
git clone https://github.com/porpezite/juanshu-pdf.git
cd juanshu-pdf
```

已经有本地副本时，拉下 `main`，再切到你要测的分支。

### 3. 用 DevEco 打开工程

1. 启动 DevEco Studio，选择 **Open**，选中仓库根目录。根目录里能看到 `build-profile.json5`、`hvigorfile.ts`、`AppScope` 和 `entry`。
2. 打开的是这一层，而不是单独的 `entry` 文件夹。
3. 等待右下角 Sync 结束。依赖没拉下来时，用 DevEco 自带的 ohpm 在工程根目录执行 `ohpm install`。
4. 工程同步成功后，左侧能看到 `entry` 和 `core` 两个模块。

### 4. 手机打开开发者模式和 USB 调试

请在机主的主空间里操作。子用户、隐私空间、学生模式或「坚盾守护模式」下，开发者选项和 USB 调试打不开。

1. 打开手机 **设置**，搜索「关于本机」并进入。有的机型写的是「关于手机」。
2. 找到 **软件版本**，连续快速点击 7 次。系统会提示剩余次数，然后询问是否开启开发者选项。
3. 点确认。HarmonyOS 5 及以上会重启手机并打开开发者选项。有锁屏密码时，按提示输入。
4. 重启后进入 **设置 > 系统 > 开发者选项**。也可以在设置里搜索「开发者选项」。
5. 打开 **USB 调试**。第一次打开时，在确认框里点允许。

日常不用调试时，可以关掉 USB 调试。

### 5. 用数据线连接电脑

1. 使用能传数据的 USB 线，接到电脑主机上的 USB 口。充电线和扩展坞经常让电脑看不到手机。
2. 手机弹出 USB 用途时，按 HarmonyOS 5 的调试说明选择 **仅充电**。
3. 手机弹出「允许 USB 调试」时，勾选 **始终允许使用这台计算机进行调试**，再点允许。
4. 回到 DevEco Studio 顶部的设备下拉框，等待几秒，列表里应出现这台手机的型号。

仍看不到手机时，在 DevEco 自带的终端里执行：

```bash
hdc list targets
```

正常时会打印一行设备序列号。打印 `[Empty]` 说明电脑还没连上手机，先看下面的「常见问题」。

### 6. 用华为账号做自动签名

仓库里没有证书。真机安装必须签名，调试用自动签名即可。

1. 菜单打开 **File > Project Structure > Project > Signing Configs**。
2. 勾选 **Automatically generate signature**（自动生成签名）。还没登录时，点 **Sign In**，用华为开发者账号登录。没有账号就按页面提示注册；需要切换团队时用 Team 下拉框。
3. 保持联网，点 **Apply** 或 **OK**。DevEco 会按包名 `com.juanshu.pdf` 申请调试证书，并写进本机的 `build-profile.json5`。
4. 这些证书、`.p12`、`.cer`、`.p7b` 和密码只留在你的电脑上，不要提交到 Git。

自动签名需要本机时间接近北京时间。断网、多人共用同一套密钥，或要给开放能力配指纹时，再改用手动签名。本应用的相机权限不是受限 ACL，调试阶段用自动签名即可。

### 7. 运行并安装

1. 窗口上方的运行配置保持 **entry**，构建变体用 **debug**。debug 默认可调试；release 默认不可调试。
2. 设备下拉框选中刚才连上的手机。
3. 点绿色 **Run**。第一次会编译 `core` 和 `entry`，再把 HAP 装到手机。
4. 安装完成后，手机会打开「卷舒 PDF」。入口 Ability 是 `EntryAbility`，包名是 `com.juanshu.pdf`。桌面上也能找到同名图标。

装好后建议按这个顺序点一遍：

1. 底部能看到「文档、工具、扫描、我的」，每项是 24×24 图标加文字，选中为蓝色。文档页是大标题和搜索图标，「最近 / 文件夹」用新闻模板的下划线。列表是浅灰底上的白卡片，标题在左，圆角缩略图在右。点一份文档，应打开系统 PDF 预览，左上角可以返回。
2. 打开「扫描」。整页是系统文档扫描控件，没有自绘裁切框。保存后回到文档列表。
3. 打开「工具」，点「提取文字」或「合并」，进入对应页面。有 Core Vision Kit 的手机上，在提取文字里点「识别本页」；系统没有该能力时，会提示识别不可用。
4. 在整理页搜索刚才的文件名，试一次重命名。第一次使用相机或相册时，在系统弹窗里允许权限。

### 8. 常见问题

| 现象 | 处理 |
| --- | --- |
| 设备列表是空的，`hdc list targets` 显示 `[Empty]` | 确认已经重启并进入开发者选项，USB 调试已打开，并且在手机上点了「允许」。换一根数据线和主机上的 USB 口。拔掉扩展坞。关掉电脑上的 VPN 后再插一次。仍没有序列号时，重启手机和 DevEco。 |
| USB 调试是灰的，或找不到开发者选项 | 退出隐私空间和子用户，用机主主空间操作。关闭「坚盾守护模式」。HarmonyOS 5 要连点「软件版本」7 次并确认重启，连点「HarmonyOS 版本」是更早系统的入口。 |
| 弹出允许调试后又马上断开 | USB 用途改成「仅充电」再授权一次。线只能充电、不能传数据时，换线。 |
| Sync 失败，或提示找不到 SDK 26.0.0 | 在 DevEco 的 SDK Manager 里安装 HarmonyOS SDK 26.0.0，并确认 `build-profile.json5` 里的 `compileSdkVersion`、`compatibleSdkVersion`、`targetSdkVersion` 都是 `26.0.0`。企业网络需要在 DevEco 里配置代理。 |
| 打开工程后没有 `entry` / `core`，或 Sync 报工程结构错误 | 关掉窗口，重新 Open 仓库根目录。根目录必须同时有 `build-profile.json5` 和 `entry`。 |
| 签名失败，提示未登录、申请证书失败或时间无效 | 在 Signing Configs 里重新 Sign In。检查网络和系统时间。确认勾的是自动签名，并且包名仍是 `com.juanshu.pdf`。 |
| 安装失败，提示签名不一致或 `install parse native so failed` / 签名不匹配 | 手机上先卸载旧的「卷舒 PDF」，再 Run 一次。换过华为账号或换过电脑后，旧调试证书和新证书对不上。 |
| Run 按钮是灰的 | 先等 Sync 结束。设备没选中时，先让 `hdc list targets` 能看到序列号。运行配置选 `entry`。 |
| 能安装，但相机、智能扫描或 OCR 没反应 | 在系统设置里给「卷舒 PDF」打开相机权限。文档扫描和文字识别依赖系统能力；没有该能力时，应用会提示，扫描仍可用「示例页」和系统相机。 |
| 命令行编译提示 `No signingConfig` | 只编译、不安装时这是预期提示，产物未签名，不能装到真机。真机请用上面的自动签名，再在 DevEco 里 Run。 |

### 只编译、不安装到手机

把路径换成自己的 DevEco 安装目录：

```bash
export DEVECO_SDK_HOME=/path/to/DevEco-Studio/sdk
/path/to/DevEco-Studio/tools/ohpm/bin/ohpm install
/path/to/DevEco-Studio/tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default -p module=entry@default
```

HAP 一般在 `entry/build` 下面。没有签名配置时会出现 `No signingConfig`。要装到手机，请走上一节的自动签名和 Run。

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
docs/PRODUCT.md           优先级、会员规则、多端顺序
docs/ARCHITECTURE.md      模块边界和跨平台策略
docs/STATUS.md            已完成与待办
test/                     核心单元测试
```

## 已知限制

卷舒自己写出的 PDF 用未压缩 RGB 图和 `STSong-Light` 引用中文，阅读器需要能替换这款 CJK 字体。任意第三方 PDF 的解析交给 PDF Kit，不在可移植核心里完成。压缩是降采样，不是 JPEG/Flate 重编码。OCR 行框排序已经在核心里，当前适配器使用识别结果的整段文字。更完整的列表在 `docs/STATUS.md`。
