import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { AppHost } from '../platform/AppHost';

const TAG = 'PDFView';

class EditRoute {
  docId: string = '';
}

@Entry
@Component
struct EditPage {
  private controller: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private filePath: string = '';

  aboutToAppear(): void {
    const params = router.getParams();
    if (params !== undefined && params !== null) {
      const route = params as EditRoute;
      if (route.docId !== undefined && route.docId.length > 0) {
        this.filePath = AppHost.path(route.docId);
      }
    }
    this.loadPdf();
  }

  @Builder
  Back() {
    Button('返回')
      .width(100)
      .fontSize(20)
      .padding({ left: 30, top: 8 })
      .margin({ left: 10, top: 10 })
      .onClick(() => {
        this.getUIContext().getRouter().back({ url: 'pages/Index' });
      })
  }

  build() {
    Row() {
      PdfView({
        controller: this.controller,
        pageFit: pdfService.PageFit.FIT_WIDTH,
        showScroll: true
      })
        .id('pdfview_app_view')
        .layoutWeight(1)
        .overlay(this.Back(), {
          align: Alignment.TopStart
        })
    }
    .width('100%')
    .height('100%')
  }

  private loadPdf(): void {
    if (this.filePath.length === 0) {
      hilog.error(0x0000, TAG, 'missing document path');
      return;
    }
    this.controller.loadDocument(this.filePath).then((loadResult: pdfService.ParseResult) => {
      if (loadResult === pdfService.ParseResult.PARSE_SUCCESS) {
        hilog.info(0x0000, TAG, 'PDF load successfully');
      }
    }).catch(() => {
      hilog.error(0x0000, TAG, 'PDF load failed');
    });
  }
}
