import { router } from '@kit.ArkUI';
import { AppHost } from '../platform/AppHost';
import { BottomItem, SideItem, ToolTile, stampName } from '../components/Chrome';
import { DocSummary } from 'juanshu_core';

@Entry
@Component
struct Index {
  @State recent: DocSummary[] = [];
  @State currentBreakpoint: string = 'sm';

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  build() {
    GridRow({
      columns: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12, xxl: 12 },
      breakpoints: {
        value: ['320vp', '600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12, xxl: 12 } }) {
        if (this.isWide()) {
          this.wideShell()
        } else {
          this.phoneShell()
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
    .onBreakpointChange((breakpoint: string) => {
      this.currentBreakpoint = breakpoint;
    })
  }

  @Builder
  phoneShell() {
    Column() {
      Scroll() {
        Column() {
          this.header()
          this.toolGrid()
          this.recentFiles()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      this.bottomNav()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  wideShell() {
    GridRow({
      columns: { xs: 4, sm: 4, md: 8, lg: 12, xl: 12, xxl: 12 },
      gutter: { x: 12 },
      breakpoints: {
        value: ['320vp', '600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: { xs: 4, sm: 4, md: 3, lg: 3, xl: 3, xxl: 3 } }) {
        this.sideBar()
      }
      .height('100%')

      GridCol({ span: { xs: 4, sm: 4, md: 5, lg: 9, xl: 9, xxl: 9 } }) {
        Scroll() {
          Column() {
            Text('扫描、编辑、转换、整理')
              .fontSize(14)
              .fontColor('#6E6A62')
              .width('100%')
              .margin({ bottom: 16 })
            this.recentFiles()
          }
          .width('100%')
          .padding({ left: 12, right: 28, top: 24, bottom: 28 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  sideBar() {
    Column() {
      Row() {
        Column() {
          Text('卷')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F4EF')
        }
        .width(44)
        .height(44)
        .borderRadius(14)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1F6B4A')
        Text('卷舒 PDF')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1B19')
          .margin({ left: 10 })
      }
      .width('100%')
      .margin({ bottom: 22 })

      SideItem({
        mark: '扫',
        title: '扫描',
        onTap: () => {
          this.openScan();
        }
      })
      SideItem({
        mark: '编',
        title: '编辑',
        onTap: () => {
          this.openEdit();
        }
      })
      SideItem({
        mark: '识',
        title: '转换识别',
        onTap: () => {
          this.openConvert();
        }
      })
      SideItem({
        mark: '档',
        title: '文档',
        onTap: () => {
          this.openManage();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
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
  toolGrid() {
    GridRow({
      columns: { xs: 4, sm: 4, md: 8, lg: 12 },
      gutter: { x: 12, y: 12 },
      breakpoints: {
        value: ['320vp', '600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: { xs: 2, sm: 2, md: 4, lg: 3 } }) {
        ToolTile({
          title: '扫描',
          detail: '拍照、裁边、滤镜',
          mark: '扫',
          onTap: () => {
            this.openScan();
          }
        })
      }
      GridCol({ span: { xs: 2, sm: 2, md: 4, lg: 3 } }) {
        ToolTile({
          title: '编辑',
          detail: '文字、批注、签名',
          mark: '编',
          onTap: () => {
            this.openEdit();
          }
        })
      }
      GridCol({ span: { xs: 2, sm: 2, md: 4, lg: 3 } }) {
        ToolTile({
          title: '转换识别',
          detail: 'OCR、图片与文本',
          mark: '识',
          onTap: () => {
            this.openConvert();
          }
        })
      }
      GridCol({ span: { xs: 2, sm: 2, md: 4, lg: 3 } }) {
        ToolTile({
          title: '文档',
          detail: '合并、拆分、压缩',
          mark: '档',
          onTap: () => {
            this.openManage();
          }
        })
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  bottomNav() {
    Column() {
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#E7E2D8')
      Flex({ justifyContent: FlexAlign.SpaceEvenly, alignItems: ItemAlign.Center }) {
        BottomItem({
          mark: '扫',
          title: '扫描',
          onTap: () => {
            this.openScan();
          }
        })
        BottomItem({
          mark: '编',
          title: '编辑',
          onTap: () => {
            this.openEdit();
          }
        })
        BottomItem({
          mark: '识',
          title: '识别',
          onTap: () => {
            this.openConvert();
          }
        })
        BottomItem({
          mark: '档',
          title: '文档',
          onTap: () => {
            this.openManage();
          }
        })
      }
      .width('100%')
      .height(62)
      .backgroundColor('#FFFFFF')
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

  private isWide(): boolean {
    if (this.currentBreakpoint === 'xs' || this.currentBreakpoint === 'sm') {
      return false;
    }
    return true;
  }

  private reload(): void {
    this.recent = AppHost.recent(8);
  }

  private openScan(): void {
    router.pushUrl({ url: 'pages/ScanPage' });
  }

  private openEdit(): void {
    router.pushUrl({ url: 'pages/EditPage' });
  }

  private openConvert(): void {
    router.pushUrl({ url: 'pages/ConvertPage' });
  }

  private openManage(): void {
    router.pushUrl({ url: 'pages/ManagePage' });
  }

  private openDoc(id: string): void {
    router.pushUrl({ url: 'pages/EditPage', params: { docId: id } });
  }
}
