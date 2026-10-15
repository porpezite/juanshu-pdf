import { DocType, DocumentScanner, DocumentScannerConfig, FilterId, SaveOption, ShootingMode } from '@kit.VisionKit';
import { AppHost } from '../platform/AppHost';
import { stampName, toast } from './Chrome';

/** 全屏使用 Vision Kit 文档扫描控件。默认滤镜是原图。 */
@Component
export struct OfficialScanner {
  @Prop shotLimit: number = 20;
  onSaved: () => void = () => {
  };
  private scannerConfig: DocumentScannerConfig = new DocumentScannerConfig();
  @State supported: boolean = true;
  @State armed: boolean = false;

  aboutToAppear(): void {
    this.supported = canIUse('SystemCapability.AI.Component.DocScan');
    this.scannerConfig.supportType = [DocType.DOC];
    this.scannerConfig.isGallerySupported = true;
    this.scannerConfig.maxShotCount = this.shotLimit;
    this.scannerConfig.defaultFilterId = FilterId.ORIGINAL;
    this.scannerConfig.defaultShootingMode = ShootingMode.MANUAL;
    this.scannerConfig.saveOptions = [SaveOption.PDF, SaveOption.JPG];
    this.armed = true;
  }

  build() {
    Column() {
      if (!this.supported) {
        Column() {
          Text('当前设备没有文档扫描控件')
            .fontSize(16)
            .fontColor('#1C1B19')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else if (this.armed) {
        DocumentScanner({
          scannerConfig: this.scannerConfig,
          onResult: (code: number, saveType: SaveOption, uris: string[]) => {
            this.onResult(code, saveType, uris);
          }
        })
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  private async onResult(code: number, saveType: SaveOption, uris: string[]): Promise<void> {
    if (code !== 200 || uris.length === 0) {
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
