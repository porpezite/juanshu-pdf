import { image } from '@kit.ImageKit';
import { router } from '@kit.ArkUI';
import { pdfService, PdfView, pdfViewManager } from '@kit.PDFKit';
import {
  AnnKind, Annotation, DocSummary, PdfDocumentModel, Point, rasterizeStroke, renderPage
} from 'juanshu_core';
import { TitleBar, toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';
import { toPixelMap } from '../platform/PixelBridge';

class EditRoute {
  docId: string = '';
}

@Entry
@Component
struct EditPage {
  @State docId: string = '';
  @State title: string = '选择文档';
  @State pageIndex: number = 0;
  @State pageCount: number = 0;
  @State tool: number = AnnKind.HIGHLIGHT;
  @State draft: string = '';
  @State showEntry: boolean = false;
  @State signing: boolean = false;
  @State external: boolean = false;
  @State files: DocSummary[] = [];
  @State body: string = '';
  @State marks: string[] = [];
  @State preview: image.PixelMap | undefined = undefined;
  private model: PdfDocumentModel | null = null;
  private controller: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private anchorX: number = 0;
  private anchorY: number = 0;
  private areaWidth: number = 1;
  private areaHeight: number = 1;
  private stroke: Point[] = [];
  private signStroke: Point[] = [];

  aboutToAppear(): void {
    const params = router.getParams();
    if (params !== undefined && params !== null) {
      const route = params as EditRoute;
      if (route.docId !== undefined && route.docId.length > 0) {
        this.docId = route.docId;
      }
    }
    this.reload();
  }

  build() {
    Column() {
      TitleBar({
        title: this.docId.length > 0 ? this.title : '文档',
        action: '',
        onAction: () => {
        }
      })
      if (this.docId.length === 0) {
        this.picker()
      } else {
        PdfView({
          controller: this.controller,
          pageFit: pdfService.PageFit.FIT_WIDTH
        })
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#E7E2D8')
        this.pageButtons()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  @Builder
  picker() {
    Scroll() {
      Column() {
        Text('文档')
          .fontSize(14)
          .fontColor('#6E6A62')
          .width('100%')
          .margin({ bottom: 12 })
        Button('新建空白文稿')
          .width('100%')
          .height(44)
          .backgroundColor('#1F6B4A')
          .fontColor('#FFFFFF')
          .onClick(() => {
            const created = AppHost.newBlank('未命名文稿');
            this.docId = created.id;
            this.reload();
          })
        ForEach(this.files, (item: DocSummary) => {
          Text(item.name)
            .fontSize(15)
            .fontColor('#1C1B19')
            .width('100%')
            .padding(14)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .onClick(() => {
              this.docId = item.id;
              this.reload();
            })
        }, (item: DocSummary) => item.id)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .layoutWeight(1)
  }

  @Builder
  canvas() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(this.preview)
        .width('100%')
        .height(420)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#E7E2D8')
        .borderRadius(16)
    }
    .width('100%')
    .height(420)
    .gesture(
      PanGesture()
        .onActionStart((event: GestureEvent) => {
          this.anchorX = this.localX(event) / Math.max(1, this.areaWidth);
          this.anchorY = this.localY(event) / Math.max(1, this.areaHeight);
          this.stroke = [];
          this.stroke.push(new Point(this.anchorX, this.anchorY));
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.tool === AnnKind.INK) {
            this.stroke.push(new Point(
              this.localX(event) / Math.max(1, this.areaWidth),
              this.localY(event) / Math.max(1, this.areaHeight)
            ));
          }
        })
        .onActionEnd((event: GestureEvent) => {
          this.finishDraw(this.localX(event) / Math.max(1, this.areaWidth),
            this.localY(event) / Math.max(1, this.areaHeight));
        })
    )
    .onAreaChange((_old, area) => {
      this.areaWidth = Number(area.width);
      this.areaHeight = Number(area.height);
    })
  }

  @Builder
  tools() {
    Flex({ wrap: FlexWrap.Wrap }) {
      this.toolChip('高亮', AnnKind.HIGHLIGHT)
      this.toolChip('下划线', AnnKind.UNDERLINE)
      this.toolChip('画笔', AnnKind.INK)
      this.toolChip('矩形', AnnKind.RECT)
      this.toolChip('椭圆', AnnKind.OVAL)
      this.toolChip('文字', AnnKind.TEXT)
      this.toolChip('批注', AnnKind.COMMENT)
      this.toolChip('签名', AnnKind.SIGNATURE)
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  toolChip(label: string, kind: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.tool === kind ? '#FFFFFF' : '#1C1B19')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .borderRadius(12)
      .backgroundColor(this.tool === kind ? '#1F6B4A' : '#FFFFFF')
      .onClick(() => {
        this.tool = kind;
        this.showEntry = kind === AnnKind.TEXT || kind === AnnKind.COMMENT;
        this.signing = kind === AnnKind.SIGNATURE;
        this.draft = '';
      })
  }

  @Builder
  entryPanel() {
    Column() {
      TextInput({ text: this.draft, placeholder: this.tool === AnnKind.TEXT ? '输入文字' : '输入批注' })
        .width('100%')
        .height(44)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.draft = value;
        })
      Button('放到页面')
        .width('100%')
        .height(40)
        .margin({ top: 8 })
        .backgroundColor('#1F6B4A')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.placeText();
        })
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  signPanel() {
    Column() {
      Text('在下方签名，然后放置到页面右下角')
        .fontSize(12)
        .fontColor('#6E6A62')
      Column()
        .width('100%')
        .height(120)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ top: 8 })
        .gesture(
          PanGesture()
            .onActionStart((event: GestureEvent) => {
              this.signStroke = [];
              this.signStroke.push(new Point(this.padX(event), this.padY(event)));
            })
            .onActionUpdate((event: GestureEvent) => {
              this.signStroke.push(new Point(this.padX(event), this.padY(event)));
            })
        )
      Button('放置签名')
        .width('100%')
        .height(40)
        .margin({ top: 8 })
        .backgroundColor('#1F6B4A')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.placeSignature();
        })
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  markList() {
    Column() {
      ForEach(this.marks, (label: string, index: number) => {
        Text((index + 1) + '. ' + label)
          .fontSize(13)
          .fontColor('#1C1B19')
          .width('100%')
          .margin({ top: 4 })
      }, (label: string, index: number) => index + ':' + label)
      if (this.marks.length > 0 && !this.external) {
        Text('撤销上一处')
          .fontSize(13)
          .fontColor('#1F6B4A')
          .margin({ top: 8 })
          .onClick(() => {
            this.undo();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 8 })
  }

  @Builder
  pageButtons() {
    Row() {
      Button('上一页')
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#FFFFFF')
        .fontColor('#1C1B19')
        .onClick(() => {
          this.changePage(-1);
        })
      Button('下一页')
        .layoutWeight(1)
        .height(40)
        .margin({ left: 8 })
        .backgroundColor('#FFFFFF')
        .fontColor('#1C1B19')
        .onClick(() => {
          this.changePage(1);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
  }

  private reload(): void {
    this.files = AppHost.list();
    if (this.docId.length === 0) {
      return;
    }
    const summary = AppHost.find(this.docId);
    if (summary === null) {
      this.docId = '';
      return;
    }
    this.title = summary.name;
    this.model = AppHost.load(this.docId);
    if (this.model !== null) {
      this.pageCount = this.model.pages.length;
      this.external = false;
    } else {
      this.pageCount = summary.pageCount;
      this.external = true;
    }
    this.loadNative();
  }

  private loadNative(): void {
    const path = AppHost.path(this.docId);
    this.controller.loadDocument(path).then((result: pdfService.ParseResult) => {
      if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
        toast('系统 PDF 预览没有打开这份文件');
      }
    }).catch(() => {
      toast('当前环境无法使用 PDF Kit 预览');
    });
  }

  private async showCurrent(): Promise<void> {
    if (this.model === null || this.pageIndex >= this.model.pages.length) {
      return;
    }
    const page = this.model.pages[this.pageIndex];
    this.body = page.text.length > 0 ? page.text : page.ocrText;
    const labels: string[] = [];
    for (let i = 0; i < page.annotations.length; i++) {
      labels.push(labelOf(page.annotations[i]));
    }
    this.marks = labels;
    this.preview = await toPixelMap(renderPage(page));
  }

  private save(): void {
    if (this.model === null) {
      toast(this.external ? '外部 PDF 的修改已写入文件' : '没有可保存的内容');
      return;
    }
    if (AppHost.saveExisting(this.docId, this.model)) {
      toast('已保存');
    }
  }

  private changePage(delta: number): void {
    const next = this.pageIndex + delta;
    if (next < 0 || next >= this.pageCount) {
      return;
    }
    this.pageIndex = next;
    this.controller.goToPage(next);
  }

  private finishDraw(x: number, y: number): void {
    if (this.tool === AnnKind.TEXT || this.tool === AnnKind.COMMENT || this.tool === AnnKind.SIGNATURE) {
      return;
    }
    const ann = new Annotation(this.tool);
    ann.color = this.tool === AnnKind.INK ? 0x15342A : 0xE0A106;
    if (this.tool === AnnKind.INK) {
      ann.points = this.stroke;
      this.commit(ann);
      return;
    }
    const left = Math.min(this.anchorX, x);
    const top = Math.min(this.anchorY, y);
    ann.x = left;
    ann.y = top;
    ann.w = Math.max(0.02, Math.abs(x - this.anchorX));
    ann.h = Math.max(0.02, Math.abs(y - this.anchorY));
    this.commit(ann);
  }

  private placeText(): void {
    if (this.draft.trim().length === 0) {
      return;
    }
    const ann = new Annotation(this.tool);
    ann.text = this.draft.trim();
    ann.x = 0.12;
    ann.y = 0.12 + Math.min(0.6, this.marks.length * 0.08);
    ann.w = 0.7;
    ann.h = 0.08;
    ann.fontSize = 16;
    ann.color = 0x1C1B19;
    this.commit(ann);
    this.draft = '';
    this.showEntry = false;
  }

  private placeSignature(): void {
    if (this.signStroke.length < 2) {
      toast('请先签名');
      return;
    }
    const image = rasterizeStroke(240, 100, this.signStroke, 0x15342A, 2);
    const ann = new Annotation(AnnKind.SIGNATURE);
    ann.image = image;
    ann.x = 0.48;
    ann.y = 0.72;
    ann.w = 0.42;
    ann.h = 0.16;
    this.commit(ann);
    this.signStroke = [];
    this.signing = false;
  }

  private commit(ann: Annotation): void {
    if (this.external || this.model === null) {
      const image = ann.image;
      if (AppHost.addNativeMarkup(this.docId, this.pageIndex, ann, image)) {
        toast('已写入 PDF');
        this.loadNative();
      } else {
        toast('系统 PDF 引擎没有写入成功');
      }
      return;
    }
    this.model.pages[this.pageIndex].annotations.push(ann);
    this.showCurrent();
  }

  private undo(): void {
    if (this.model === null) {
      return;
    }
    const list = this.model.pages[this.pageIndex].annotations;
    if (list.length === 0) {
      return;
    }
    list.pop();
    this.showCurrent();
  }

  private localX(event: GestureEvent): number {
    if (event.fingerList.length === 0) {
      return 0;
    }
    return event.fingerList[0].localX;
  }

  private localY(event: GestureEvent): number {
    if (event.fingerList.length === 0) {
      return 0;
    }
    return event.fingerList[0].localY;
  }

  private padX(event: GestureEvent): number {
    return Math.max(0, Math.min(1, this.localX(event) / 320));
  }

  private padY(event: GestureEvent): number {
    return Math.max(0, Math.min(1, this.localY(event) / 120));
  }
}

function labelOf(ann: Annotation): string {
  if (ann.type === AnnKind.TEXT) {
    return '文字 ' + ann.text;
  }
  if (ann.type === AnnKind.COMMENT) {
    return '批注 ' + ann.text;
  }
  if (ann.type === AnnKind.HIGHLIGHT) {
    return '高亮';
  }
  if (ann.type === AnnKind.UNDERLINE) {
    return '下划线';
  }
  if (ann.type === AnnKind.INK) {
    return '手写';
  }
  if (ann.type === AnnKind.RECT) {
    return '矩形';
  }
  if (ann.type === AnnKind.OVAL) {
    return '椭圆';
  }
  if (ann.type === AnnKind.SIGNATURE) {
    return '签名';
  }
  return '标记';
}
