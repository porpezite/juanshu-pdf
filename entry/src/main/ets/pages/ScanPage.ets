import { HdsNavDestination } from '@kit.UIDesignKit';
import { DocScanner } from '../components/DocScanner';

/**
 * 全屏官方 DocumentScanner。不放标题栏，避免盖住系统扫描控件。
 * 离开扫描靠系统返回或结果回调。
 */
@Component
struct ScanPage {
  private stack: NavPathStack | null = null;

  build() {
    HdsNavDestination() {
      DocScanner({
        onSaved: () => {
          this.leave();
        },
        onClosed: () => {
          this.leave();
        }
      })
        .width('100%')
        .height('100%')
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
    })
    .width('100%')
    .height('100%')
  }

  private leave(): void {
    if (this.stack !== null) {
      this.stack.pop();
    }
  }
}

@Builder
export function ScanPageBuilder(name: string, param: Object) {
  if (name.length >= 0 && param !== undefined) {
    ScanPage()
  }
}
