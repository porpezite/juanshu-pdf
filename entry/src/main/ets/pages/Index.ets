import { router } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { DocSummary } from 'juanshu_core';
import { BreakpointConstants } from '../common/BreakpointConstants';
import { DocScanner } from '../components/DocScanner';
import { toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';

@Component
struct NewsRow {
  label: string = '';
  detail: string = '';
  thumb: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.label)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.detail.length > 0) {
            Text(this.detail)
              .fontSize(12)
              .fontColor('#99182431')
              .maxLines(2)
              .margin({ top: 8 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: this.thumb ? 12 : 0 })

        if (this.thumb) {
          Image($r('app.media.app_icon'))
            .width(96)
            .height(72)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })

      Divider()
        .strokeWidth(0.5)
        .color('#E8E8E8')
        .margin({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor(Color.White)
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
        xs: BreakpointConstants.COLUMNS_SM,
        sm: BreakpointConstants.COLUMNS_SM,
        md: BreakpointConstants.COLUMNS_MD,
        lg: BreakpointConstants.COLUMNS_LG
      },
      breakpoints: {
        value: [BreakpointConstants.RANGE_SM, BreakpointConstants.RANGE_MD, BreakpointConstants.RANGE_LG],
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({
        span: {
          xs: BreakpointConstants.COLUMNS_SM,
          sm: BreakpointConstants.COLUMNS_SM,
          md: BreakpointConstants.COLUMNS_MD,
          lg: BreakpointConstants.SPAN_LG
        },
        offset: {
          xs: 0,
          sm: 0,
          md: 0,
          lg: BreakpointConstants.OFFSET_LG
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
  @State query: string = '';
  @State docs: DocSummary[] = [];
  private navStack: NavPathStack = new NavPathStack();
  private tabsController: TabsController = new TabsController();

  aboutToAppear(): void {
    this.reloadDocs();
  }

  onPageShow(): void {
    this.reloadDocs();
  }

  @Builder
  tabBarBuilder(title: string, index: number, selectedImg: ResourceStr, normalImg: ResourceStr) {
    Column() {
      Image(this.currentIndex === index ? selectedImg : normalImg)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? '#FF6B00' : '#99182431')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Navigation(this.navStack) {
      Column() {
        Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex }) {
          TabContent() {
            this.docsPage()
          }
          .tabBar(this.tabBarBuilder('文档', 0, $r('app.media.ic_doc_selected'), $r('app.media.ic_doc')))

          TabContent() {
            this.toolsPage()
          }
          .tabBar(this.tabBarBuilder('工具', 1, $r('app.media.ic_tool_selected'), $r('app.media.ic_tool')))

          TabContent() {
            if (this.currentIndex === 2) {
              DocScanner({
                onSaved: () => {
                  this.reloadDocs();
                  this.openTab(0);
                }
              })
                .width('100%')
                .height('100%')
            }
          }
          .tabBar(this.tabBarBuilder('扫描', 2, $r('app.media.ic_scan_selected'), $r('app.media.ic_scan')))

          TabContent() {
            this.minePage()
          }
          .tabBar(this.tabBarBuilder('我的', 3, $r('app.media.ic_mine_selected'), $r('app.media.ic_mine')))
        }
        .barHeight(56)
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .barBackgroundColor(Color.White)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  docsPage() {
    NewsFrame() {
      Column() {
        Row() {
          Text('文档')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .layoutWeight(1)
          Text('导入')
            .fontSize(16)
            .fontColor('#182431')
            .onClick(() => {
              this.importDoc();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 16, bottom: 12 })

        Row() {
          this.subTab('最近', 0)
          this.subTab('文件夹', 1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, bottom: 8 })

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
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.docTab === 0) {
          this.recentList()
        } else {
          this.folderList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }

  @Builder
  subTab(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(16)
        .fontWeight(this.docTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.docTab === index ? '#182431' : '#99182431')
      Row()
        .width(24)
        .height(2)
        .margin({ top: 6 })
        .borderRadius(1)
        .backgroundColor(this.docTab === index ? '#FF6B00' : Color.Transparent)
    }
    .margin({ right: 28 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.docTab = index;
    })
  }

  @Builder
  recentList() {
    if (this.docs.length === 0) {
      Text('最近还没有文档')
        .fontSize(14)
        .fontColor('#99182431')
        .width('100%')
        .padding({ left: 16, top: 24 })
    } else {
      List() {
        ForEach(this.docs, (item: DocSummary) => {
          ListItem() {
            NewsRow({
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
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  folderList() {
    List() {
      ForEach(this.visibleFolders(), (name: string) => {
        ListItem() {
          NewsRow({
            label: name,
            thumb: true,
            onTap: () => {
              this.openTab(2);
            }
          })
        }
      }, (name: string) => name)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  toolsPage() {
    NewsFrame() {
      Column() {
        Text('工具')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        List() {
          ListItemGroup({ header: this.headRecognize }) {
            ListItem() {
              NewsRow({
                label: '提取文字',
                onTap: () => {
                  this.openConvert('text');
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '扫描证件',
                onTap: () => {
                  this.openTab(2);
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '扫描书籍',
                onTap: () => {
                  this.openTab(2);
                }
              })
            }
          }
          ListItemGroup({ header: this.headPdf }) {
            ListItem() {
              NewsRow({
                label: '合并',
                onTap: () => {
                  this.openManage('merge');
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '拆分',
                onTap: () => {
                  this.openManage('split');
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '压缩',
                onTap: () => {
                  this.openManage('compress');
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '页序',
                onTap: () => {
                  this.openManage('order');
                }
              })
            }
          }
          ListItemGroup({ header: this.headExport }) {
            ListItem() {
              NewsRow({
                label: '转 Word',
                onTap: () => {
                  this.openConvert('word');
                }
              })
            }
            ListItem() {
              NewsRow({
                label: '转图片',
                onTap: () => {
                  this.openConvert('image');
                }
              })
            }
            ListItem() {
              NewsRow({
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
      .fontColor('#99182431')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 4 })
  }

  @Builder
  headPdf() {
    Text('PDF处理')
      .fontSize(14)
      .fontColor('#99182431')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 4 })
  }

  @Builder
  headExport() {
    Text('转换导出')
      .fontSize(14)
      .fontColor('#99182431')
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 4 })
  }

  @Builder
  minePage() {
    NewsFrame() {
      Column() {
        Text('我的')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        List() {
          ListItem() {
            NewsRow({
              label: '本地优先',
              detail: '文档保存在这台设备上，打开和扫描不要求上传。'
            })
          }
          ListItem() {
            NewsRow({
              label: 'Free',
              detail: '当前方案'
            })
          }
          ListItem() {
            NewsRow({
              label: '取消订阅',
              onTap: () => {
                toast('当前是 Free，没有需要取消的订阅。');
              }
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }

  private openTab(index: number): void {
    this.currentIndex = index;
    this.tabsController.changeIndex(index);
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
    return date.getFullYear() + '-' + this.two(date.getMonth() + 1) + '-' + this.two(date.getDate());
  }

  private two(value: number): string {
    if (value < 10) {
      return '0' + value;
    }
    return String(value);
  }
}
