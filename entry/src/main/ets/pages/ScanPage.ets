import { router } from '@kit.ArkUI';
import { DocScanner } from '../components/DocScanner';

@Entry
@Component
struct ScanPage {
  build() {
    DocScanner({
      onSaved: () => {
        router.back();
      }
    })
      .width('100%')
      .height('100%')
  }
}
