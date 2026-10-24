import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { HdsNavigation, HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { DocSummary } from 'juanshu_core';
import { BreakpointConstants } from '../common/BreakpointConstants';
import { ConvertRoute, EditRoute, ManageRoute, ScanRoute } from '../common/NavRoutes';
import { toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';

@Component
struct NewsCard {
  label: string = '';
  detail: string = '';
  thumb: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Row() {
      Column() {
        Text(this.label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.fontColor_text3'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(12)
            .fontColor($r('app.color.news_time_fontColor'))
            .maxLines(1)
            .margin({ top: 8 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: this.thumb ? 12 : 0 })

      if (this.thumb) {
        Image($r('app.media.app_icon'))
          .width(108)
          .height(80)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct MineShortcut {
  label: string = '';
  icon: ResourceStr = '';
  onTap: () => void = () => {
  };

  build() {
    Column() {
      Image(this.icon)
        .width(40)
        .height(40)
      Text(this.label)
        .fontSize(12)
        .fontColor($r('app.color.news_time_fontColor'))
        .maxLines(1)
        .margin({ top: 8 })
    }
    .width(72)
    .padding({ top: 16, bottom: 12 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
struct NewsFrame {
  @Builder
  defaultContent() {
  }

  @BuilderParam content: () => void = this.defaultContent;

  build() {
    GridRow({
      columns: {
        sm: BreakpointConstants.GRID_ROW_COLUMNS[0],
        md: BreakpointConstants.GRID_ROW_COLUMNS[1],
        lg: BreakpointConstants.GRID_ROW_COLUMNS[2]
      },
      breakpoints: {
        value: ['320vp', '600vp', '840vp'],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({
        span: {
          sm: BreakpointConstants.GRID_COLUMN_SPANS[0],
          md: BreakpointConstants.GRID_COLUMN_SPANS[1],
          lg: BreakpointConstants.GRID_COLUMN_SPANS[3]
        },
        offset: {
          sm: 0,
          md: 0,
          lg: 2
        }
      }) {
        this.content()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State docTab: number = 0;
  @State showSearch: boolean = false;
  @State query: string = '';
  @State docs: DocSummary[] = [];
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  private navStack: NavPathStack = new NavPathStack();
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.reloadDocs();
  }

  onPageShow(): void {
    this.reloadDocs();
  }

  @Builder
  tabBarBuilder(title: string, index: number, selectedImg: ResourceStr, normalImg: ResourceStr, shift: number) {
    Column() {
      Image(this.currentIndex === index ? selectedImg : normalImg)
        .width(24)
        .height(24)
      Text(title)
        .fontColor(this.currentIndex === index ? $r('app.color.icon_color_highlight') :
          $r('app.color.icon_color_level2'))
        .fontSize($r('app.string.font_size_12'))
        .margin({ top: $r('app.string.margin_xs') })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ left: shift })
  }

  @Builder
  scanFab() {
    Column() {
      Image($r('app.media.ic_scan_selected'))
        .width(28)
        .height(28)
    }
    .width(60)
    .height(60)
    .borderRadius(30)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
    .border({ width: 3, color: $r('app.color.icon_color_highlight') })
    .shadow({ radius: 12, color: '#330A59F7', offsetY: 4 })
    .margin({ bottom: this.navIndicatorHeight + 18 })
    .onClick(() => {
      this.openScan();
    })
  }

  build() {
    HdsNavigation(this.navStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        HdsTabs({ controller: this.tabsController, index: this.currentIndex }) {
          TabContent() {
            if (this.currentIndex === 0) {
              this.docsPage()
            }
          }
          .tabBar(this.tabBarBuilder('文档', 0, $r('app.media.ic_doc_selected'), $r('app.media.ic_doc'), -16))

          TabContent() {
            if (this.currentIndex === 1) {
              this.toolsPage()
            }
          }
          .tabBar(this.tabBarBuilder('工具', 1, $r('app.media.ic_tool_selected'), $r('app.media.ic_tool'), -36))

          TabContent() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(Color.White)
          }
          .tabBar(this.tabBarBuilder('扫描', 2, $r('app.media.ic_scan_selected'), $r('app.media.ic_scan'), 36))

          TabContent() {
            if (this.currentIndex === 3) {
              this.minePage()
            }
          }
          .tabBar(this.tabBarBuilder('我的', 3, $r('app.media.ic_mine_selected'), $r('app.media.ic_mine'), 16))
        }
        .scrollable(false)
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .animationDuration(0)
        .width('100%')
        .height('100%')
        .barFloatingStyle({
          barBottomMargin: this.navIndicatorHeight + 12,
          gradientMask: { maskColor: '#66F1F3F5', maskHeight: 92 },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .onChange((index: number) => {
          if (index === 2) {
            this.openScan();
            this.tabsController.changeIndex(this.currentIndex);
            return;
          }
          this.currentIndex = index;
        })

        this.scanFab()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  docsPage() {
    NewsFrame() {
      Column() {
        this.pageTitle('文档', true)
        if (this.showSearch) {
          this.searchBar()
        }
        Tabs({ barPosition: BarPosition.Start, index: this.docTab }) {
          TabContent() {
            this.recentList()
          }
          .backgroundColor($r('app.color.list_background'))
          .padding({ top: 8 })
          .tabBar(this.channelTab('最近', 0))

          TabContent() {
            this.folderList()
          }
          .backgroundColor($r('app.color.list_background'))
          .padding({ top: 8 })
          .tabBar(this.channelTab('文件夹', 1))
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ top: 12 })
        .barHeight(48)
        .barMode(BarMode.Scrollable)
        .barWidth('100%')
        .vertical(false)
        .onChange((index: number) => {
          this.docTab = index;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }

  @Builder
  pageTitle(title: string, withImport: boolean) {
    Row() {
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.fontColor_text3'))
        .layoutWeight(1)
      if (withImport) {
        Text('导入')
          .fontSize(16)
          .fontColor($r('app.color.fontColor_text3'))
          .margin({ right: 16 })
          .onClick(() => {
            this.importDoc();
          })
      }
      Image($r('app.media.ic_search'))
        .width(24)
        .height(24)
        .onClick(() => {
          this.toggleSearch();
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: this.statusBarHeight + 8, bottom: 4 })
  }

  @Builder
  searchBar() {
    Row() {
      Search({ value: this.query, placeholder: '搜索' })
        .layoutWeight(1)
        .height(40)
        .onChange((value: string) => {
          this.query = value;
          this.reloadDocs();
        })
        .onSubmit((value: string) => {
          this.query = value;
          this.reloadDocs();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 })
  }

  @Builder
  channelTab(label: string, index: number) {
    Column() {
      Text(label)
        .margin({ left: 24, right: 22 })
        .fontSize(16)
        .fontWeight(this.docTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.docTab === index ? $r('app.color.fontColor_text3') : $r('app.color.news_time_fontColor'))
        .borderColor({ bottom: $r('app.color.tab_indicator') })
        .borderWidth({ bottom: this.docTab === index ? 3 : 0 })
        .padding({ bottom: 8 })
    }
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  recentList() {
    if (this.docs.length === 0) {
      Text('最近还没有文档')
        .fontSize(14)
        .fontColor($r('app.color.news_time_fontColor'))
        .width('100%')
        .padding({ left: 16, top: 24 })
    } else {
      List({ space: 12 }) {
        ForEach(this.docs, (item: DocSummary) => {
          ListItem() {
            NewsCard({
              label: item.name,
              detail: this.formatWhen(item.updatedAt) + '  ' + item.pageCount + ' 页',
              thumb: true,
              onTap: () => {
                this.openDoc(item.id);
              }
            })
          }
        }, (item: DocSummary) => item.id + ':' + item.updatedAt)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.dockInset() })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  folderList() {
    List({ space: 12 }) {
      ForEach(this.visibleFolders(), (name: string) => {
        ListItem() {
          NewsCard({
            label: name,
            thumb: true,
            onTap: () => {
              this.openTab(2);
            }
          })
        }
      }, (name: string) => name)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: this.dockInset() })
    .scrollBar(BarState.Off)
  }

  @Builder
  toolsPage() {
    NewsFrame() {
      Column() {
        this.pageTitle('工具', false)
        List({ space: 12 }) {
          ListItemGroup({ header: this.headRecognize }) {
            ListItem() {
              NewsCard({
                label: '提取文字',
                onTap: () => {
                  this.openConvert('text');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '扫描证件',
                onTap: () => {
                  this.openTab(2);
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '扫描书籍',
                onTap: () => {
                  this.openTab(2);
                }
              })
            }
          }
          ListItemGroup({ header: this.headPdf }) {
            ListItem() {
              NewsCard({
                label: '合并',
                onTap: () => {
                  this.openManage('merge');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '拆分',
                onTap: () => {
                  this.openManage('split');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '压缩',
                onTap: () => {
                  this.openManage('compress');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '页序',
                onTap: () => {
                  this.openManage('order');
                }
              })
            }
          }
          ListItemGroup({ header: this.headExport }) {
            ListItem() {
              NewsCard({
                label: '转 Word',
                onTap: () => {
                  this.openConvert('word');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '转图片',
                onTap: () => {
                  this.openConvert('image');
                }
              })
            }
            ListItem() {
              NewsCard({
                label: '分享',
                onTap: () => {
                  this.shareRecent();
                }
              })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: this.dockInset() })
        .backgroundColor($r('app.color.list_background'))
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }

  @Builder
  headRecognize() {
    Text('扫描与识别')
      .fontSize(14)
      .fontColor($r('app.color.news_time_fontColor'))
      .width('100%')
      .padding({ top: 12, bottom: 4 })
  }

  @Builder
  headPdf() {
    Text('PDF处理')
      .fontSize(14)
      .fontColor($r('app.color.news_time_fontColor'))
      .width('100%')
      .padding({ top: 12, bottom: 4 })
  }

  @Builder
  headExport() {
    Text('转换导出')
      .fontSize(14)
      .fontColor($r('app.color.news_time_fontColor'))
      .width('100%')
      .padding({ top: 12, bottom: 4 })
  }

  @Builder
  minePage() {
    NewsFrame() {
      Column() {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.banner_mine'))
            .width('100%')
            .height(188 + this.statusBarHeight)
            .objectFit(ImageFit.Cover)
          Row() {
            Text('我的')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)
            Image($r('app.media.ic_search_light'))
              .width(24)
              .height(24)
              .onClick(() => {
                this.showSearch = true;
                this.openTab(0);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: this.statusBarHeight + 8 })
        }
        .width('100%')
        .height(188 + this.statusBarHeight)

        Scroll() {
          Row() {
            MineShortcut({
              label: '本地优先',
              icon: $r('app.media.sc_local')
            })
            MineShortcut({
              label: 'Free',
              icon: $r('app.media.sc_free'),
              onTap: () => {
                toast('当前是 Free，没有需要取消的订阅。');
              }
            })
            MineShortcut({
              label: '取消订阅',
              icon: $r('app.media.sc_cancel'),
              onTap: () => {
                toast('当前是 Free，没有需要取消的订阅。');
              }
            })
            MineShortcut({
              label: '导入',
              icon: $r('app.media.sc_import'),
              onTap: () => {
                this.importDoc();
              }
            })
            MineShortcut({
              label: '分享',
              icon: $r('app.media.sc_share'),
              onTap: () => {
                this.shareRecent();
              }
            })
            MineShortcut({
              label: '扫描',
              icon: $r('app.media.sc_scan'),
              onTap: () => {
                this.openTab(2);
              }
            })
          }
          .padding({ left: 8, right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .backgroundColor(Color.White)

        Column() {
          Text('本地优先')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.fontColor_text3'))
            .width('100%')
            .padding({ top: 16, bottom: 12 })
          Text('文档保存在这台设备上，打开和扫描不要求上传。')
            .fontSize(14)
            .fontColor($r('app.color.news_time_fontColor'))
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(16)
          Column() {
            Text('Free')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.fontColor_text3'))
              .width('100%')
            Text('当前方案')
              .fontSize(12)
              .fontColor($r('app.color.news_time_fontColor'))
              .width('100%')
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor(Color.White)
          .borderRadius(16)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: this.dockInset() })
        .backgroundColor($r('app.color.list_background'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }

  private toggleSearch(): void {
    if (this.currentIndex !== 0) {
      this.showSearch = true;
      this.openTab(0);
      return;
    }
    this.showSearch = !this.showSearch;
  }

  private dockInset(): number {
    return 108 + this.navIndicatorHeight;
  }

  private openTab(index: number): void {
    if (index === 2) {
      this.openScan();
      return;
    }
    this.currentIndex = index;
    this.tabsController.changeIndex(index);
  }

  private openScan(): void {
    this.navStack.pushPathByName('ScanPage', new ScanRoute(), (popInfo: PopInfo) => {
      if (popInfo !== undefined) {
        this.reloadDocs();
      }
    });
  }

  private visibleFolders(): string[] {
    const names: string[] = ['扫描证件', '扫描书籍'];
    if (this.query.length === 0) {
      return names;
    }
    const matched: string[] = [];
    for (let i = 0; i < names.length; i++) {
      if (names[i].indexOf(this.query) >= 0) {
        matched.push(names[i]);
      }
    }
    return matched;
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
    this.openTab(0);
  }

  private openDoc(id: string): void {
    this.navStack.pushPathByName('EditPage', new EditRoute(id));
  }

  private openConvert(tool: string): void {
    this.navStack.pushPathByName('ConvertPage', new ConvertRoute(tool));
  }

  private openManage(tool: string): void {
    this.navStack.pushPathByName('ManagePage', new ManageRoute(tool));
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
    return date.getFullYear() + '-' + this.two(date.getMonth() + 1) + '-' + this.two(date.getDate());
  }

  private two(value: number): string {
    if (value < 10) {
      return '0' + value;
    }
    return String(value);
  }
}
