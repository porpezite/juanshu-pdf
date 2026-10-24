import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AppHost } from '../platform/AppHost';

const DOMAIN = 0xA710;
const TAG = 'JuanshuPdf';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppHost.init(this.context);
    hilog.info(DOMAIN, TAG, '卷舒 PDF onCreate ability=%{public}s', want.abilityName ?? '');
    hilog.info(DOMAIN, TAG, 'launch reason=%{public}d', launchParam.launchReason);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#FFFFFF');
      win.setWindowLayoutFullScreen(true).then(() => {
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#182431',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#182431'
        });
        this.publishAvoidArea(win);
        this.loadIndex(windowStage);
      }).catch(() => {
        hilog.error(DOMAIN, TAG, 'fullscreen layout failed');
        this.loadIndex(windowStage);
      });
    }).catch(() => {
      hilog.error(DOMAIN, TAG, 'window style failed');
      this.loadIndex(windowStage);
    });
  }

  private publishAvoidArea(win: window.Window): void {
    let density = 1;
    try {
      const pixels = display.getDefaultDisplaySync().densityPixels;
      if (pixels > 0) {
        density = pixels;
      }
    } catch (err) {
      density = 1;
    }
    const top = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height / density;
    const bottom = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height / density;
    AppStorage.setOrCreate('statusBarHeight', top);
    AppStorage.setOrCreate('navIndicatorHeight', bottom);
  }

  private loadIndex(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'load Index failed code=%{public}d', err.code);
        return;
      }
      hilog.info(DOMAIN, TAG, 'Index loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'window destroyed');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'foreground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'background');
  }
}
