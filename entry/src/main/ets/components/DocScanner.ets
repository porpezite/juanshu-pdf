import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DocType,
  DocumentScanner,
  DocumentScannerConfig,
  FilterId,
  SaveOption,
  ShootingMode
} from '@kit.VisionKit';
import { AppHost } from '../platform/AppHost';
import { stampName, toast } from './Chrome';

const TAG: string = 'DocDemoPage';

/**
 * 与 Vision Kit 示例 DocDemoPage 相同的扫描页。
 * 结果写进本机文档库，不再画裁切框或快门。
 */
@Component
export struct DocScanner {
  @State docImageUris: string[] = [];
  onSaved: () => void = () => {
  };
  private docScanConfig: DocumentScannerConfig = new DocumentScannerConfig();

  aboutToAppear(): void {
    this.docScanConfig.supportType = [DocType.DOC, DocType.SHEET];
    this.docScanConfig.isGallerySupported = true;
    this.docScanConfig.editTabs = [];
    this.docScanConfig.maxShotCount = 3;
    this.docScanConfig.defaultFilterId = FilterId.ORIGINAL;
    this.docScanConfig.defaultShootingMode = ShootingMode.MANUAL;
    this.docScanConfig.isShareable = true;
    this.docScanConfig.originalUris = [];
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      DocumentScanner({
        scannerConfig: this.docScanConfig,
        onResult: (code: number, saveType: SaveOption, uris: string[]) => {
          hilog.info(0x0001, TAG, 'result code: ' + code + ', save: ' + saveType);
          for (let i = 0; i < uris.length; i++) {
            hilog.info(0x0001, TAG, 'uri: ' + uris[i]);
          }
          this.docImageUris = uris;
          this.keep(uris, saveType);
        }
      })
        .size({ width: '100%', height: '100%' })
    }
    .width('100%')
    .height('100%')
  }

  private async keep(uris: string[], saveType: SaveOption): Promise<void> {
    if (uris.length === 0) {
      return;
    }
    if (saveType === SaveOption.PDF) {
      const bytes = await AppHost.capture().readBytes(uris[0]);
      if (bytes === null) {
        toast('没有读到扫描结果');
        return;
      }
      const saved = AppHost.importBytes(stampName('扫描'), bytes);
      if (saved === null) {
        toast('导入失败');
        return;
      }
      toast('已导入');
      this.onSaved();
      return;
    }
    const images = await AppHost.capture().readImages(uris);
    if (images.length === 0) {
      toast('没有读到扫描结果');
      return;
    }
    AppHost.imagesToPdf(images, stampName('扫描'));
    toast('已导入');
    this.onSaved();
  }
}
