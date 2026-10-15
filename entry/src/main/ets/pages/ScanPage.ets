import { image } from '@kit.ImageKit';
import { DocType, DocumentScanner, DocumentScannerConfig, SaveOption } from '@kit.VisionKit';
import {
  Point, Quad, RgbaImage, ScanFilter, applyFilter, detectDocumentQuad, sampleDocumentImage, warpPerspective
} from 'juanshu_core';
import { TitleBar, clamp01, stampName, toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';
import { HarmonyCameraSession, ensureCamera } from '../platform/HarmonyCapture';
import { readImageUri, toPixelMap } from '../platform/PixelBridge';

@Entry
@Component
struct ScanPage {
  @State stage: number = 0;
  @State filter: number = ScanFilter.ORIGINAL;
  @State pageCount: number = 0;
  @State message: string = '拍摄文档，或先用示例页试用裁边';
  @State docName: string = '';
  @State useNative: boolean = false;
  @State useCamera: boolean = false;
  @State tlx: number = 0.08;
  @State tly: number = 0.08;
  @State trx: number = 0.92;
  @State try_: number = 0.08;
  @State brx: number = 0.92;
  @State bry: number = 0.92;
  @State blx: number = 0.08;
  @State bly: number = 0.92;
  @State preview: image.PixelMap | undefined = undefined;
  @State areaWidth: number = 1;
  @State areaHeight: number = 1;
  private source: RgbaImage | null = null;
  private warped: RgbaImage | null = null;
  private pages: RgbaImage[] = [];
  private dragX: number = 0;
  private dragY: number = 0;
  private scannerConfig: DocumentScannerConfig = new DocumentScannerConfig();
  private liveCamera: HarmonyCameraSession = new HarmonyCameraSession();
  private xController: XComponentController = new XComponentController();

  aboutToAppear(): void {
    this.docName = stampName('扫描');
    this.scannerConfig.supportType = [DocType.DOC];
    this.scannerConfig.maxShotCount = 20;
    this.scannerConfig.isGallerySupported = true;
    this.scannerConfig.saveOptions = [SaveOption.PDF, SaveOption.JPG];
  }

  aboutToDisappear(): void {
    this.liveCamera.close();
  }

  build() {
    Column() {
      TitleBar({ title: '扫描' })
      if (this.useNative) {
        DocumentScanner({
          scannerConfig: this.scannerConfig,
          onResult: (code: number, saveType: SaveOption, uris: string[]) => {
            this.onNativeResult(code, saveType, uris);
          }
        })
          .layoutWeight(1)
          .width('100%')
      } else {
        this.scanStage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  @Builder
  scanStage() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.viewfinder()
      if (this.stage === 1 && this.preview !== undefined) {
        this.cropGuides()
      }
      this.shutterBar()
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  viewfinder() {
    Stack() {
      if (this.useCamera) {
        XComponent({
          id: 'juanshuCamera',
          type: XComponentType.SURFACE,
          controller: this.xController
        })
          .onLoad(() => {
            this.openLiveCamera();
          })
          .width('100%')
          .height('100%')
      } else if (this.preview !== undefined) {
        Image(this.preview)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#E7E2D8')
      } else {
        Column() {
          Text('取景')
            .fontSize(22)
            .fontColor('#6E6A62')
          Text('打开相机、相册或示例页')
            .fontSize(13)
            .fontColor('#6E6A62')
            .margin({ top: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#E7E2D8')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  cropGuides() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.guideEdge(this.tlx, this.tly, this.trx, this.try_)
      this.guideEdge(this.trx, this.try_, this.brx, this.bry)
      this.guideEdge(this.brx, this.bry, this.blx, this.bly)
      this.guideEdge(this.blx, this.bly, this.tlx, this.tly)
      this.handle(this.tlx, this.tly, 0)
      this.handle(this.trx, this.try_, 1)
      this.handle(this.brx, this.bry, 2)
      this.handle(this.blx, this.bly, 3)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_old, area) => {
      const width = Number(area.width);
      const height = Number(area.height);
      if (width !== this.areaWidth) {
        this.areaWidth = width;
      }
      if (height !== this.areaHeight) {
        this.areaHeight = height;
      }
    })
  }

  @Builder
  guideEdge(x1: number, y1: number, x2: number, y2: number) {
    Line()
      .width('100%')
      .height('100%')
      .startPoint([x1 * this.areaWidth, y1 * this.areaHeight])
      .endPoint([x2 * this.areaWidth, y2 * this.areaHeight])
      .stroke('#1F6B4A')
      .strokeWidth(2)
      .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  shutterBar() {
    if (this.stage === 1) {
      this.adjustBar()
    } else {
      Scroll() {
        Column() {
          Text(this.message)
            .fontSize(13)
            .fontColor('#6E6A62')
            .width('100%')
            .margin({ bottom: 8 })
          if (this.stage === 0) {
            this.captureActions()
          } else {
            this.filterActions()
          }
          this.pageTray()
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: '46%' })
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
      .backgroundColor('#F6F4EF')
      .borderRadius({ topLeft: 18, topRight: 18 })
    }
  }

  @Builder
  adjustBar() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text('拖动四角贴合纸边')
          .fontSize(13)
          .fontColor('#6E6A62')
          .layoutWeight(1)
        Button('重拍')
          .height(40)
          .margin({ right: 8 })
          .backgroundColor('#FFFFFF')
          .fontColor('#1C1B19')
          .onClick(() => {
            this.stage = 0;
            this.message = '可以继续拍摄下一页';
          })
        Button('校正')
          .height(40)
          .backgroundColor('#1F6B4A')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.applyWarp();
          })
      }
      .width('100%')
      if (this.pageCount > 0) {
        Text('已收集 ' + this.pageCount + ' 页')
          .fontSize(12)
          .fontColor('#1F6B4A')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .backgroundColor('#F6F4EF')
    .borderRadius({ topLeft: 18, topRight: 18 })
  }

  @Builder
  handle(x: number, y: number, which: number) {
    Circle()
      .width(22)
      .height(22)
      .fill('#1F6B4A')
      .position({ x: (x * 100) + '%', y: (y * 100) + '%' })
      .markAnchor({ x: '50%', y: '50%' })
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.dragX = x;
            this.dragY = y;
          })
          .onActionUpdate((event: GestureEvent) => {
            const nx = clamp01(this.dragX + event.offsetX / Math.max(1, this.areaWidth));
            const ny = clamp01(this.dragY + event.offsetY / Math.max(1, this.areaHeight));
            this.setCorner(which, nx, ny);
          })
      )
  }

  @Builder
  captureActions() {
    Column() {
      if (this.useCamera) {
        Flex({ justifyContent: FlexAlign.Center }) {
          Button('拍摄')
            .width(76)
            .height(76)
            .borderRadius(38)
            .backgroundColor('#1F6B4A')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .onClick(() => {
              this.takeLivePhoto();
            })
        }
        .width('100%')
        .margin({ bottom: 10 })
      }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Button('智能扫描')
          .width('48%')
          .height(42)
          .margin({ bottom: 8 })
          .backgroundColor('#1F6B4A')
          .fontColor('#FFFFFF')
          .borderRadius(12)
          .onClick(() => {
            this.startNativeScan();
          })
        Button(this.useCamera ? '关闭取景' : '打开相机')
          .width('48%')
          .height(42)
          .margin({ bottom: 8 })
          .backgroundColor('#FFFFFF')
          .fontColor('#1F6B4A')
          .borderRadius(12)
          .onClick(() => {
            this.toggleCamera();
          })
        Button('系统相机')
          .width('48%')
          .height(42)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C1B19')
          .borderRadius(12)
          .onClick(() => {
            this.captureSystem();
          })
        Button('相册')
          .width('48%')
          .height(42)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C1B19')
          .borderRadius(12)
          .onClick(() => {
            this.pickAlbum();
          })
        Button('示例页')
          .width('48%')
          .height(42)
          .margin({ top: 8 })
          .backgroundColor('#FFFFFF')
          .fontColor('#1C1B19')
          .borderRadius(12)
          .onClick(() => {
            this.useSample();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  filterActions() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween }) {
        this.filterChip('原图', ScanFilter.ORIGINAL)
        this.filterChip('灰度', ScanFilter.GRAY)
        this.filterChip('黑白', ScanFilter.BW)
        this.filterChip('增强', ScanFilter.COLOR)
      }
      .width('100%')
      Button('加入多页')
        .width('100%')
        .height(46)
        .margin({ top: 12 })
        .backgroundColor('#1F6B4A')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.addPage(false);
        })
      TextInput({ text: this.docName, placeholder: '文件名' })
        .width('100%')
        .height(44)
        .margin({ top: 8 })
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.docName = value;
        })
      Button('生成 PDF')
        .width('100%')
        .height(46)
        .margin({ top: 8 })
        .backgroundColor('#154832')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.addPage(true);
        })
    }
    .width('100%')
  }

  @Builder
  filterChip(label: string, value: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.filter === value ? '#FFFFFF' : '#1C1B19')
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(36)
      .margin({ right: 6 })
      .borderRadius(10)
      .backgroundColor(this.filter === value ? '#1F6B4A' : '#FFFFFF')
      .onClick(() => {
        this.filter = value;
        this.refreshFiltered();
      })
  }

  @Builder
  pageTray() {
    if (this.pageCount > 0) {
      Column() {
        Text('已收集 ' + this.pageCount + ' 页')
          .fontSize(13)
          .fontColor('#1F6B4A')
        Button('生成已收集的 PDF')
          .width('100%')
          .height(42)
          .margin({ top: 8 })
          .backgroundColor('#154832')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.finishCollected();
          })
      }
      .width('100%')
      .margin({ top: 14 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  private startNativeScan(): void {
    if (!canIUse('SystemCapability.AI.Component.DocScan')) {
      toast('当前设备没有文档扫描控件，请用相机或示例页');
      return;
    }
    this.useCamera = false;
    this.liveCamera.close();
    this.useNative = true;
  }

  private async onNativeResult(code: number, saveType: SaveOption, uris: string[]): Promise<void> {
    this.useNative = false;
    if (code !== 200 || uris.length === 0) {
      this.message = '已取消智能扫描';
      return;
    }
    if (saveType === SaveOption.PDF) {
      const bytes = await AppHost.capture().readBytes(uris[0]);
      if (bytes === null) {
        toast('没有读到扫描结果');
        return;
      }
      const saved = AppHost.importBytes(this.docName, bytes);
      toast(saved === null ? '导入失败' : '已保存 ' + (saved === null ? '' : saved.name));
      return;
    }
    const images = await AppHost.capture().readImages(uris);
    if (images.length === 0) {
      toast('没有读到图片');
      return;
    }
    const saved = AppHost.imagesToPdf(images, this.docName);
    toast('已保存 ' + saved.name);
  }

  private async toggleCamera(): Promise<void> {
    if (this.useCamera) {
      this.useCamera = false;
      await this.liveCamera.close();
      return;
    }
    const context = AppHost.context();
    if (context === null) {
      return;
    }
    const allowed = await ensureCamera(context);
    if (!allowed) {
      toast('需要相机权限');
      return;
    }
    this.useCamera = true;
    this.stage = 0;
  }

  private async openLiveCamera(): Promise<void> {
    const context = AppHost.context();
    if (context === null) {
      return;
    }
    const surfaceId = this.xController.getXComponentSurfaceId();
    const opened = await this.liveCamera.open(context, surfaceId);
    if (!opened) {
      toast('无法打开相机，可改用系统相机');
      this.useCamera = false;
    }
  }

  private async takeLivePhoto(): Promise<void> {
    const image = await this.liveCamera.capture();
    this.useCamera = false;
    await this.liveCamera.close();
    if (image === null) {
      toast('没有拿到照片');
      return;
    }
    this.beginAdjust(image);
  }

  private async captureSystem(): Promise<void> {
    const image = await AppHost.capture().capturePhoto();
    if (image === null) {
      toast('未拍摄照片');
      return;
    }
    this.beginAdjust(image);
  }

  private async pickAlbum(): Promise<void> {
    const uris = await AppHost.album().pickFromAlbum(1);
    if (uris.length === 0) {
      return;
    }
    const image = await readImageUri(uris[0]);
    if (image === null) {
      toast('无法读取图片');
      return;
    }
    this.beginAdjust(image);
  }

  private useSample(): void {
    this.beginAdjust(sampleDocumentImage());
  }

  private async beginAdjust(pixels: RgbaImage): Promise<void> {
    this.source = pixels;
    const quad = detectDocumentQuad(pixels);
    this.applyQuad(quad, pixels.width, pixels.height);
    this.stage = 1;
    this.message = '已检测边缘，可拖动四角';
    this.preview = await toPixelMap(pixels);
  }

  private applyQuad(quad: Quad, width: number, height: number): void {
    this.tlx = quad.topLeft.x / width;
    this.tly = quad.topLeft.y / height;
    this.trx = quad.topRight.x / width;
    this.try_ = quad.topRight.y / height;
    this.brx = quad.bottomRight.x / width;
    this.bry = quad.bottomRight.y / height;
    this.blx = quad.bottomLeft.x / width;
    this.bly = quad.bottomLeft.y / height;
  }

  private setCorner(which: number, x: number, y: number): void {
    if (which === 0) {
      this.tlx = x;
      this.tly = y;
    } else if (which === 1) {
      this.trx = x;
      this.try_ = y;
    } else if (which === 2) {
      this.brx = x;
      this.bry = y;
    } else {
      this.blx = x;
      this.bly = y;
    }
  }

  private async applyWarp(): Promise<void> {
    if (this.source === null) {
      return;
    }
    const width = this.source.width;
    const height = this.source.height;
    const quad = new Quad(
      new Point(this.tlx * width, this.tly * height),
      new Point(this.trx * width, this.try_ * height),
      new Point(this.brx * width, this.bry * height),
      new Point(this.blx * width, this.bly * height)
    );
    this.warped = warpPerspective(this.source, quad);
    this.stage = 2;
    this.message = '选择滤镜后加入多页，或直接生成 PDF';
    await this.refreshFiltered();
  }

  private async refreshFiltered(): Promise<void> {
    if (this.warped === null) {
      return;
    }
    const shown = applyFilter(this.warped, this.filter);
    this.preview = await toPixelMap(shown);
  }

  private addPage(finish: boolean): void {
    if (this.warped === null) {
      toast('还没有可加入的页面');
      return;
    }
    if (this.pages.length >= 50) {
      toast('一次最多 50 页');
      return;
    }
    this.pages.push(applyFilter(this.warped, this.filter));
    this.pageCount = this.pages.length;
    this.warped = null;
    if (!finish) {
      this.stage = 0;
      this.message = '已加入第 ' + this.pageCount + ' 页，继续拍摄';
      return;
    }
    this.saveCollected();
  }

  private finishCollected(): void {
    if (this.warped !== null) {
      this.addPage(true);
      return;
    }
    this.saveCollected();
  }

  private saveCollected(): void {
    if (this.pages.length === 0) {
      toast('还没有可保存的页面');
      return;
    }
    const saved = AppHost.imagesToPdf(this.pages, this.docName);
    toast('已生成 ' + saved.name);
    this.pages = [];
    this.pageCount = 0;
    this.stage = 0;
    this.message = '可以继续扫描下一份';
  }
}
