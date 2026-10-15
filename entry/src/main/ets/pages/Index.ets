import { router } from '@kit.ArkUI';
import { AppHost } from '../platform/AppHost';
import { ToolTile, stampName } from '../components/Chrome';
import { DocSummary } from 'juanshu_core';

@Entry
@Component
struct Index {
  @State recent: DocSummary[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  build() {
    Scroll() {
      Column() {
        this.header()
        this.tools()
        this.recentFiles()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
    .scrollBar(BarState.Off)
  }

  @Builder
  header() {
    Row() {
      Column() {
        Text('卷舒 PDF')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1B19')
        Text('扫描、编辑、转换、整理')
          .fontSize(14)
          .fontColor('#6E6A62')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text('卷')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F4EF')
      }
      .width(52)
      .height(52)
      .borderRadius(18)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1F6B4A')
    }
    .width('100%')
    .margin({ bottom: 22 })
  }

  @Builder
  tools() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      ToolTile({
        title: '扫描',
        detail: '拍照、裁边、滤镜',
        mark: '扫',
        onTap: () => {
          router.pushUrl({ url: 'pages/ScanPage' });
        }
      })
      ToolTile({
        title: '编辑',
        detail: '文字、批注、签名',
        mark: '编',
        onTap: () => {
          router.pushUrl({ url: 'pages/EditPage' });
        }
      })
      ToolTile({
        title: '转换识别',
        detail: 'OCR、图片与文本',
        mark: '识',
        onTap: () => {
          router.pushUrl({ url: 'pages/ConvertPage' });
        }
      })
      ToolTile({
        title: '文档',
        detail: '合并、拆分、压缩',
        mark: '档',
        onTap: () => {
          router.pushUrl({ url: 'pages/ManagePage' });
        }
      })
    }
    .width('100%')
  }

  @Builder
  recentFiles() {
    Column() {
      Row() {
        Text('最近文件')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1B19')
          .layoutWeight(1)
        Text('新建')
          .fontSize(14)
          .fontColor('#1F6B4A')
          .onClick(() => {
            const created = AppHost.newBlank(stampName('文稿'));
            this.openDoc(created.id);
          })
      }
      .width('100%')
      .margin({ top: 8, bottom: 10 })

      if (this.recent.length === 0) {
        Column() {
          Text('还没有文档')
            .fontSize(15)
            .fontColor('#1C1B19')
          Text('扫描一页，或新建一份文稿')
            .fontSize(13)
            .fontColor('#6E6A62')
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
      } else {
        ForEach(this.recent, (item: DocSummary) => {
          this.fileRow(item)
        }, (item: DocSummary) => item.id + ':' + item.updatedAt)
      }
    }
    .width('100%')
  }

  @Builder
  fileRow(item: DocSummary) {
    Row() {
      Column() {
        Text(item.kind === 0 ? '卷' : '外')
          .fontSize(12)
          .fontColor('#1F6B4A')
      }
      .width(36)
      .height(36)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#E7F2EC')

      Column() {
        Text(item.name)
          .fontSize(15)
          .fontColor('#1C1B19')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.pageCount + ' 页')
          .fontSize(12)
          .fontColor('#6E6A62')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .onClick(() => {
      this.openDoc(item.id);
    })
  }

  private reload(): void {
    this.recent = AppHost.recent(8);
  }

  private openDoc(id: string): void {
    router.pushUrl({ url: 'pages/EditPage', params: { docId: id } });
  }
}
