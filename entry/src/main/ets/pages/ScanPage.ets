import { router } from '@kit.ArkUI';
import { OfficialScanner } from '../components/OfficialScanner';

@Entry
@Component
struct ScanPage {
  build() {
    Column() {
      OfficialScanner({
        shotLimit: 20,
        onSaved: () => {
          router.back();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
