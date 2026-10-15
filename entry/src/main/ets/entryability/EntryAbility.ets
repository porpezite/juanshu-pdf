import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
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
    try {
      windowStage.getMainWindow().then((win: window.Window) => {
        win.setWindowBackgroundColor('#F6F4EF');
        win.setWindowSystemBarProperties({
          statusBarColor: '#F6F4EF',
          statusBarContentColor: '#1C1B19',
          navigationBarColor: '#F6F4EF',
          navigationBarContentColor: '#1C1B19'
        });
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'window style failed');
    }
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
