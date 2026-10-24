import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { EditRoute } from '../common/NavRoutes';
import { AppHost } from '../platform/AppHost';

const TAG = 'PDFView';

@Component
struct EditPage {
  @State docTitle: string = '文档';
  private controller: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private filePath: string = '';

  build() {
    HdsNavDestination() {
      Row() {
        PdfView({
          controller: this.controller,
          pageFit: pdfService.PageFit.FIT_WIDTH,
          showScroll: true
        })
          .id('pdfview_app_view')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      content: { title: { mainTitle: this.docTitle } }
    })
    .backgroundColor(Color.White)
    .onReady((ctx: NavDestinationContext) => {
      this.readParam(ctx.pathInfo.param);
      this.loadPdf();
    })
  }

  private readParam(param: Object): void {
    if (param === undefined || param === null) {
      return;
    }
    const route = param as EditRoute;
    if (route.docId === undefined || route.docId.length === 0) {
      return;
    }
    this.filePath = AppHost.path(route.docId);
    const found = AppHost.find(route.docId);
    if (found !== null) {
      this.docTitle = found.name;
    }
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

@Builder
export function EditPageBuilder(name: string, param: Object) {
  if (name.length >= 0 && param !== undefined) {
    EditPage()
  }
}
