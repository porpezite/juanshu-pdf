import { router } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { DocSummary } from 'juanshu_core';
import { AppHost } from '../platform/AppHost';
import { OfficialScanner } from '../components/OfficialScanner';
import { toast } from '../components/Chrome';

@Component
struct ToolRow {
  label: string = '';
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(16)
        .fontColor('#1C1B19')
        .layoutWeight(1)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      this.onTap();
    })
  }
}

@Entry
@Component
struct Index {
  @State section: number = 0;
  @State query: string = '';
  @State docs: DocSummary[] = [];
  @State currentBreakpoint: string = 'sm';
  @State shotLimit: number = 20;
  @State scanEpoch: number = 0;
  private stack: NavPathStack = new NavPathStack();
  private tabsController: TabsController = new TabsController();
  @State folders: string[] = ['扫描证件', '扫描书籍'];

  aboutToAppear(): void {
    this.reloadDocs();
  }

  onPageShow(): void {
    this.reloadDocs();
  }

  build() {
    GridRow({
      columns: { xs: 4, sm: 4, md: 8, lg: 12 },
      breakpoints: {
        value: ['320vp', '600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: { xs: 4, sm: 4, md: 8, lg: 12 } }) {
        if (this.isWide()) {
          this.wideShell()
        } else {
          this.phoneTabs()
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
      if (this.isWide() && this.stack.size() === 0) {
        this.stack.pushPathByName(this.sectionName(), '');
      }
    })
  }

  @Builder
  phoneTabs() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.section }) {
      TabContent() {
        this.docsPane()
      }
      .tabBar(this.plainTab('文档', 0))

      TabContent() {
        this.toolsPane()
      }
      .tabBar(this.plainTab('工具', 1))

      TabContent() {
        if (this.section === 2) {
          this.scannerPane()
        }
      }
      .tabBar(this.scanTab())

      TabContent() {
        this.minePane()
      }
      .tabBar(this.plainTab('我的', 3))
    }
    .barMode(BarMode.Fixed)
    .barHeight(64)
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
    .onChange((index: number) => {
      this.section = index;
    })
  }

  @Builder
  wideShell() {
    Navigation(this.stack) {
      Column() {
        Text('卷舒 PDF')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1B19')
          .width('100%')
          .padding({ left: 16, top: 20, bottom: 12 })
        List() {
          this.sideRow('文档', 0)
          this.sideRow('工具', 1)
          this.sideRow('扫描', 2)
          this.sideRow('我的', 3)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
    }
    .mode(NavigationMode.Split)
    .navBarWidth(240)
    .hideTitleBar(true)
    .navDestination(this.destination)
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  @Builder
  sideRow(label: string, index: number) {
    ListItem() {
      Text(label)
        .fontSize(16)
        .fontColor(this.section === index ? '#1F6B4A' : '#1C1B19')
        .fontWeight(this.section === index ? FontWeight.Medium : FontWeight.Normal)
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
    }
    .onClick(() => {
      this.openSection(label, index);
    })
  }

  @Builder
  destination(name: string) {
    if (name === '工具') {
      NavDestination() {
        this.toolsPane()
      }
      .hideTitleBar(true)
    } else if (name === '扫描') {
      NavDestination() {
        this.scannerPane()
      }
      .hideTitleBar(true)
    } else if (name === '我的') {
      NavDestination() {
        this.minePane()
      }
      .hideTitleBar(true)
    } else {
      NavDestination() {
        this.docsPane()
      }
      .hideTitleBar(true)
    }
  }

  @Builder
  plainTab(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(this.section === index ? '#1F6B4A' : '#6E6A62')
        .fontWeight(this.section === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  scanTab() {
    Column() {
      Column() {
        Text('扫描')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1F6B4A')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  docsPane() {
    Column() {
      Row() {
        Search({ value: this.query, placeholder: '文档' })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.query = value;
            this.reloadDocs();
          })
        Button('导入')
          .width(72)
          .height(40)
          .margin({ left: 8 })
          .fontSize(14)
          .backgroundColor('#1F6B4A')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.importDoc();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      Text('文件夹')
        .fontSize(13)
        .fontColor('#6E6A62')
        .width('100%')
        .margin({ left: 16, top: 16, bottom: 8 })

      List({ space: 12 }) {
        ForEach(this.folders, (name: string) => {
          ListItem() {
            Text(name)
              .fontSize(15)
              .fontColor('#1C1B19')
              .width(132)
              .height(72)
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
          }
          .onClick(() => {
            this.openFolder(name);
          })
        }, (name: string) => name)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(88)
      .margin({ left: 16 })
      .scrollBar(BarState.Off)

      Text('最近')
        .fontSize(13)
        .fontColor('#6E6A62')
        .width('100%')
        .margin({ left: 16, top: 8, bottom: 8 })

      if (this.docs.length === 0) {
        Text('最近还没有文档')
          .fontSize(15)
          .fontColor('#1C1B19')
          .width('100%')
          .padding({ left: 16, top: 12 })
      } else {
        List({ space: 8 }) {
          ForEach(this.docs, (item: DocSummary) => {
            ListItem() {
              this.docRow(item)
            }
            .onClick(() => {
              this.openDoc(item.id);
            })
          }, (item: DocSummary) => item.id + ':' + item.updatedAt)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F4EF')
  }

  @Builder
  docRow(item: DocSummary) {
    Row() {
      Column() {
        Text(String(item.pageCount))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F6B4A')
        Text('页')
          .fontSize(11)
          .fontColor('#6E6A62')
          .margin({ top: 2 })
      }
      .width(52)
      .height(68)
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#E7F2EC')

      Column() {
        Text(item.name)
          .fontSize(16)
          .fontColor('#1C1B19')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.pageCount + ' 页')
          .fontSize(12)
          .fontColor('#6E6A62')
          .margin({ top: 4 })
        Text(this.formatWhen(item.updatedAt))
          .fontSize(12)
          .fontColor('#6E6A62')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  toolsPane() {
    List() {
      ListItemGroup({ header: this.headRecognize }) {
        ListItem() {
          ToolRow({
            label: '提取文字',
            onTap: () => {
              this.openConvert('text');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '扫描证件',
            onTap: () => {
              this.openIdScan();
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '扫描书籍',
            onTap: () => {
              this.openBookScan();
            }
          })
        }
      }
      ListItemGroup({ header: this.headPdf }) {
        ListItem() {
          ToolRow({
            label: '合并',
            onTap: () => {
              this.openManage('merge');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '拆分',
            onTap: () => {
              this.openManage('split');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '压缩',
            onTap: () => {
              this.openManage('compress');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '页序',
            onTap: () => {
              this.openManage('order');
            }
          })
        }
      }
      ListItemGroup({ header: this.headExport }) {
        ListItem() {
          ToolRow({
            label: '转 Word',
            onTap: () => {
              this.openConvert('word');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '转图片',
            onTap: () => {
              this.openConvert('image');
            }
          })
        }
        ListItem() {
          ToolRow({
            label: '分享',
            onTap: () => {
              this.shareRecent();
            }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 16 })
    .backgroundColor('#F6F4EF')
    .scrollBar(BarState.Off)
  }

  @Builder
  headRecognize() {
    Text('扫描与识别')
      .fontSize(13)
      .fontColor('#6E6A62')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })
  }

  @Builder
  headPdf() {
    Text('PDF处理')
      .fontSize(13)
      .fontColor('#6E6A62')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })
  }

  @Builder
  headExport() {
    Text('转换导出')
      .fontSize(13)
      .fontColor('#6E6A62')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })
  }

  @Builder
  scannerPane() {
    OfficialScanner({
      shotLimit: this.shotLimit,
      onSaved: () => {
        this.reloadDocs();
        this.openSection('文档', 0);
      }
    })
      .key('scan' + this.scanEpoch)
      .width('100%')
      .height('100%')
  }

  @Builder
  minePane() {
    Column() {
      Text('卷舒 PDF')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1B19')
        .width('100%')
        .margin({ bottom: 12 })
      Row() {
        this.planCard('Free', true)
        this.planCard('Plus', false)
        this.planCard('Pro', false)
      }
      .width('100%')
      .margin({ bottom: 16 })

      List() {
        ListItem() {
          Column() {
            Text('本地优先')
              .fontSize(16)
              .fontColor('#1C1B19')
              .width('100%')
            Text('文档保存在这台设备上，打开和扫描不要求上传。')
              .fontSize(13)
              .fontColor('#6E6A62')
              .width('100%')
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }
        ListItem() {
          Text('取消订阅')
            .fontSize(16)
            .fontColor('#1C1B19')
            .width('100%')
            .padding(16)
            .margin({ top: 8 })
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .onClick(() => {
              toast('当前是 Free，没有需要取消的订阅。');
            })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F6F4EF')
  }

  @Builder
  planCard(name: string, current: boolean) {
    Text(name)
      .fontSize(14)
      .fontWeight(current ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(current ? '#FFFFFF' : '#1C1B19')
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(44)
      .margin({ right: 8 })
      .borderRadius(12)
      .backgroundColor(current ? '#1F6B4A' : '#FFFFFF')
  }

  private isWide(): boolean {
    if (this.currentBreakpoint === 'xs' || this.currentBreakpoint === 'sm') {
      return false;
    }
    return true;
  }

  private sectionName(): string {
    if (this.section === 1) {
      return '工具';
    }
    if (this.section === 2) {
      return '扫描';
    }
    if (this.section === 3) {
      return '我的';
    }
    return '文档';
  }

  private openSection(name: string, index: number): void {
    this.section = index;
    if (this.isWide()) {
      if (this.stack.size() > 0) {
        this.stack.clear();
      }
      this.stack.pushPathByName(name, '');
      return;
    }
    this.tabsController.changeIndex(index);
  }

  private openFolder(name: string): void {
    if (name === '扫描书籍') {
      this.openBookScan();
      return;
    }
    this.openIdScan();
  }

  private openIdScan(): void {
    this.shotLimit = 2;
    this.scanEpoch = this.scanEpoch + 1;
    this.openSection('扫描', 2);
  }

  private openBookScan(): void {
    this.shotLimit = 20;
    this.scanEpoch = this.scanEpoch + 1;
    this.openSection('扫描', 2);
  }

  private reloadDocs(): void {
    if (this.query.length === 0) {
      this.docs = AppHost.recent(50);
      return;
    }
    this.docs = AppHost.search(this.query);
  }

  private async importDoc(): Promise<void> {
    const saved = await AppHost.pickPdf();
    if (saved === null) {
      return;
    }
    toast('已导入');
    this.reloadDocs();
  }

  private openDoc(id: string): void {
    router.pushUrl({ url: 'pages/EditPage', params: { docId: id } });
  }

  private openConvert(tool: string): void {
    router.pushUrl({ url: 'pages/ConvertPage', params: { tool: tool } });
  }

  private openManage(tool: string): void {
    router.pushUrl({ url: 'pages/ManagePage', params: { tool: tool } });
  }

  private async shareRecent(): Promise<void> {
    const recent = AppHost.recent(1);
    if (recent.length === 0) {
      toast('最近还没有文档');
      return;
    }
    const context = AppHost.context();
    if (context === null) {
      return;
    }
    try {
      const uri = fileUri.getUriFromPath(AppHost.path(recent[0].id));
      const shared: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.FILE,
        uri: uri,
        title: recent[0].name
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(shared);
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (err) {
      toast('分享没有打开');
    }
  }

  private formatWhen(ms: number): string {
    const date = new Date(ms);
    return date.getFullYear() + '-' + this.two(date.getMonth() + 1) + '-' + this.two(date.getDate()) +
      ' ' + this.two(date.getHours()) + ':' + this.two(date.getMinutes());
  }

  private two(value: number): string {
    if (value < 10) {
      return '0' + value;
    }
    return String(value);
  }
}
