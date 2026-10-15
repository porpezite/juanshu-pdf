import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

@Component
export struct TitleBar {
  title: string = '';
  action: string = '';
  onAction: () => void = () => {
  };

  build() {
    Row() {
      Text('返回')
        .fontSize(16)
        .fontColor('#1F6B4A')
        .width(48)
        .onClick(() => {
          router.back();
        })
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1B19')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text(this.action.length > 0 ? this.action : ' ')
        .fontSize(16)
        .fontColor('#1F6B4A')
        .width(48)
        .textAlign(TextAlign.End)
        .onClick(() => {
          if (this.action.length > 0) {
            this.onAction();
          }
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }
}

@Component
export struct ToolTile {
  title: string = '';
  detail: string = '';
  mark: string = '';
  onTap: () => void = () => {
  };

  build() {
    Column() {
      Text(this.mark)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F6B4A')
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor('#E7F2EC')
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1B19')
        .margin({ top: 12 })
      Text(this.detail)
        .fontSize(12)
        .fontColor('#6E6A62')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('48%')
    .padding(16)
    .margin({ bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .onClick(() => {
      this.onTap();
    })
  }
}

export function toast(message: string): void {
  try {
    promptAction.showToast({ message: message, duration: 1800 });
  } catch (err) {
  }
}

export function clamp01(value: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

export function stampName(prefix: string): string {
  const now = new Date();
  return prefix + now.getFullYear() + pad(now.getMonth() + 1) + pad(now.getDate()) + '_' +
    pad(now.getHours()) + pad(now.getMinutes());
}

function pad(value: number): string {
  if (value < 10) {
    return '0' + value;
  }
  return String(value);
}
