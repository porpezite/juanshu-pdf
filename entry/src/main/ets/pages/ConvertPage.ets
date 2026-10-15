import { router } from '@kit.ArkUI';
import { DocSummary } from 'juanshu_core';
import { TitleBar, stampName, toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';

class ConvertRoute {
  docId: string = '';
}

@Entry
@Component
struct ConvertPage {
  @State docId: string = '';
  @State title: string = '未选择文档';
  @State pageIndex: number = 0;
  @State pageCount: number = 1;
  @State output: string = '';
  @State draft: string = '';
  @State files: DocSummary[] = [];
  @State busy: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams();
    if (params !== undefined && params !== null) {
      const route = params as ConvertRoute;
      if (route.docId !== undefined && route.docId.length > 0) {
        this.docId = route.docId;
      }
    }
    this.reload();
  }

  build() {
    Column() {
      TitleBar({ title: '转换识别' })
      Scroll() {
        Column() {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text('第 ' + (this.pageIndex + 1) + ' / ' + this.pageCount + ' 页')
            .fontSize(12)
            .fontColor('#6E6A62')
            .margin({ top: 4, bottom: 12 })
          this.docPicker()
          Button(this.busy ? '正在识别…' : '识别本页')
            .width('100%')
            .height(46)
            .margin({ top: 12 })
            .backgroundColor('#1F6B4A')
            .fontColor('#FFFFFF')
            .enabled(!this.busy)
            .onClick(() => {
              this.runOcr();
            })
          Text('中英文识别使用 Core Vision Kit。没有该能力时会提示，不会伪造文字。')
            .fontSize(12)
            .fontColor('#6E6A62')
            .margin({ top: 8 })
          TextArea({ text: this.output, placeholder: '识别结果或导出的正文会出现在这里' })
            .width('100%')
            .height(160)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
          Button('导出正文')
            .width('100%')
            .height(44)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .fontColor('#1F6B4A')
            .onClick(() => {
              this.exportText();
            })
          Button('把正文存成新 PDF')
            .width('100%')
            .height(44)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .fontColor('#1C1B19')
            .onClick(() => {
              this.saveTextPdf();
            })
          Button('导出页面图片')
            .width('100%')
            .height(44)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .fontColor('#1C1B19')
            .onClick(() => {
              this.exportImages();
            })
          Text('图片或文字生成 PDF')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 20 })
            .width('100%')
          Button('从相册生成 PDF')
            .width('100%')
            .height(44)
            .margin({ top: 8 })
            .backgroundColor('#1F6B4A')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.imagesToPdf();
            })
          TextArea({ text: this.draft, placeholder: '输入要转成 PDF 的文字，支持中文' })
            .width('100%')
            .height(120)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => {
              this.draft = value;
            })
          Button('文字生成 PDF')
            .width('100%')
            .height(44)
            .margin({ top: 8 })
            .backgroundColor('#154832')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.draftToPdf();
            })
          Row() {
            Button('上一页')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#FFFFFF')
              .onClick(() => {
                this.shift(-1);
              })
            Button('下一页')
              .layoutWeight(1)
              .height(40)
              .margin({ left: 8 })
              .backgroundColor('#FFFFFF')
              .onClick(() => {
                this.shift(1);
              })
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  @Builder
  docPicker() {
    Scroll() {
      Row() {
        ForEach(this.files, (item: DocSummary) => {
          Text(item.name)
            .fontSize(13)
            .fontColor(item.id === this.docId ? '#FFFFFF' : '#1C1B19')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ right: 8 })
            .borderRadius(12)
            .backgroundColor(item.id === this.docId ? '#1F6B4A' : '#FFFFFF')
            .onClick(() => {
              this.docId = item.id;
              this.pageIndex = 0;
              this.bindSummary();
            })
        }, (item: DocSummary) => item.id)
      }
      .height(44)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  private reload(): void {
    this.files = AppHost.list();
    this.bindSummary();
  }

  private bindSummary(): void {
    const item = AppHost.find(this.docId);
    if (item === null) {
      this.title = this.files.length === 0 ? '还没有文档' : '请选择文档';
      this.pageCount = 1;
      return;
    }
    this.title = item.name;
    this.pageCount = Math.max(1, item.pageCount);
  }

  private shift(delta: number): void {
    const next = this.pageIndex + delta;
    if (next < 0 || next >= this.pageCount) {
      return;
    }
    this.pageIndex = next;
  }

  private async runOcr(): Promise<void> {
    if (this.docId.length === 0) {
      toast('先选择文档');
      return;
    }
    if (!AppHost.ocr().available()) {
      toast('这台设备没有 Core Vision Kit 文字识别');
      return;
    }
    this.busy = true;
    const text = await AppHost.recognizePage(this.docId, this.pageIndex);
    this.busy = false;
    if (text.length === 0) {
      toast('没有识别到文字');
      return;
    }
    this.output = text;
    toast('识别完成');
  }

  private exportText(): void {
    if (this.docId.length === 0) {
      return;
    }
    const text = AppHost.textOf(this.docId);
    this.output = text.length > 0 ? text : this.output;
    if (this.output.length === 0) {
      toast('这份文档还没有文字层');
      return;
    }
    toast('正文已显示，可存成新 PDF');
  }

  private saveTextPdf(): void {
    if (this.output.trim().length === 0) {
      toast('没有可保存的文字');
      return;
    }
    const saved = AppHost.textToPdf(this.output, stampName('文本'));
    toast('已保存 ' + saved.name);
    this.reload();
  }

  private exportImages(): void {
    if (this.docId.length === 0) {
      return;
    }
    const paths = AppHost.exportImages(this.docId);
    if (paths.length === 0) {
      toast('没有导出图片。外部 PDF 需要 PDF Kit');
      return;
    }
    toast('已导出 ' + paths.length + ' 张图片');
  }

  private async imagesToPdf(): Promise<void> {
    const uris = await AppHost.album().pickFromAlbum(20);
    if (uris.length === 0) {
      return;
    }
    const images = await AppHost.capture().readImages(uris);
    if (images.length === 0) {
      toast('没有读到图片');
      return;
    }
    const saved = AppHost.imagesToPdf(images, stampName('图片'));
    toast('已生成 ' + saved.name);
    this.reload();
  }

  private draftToPdf(): void {
    if (this.draft.trim().length === 0) {
      toast('先输入文字');
      return;
    }
    const saved = AppHost.textToPdf(this.draft, stampName('文稿'));
    toast('已生成 ' + saved.name);
    this.draft = '';
    this.reload();
  }
}
