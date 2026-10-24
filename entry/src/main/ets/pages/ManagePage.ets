import { HdsNavDestination } from '@kit.UIDesignKit';
import { DocSummary, identityOrder } from 'juanshu_core';
import { EditRoute, ManageRoute } from '../common/NavRoutes';
import { stampName, toast } from '../components/Chrome';
import { AppHost } from '../platform/AppHost';

@Component
struct ManagePage {
  @State query: string = '';
  @State files: DocSummary[] = [];
  @State picked: string[] = [];
  @State active: string = '';
  @State order: number[] = [];
  @State ranges: string = '1-1';
  @State rename: string = '';
  @State tool: string = '';
  private stack: NavPathStack | null = null;

  build() {
    HdsNavDestination() {
      Column() {
      Scroll() {
        Column() {
          TextInput({ text: this.query, placeholder: '搜索文件名' })
            .width('100%')
            .height(44)
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => {
              this.query = value;
              this.reload();
            })
          Row() {
            Button('导入')
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#1F6B4A')
              .onClick(() => {
                this.importPdf();
              })
            Button('新建')
              .layoutWeight(1)
              .height(40)
              .margin({ left: 8 })
              .backgroundColor('#1F6B4A')
              .fontColor('#FFFFFF')
              .onClick(() => {
                const created = AppHost.newBlank(stampName('文稿'));
                toast('已新建 ' + created.name);
                this.reload();
              })
          }
          .width('100%')
          .margin({ top: 10 })
          if (this.files.length === 0) {
            Text('没有匹配的文档')
              .fontSize(14)
              .fontColor('#6E6A62')
              .margin({ top: 20 })
          }
          ForEach(this.files, (item: DocSummary) => {
            this.row(item)
          }, (item: DocSummary) => item.id + ':' + item.updatedAt + ':' + this.isPicked(item.id))
          if (this.picked.length > 1) {
            Button('合并所选 ' + this.picked.length + ' 份')
              .width('100%')
              .height(44)
              .margin({ top: 12 })
              .backgroundColor('#1F6B4A')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.mergePicked();
              })
          }
          if (this.active.length > 0) {
            this.editor()
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F4EF')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      content: { title: { mainTitle: this.toolTitle() } }
    })
    .backgroundColor('#F6F4EF')
    .onReady((ctx: NavDestinationContext) => {
      this.stack = ctx.pathStack;
      this.applyRoute(ctx.pathInfo.param);
      this.reload();
    })
    .onShown(() => {
      this.reload();
    })
  }

  @Builder
  row(item: DocSummary) {
    Column() {
      Row() {
        Text(this.isPicked(item.id) ? '已选' : '选择')
          .fontSize(12)
          .fontColor(this.isPicked(item.id) ? '#FFFFFF' : '#1F6B4A')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
          .backgroundColor(this.isPicked(item.id) ? '#1F6B4A' : '#E7F2EC')
          .onClick(() => {
            this.toggle(item.id);
          })
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
        .margin({ left: 10 })
        .onClick(() => {
          this.openDoc(item.id);
        })
      }
      .width('100%')
      Row() {
        Text('整理')
          .fontSize(13)
          .fontColor('#1F6B4A')
          .onClick(() => {
            this.openEditor(item);
          })
        Text('重命名')
          .fontSize(13)
          .fontColor('#1C1B19')
          .margin({ left: 16 })
          .onClick(() => {
            this.active = item.id;
            this.rename = item.name;
            this.order = identityOrder(item.pageCount);
          })
        Text('删除')
          .fontSize(13)
          .fontColor('#9C3B2E')
          .margin({ left: 16 })
          .onClick(() => {
            AppHost.remove(item.id);
            this.active = '';
            this.reload();
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(14)
    .margin({ top: 10 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  editor() {
    Column() {
      Text('页面顺序')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 8 })
      ForEach(this.order, (_index: number, position: number) => {
        Row() {
          Text('第 ' + (position + 1) + ' 页')
            .fontSize(14)
            .layoutWeight(1)
          Text('上移')
            .fontSize(13)
            .fontColor('#1F6B4A')
            .onClick(() => {
              this.shift(position, -1);
            })
          Text('下移')
            .fontSize(13)
            .fontColor('#1F6B4A')
            .margin({ left: 10 })
            .onClick(() => {
              this.shift(position, 1);
            })
          Text('旋转')
            .fontSize(13)
            .fontColor('#1C1B19')
            .margin({ left: 10 })
            .onClick(() => {
              if (AppHost.rotate(this.active, position)) {
                toast('已旋转');
              } else {
                toast('旋转失败');
              }
            })
          Text('删除')
            .fontSize(13)
            .fontColor('#9C3B2E')
            .margin({ left: 10 })
            .onClick(() => {
              this.deleteAt(position);
            })
        }
        .width('100%')
        .margin({ top: 6 })
      }, (_index: number, position: number) => position + ':' + this.order.length)
      TextInput({ text: this.ranges, placeholder: '拆分页码，如 1-2,4' })
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .backgroundColor('#F6F4EF')
        .onChange((value: string) => {
          this.ranges = value;
        })
      Button('按页码拆分')
        .width('100%')
        .height(42)
        .margin({ top: 8 })
        .backgroundColor('#1F6B4A')
        .fontColor('#FFFFFF')
        .onClick(() => {
          const parts = AppHost.split(this.active, this.ranges);
          toast(parts.length === 0 ? '没有拆出文档' : '已拆成 ' + parts.length + ' 份');
          this.reload();
        })
      Row() {
        Button('压缩')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#FFFFFF')
          .fontColor('#1F6B4A')
          .onClick(() => {
            this.compress(false);
          })
        Button('较小文件')
          .layoutWeight(1)
          .height(42)
          .margin({ left: 8 })
          .backgroundColor('#FFFFFF')
          .fontColor('#1C1B19')
          .onClick(() => {
            this.compress(true);
          })
      }
      .width('100%')
      .margin({ top: 8 })
      TextInput({ text: this.rename, placeholder: '新文件名' })
        .width('100%')
        .height(44)
        .margin({ top: 8 })
        .backgroundColor('#F6F4EF')
        .onChange((value: string) => {
          this.rename = value;
        })
      Button('重命名')
        .width('100%')
        .height(42)
        .margin({ top: 8 })
        .backgroundColor('#154832')
        .fontColor('#FFFFFF')
        .onClick(() => {
          if (AppHost.rename(this.active, this.rename)) {
            toast('已重命名');
            this.reload();
          }
        })
    }
    .width('100%')
    .padding(14)
    .margin({ top: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  private applyRoute(param: Object): void {
    if (param === undefined || param === null) {
      return;
    }
    const route = param as ManageRoute;
    if (route.tool !== undefined && route.tool.length > 0) {
      this.tool = route.tool;
    }
  }

  private openDoc(id: string): void {
    if (this.stack !== null) {
      this.stack.pushPathByName('EditPage', new EditRoute(id));
    }
  }

  private toolTitle(): string {
    if (this.tool === 'merge') {
      return '合并';
    }
    if (this.tool === 'split') {
      return '拆分';
    }
    if (this.tool === 'compress') {
      return '压缩';
    }
    if (this.tool === 'order') {
      return '页序';
    }
    return '文档';
  }

  private reload(): void {
    this.files = AppHost.search(this.query);
    if (this.active.length > 0 && AppHost.find(this.active) === null) {
      this.active = '';
    }
  }

  private isPicked(id: string): boolean {
    for (let i = 0; i < this.picked.length; i++) {
      if (this.picked[i] === id) {
        return true;
      }
    }
    return false;
  }

  private toggle(id: string): void {
    const next: string[] = [];
    let found = false;
    for (let i = 0; i < this.picked.length; i++) {
      if (this.picked[i] === id) {
        found = true;
      } else {
        next.push(this.picked[i]);
      }
    }
    if (!found) {
      next.push(id);
    }
    this.picked = next;
  }

  private openEditor(item: DocSummary): void {
    this.active = item.id;
    this.rename = item.name;
    this.order = identityOrder(Math.max(1, item.pageCount));
    this.ranges = '1-' + Math.max(1, item.pageCount);
  }

  private shift(position: number, delta: number): void {
    const target = position + delta;
    if (target < 0 || target >= this.order.length) {
      return;
    }
    if (!AppHost.move(this.active, position, target)) {
      toast('调整顺序失败');
      return;
    }
    this.order = identityOrder(this.order.length);
  }

  private deleteAt(position: number): void {
    if (!AppHost.removePage(this.active, position)) {
      toast('至少保留一页，或删除失败');
      return;
    }
    this.order = identityOrder(Math.max(0, this.order.length - 1));
    this.reload();
  }

  private mergePicked(): void {
    const saved = AppHost.merge(this.picked, stampName('合并'));
    if (saved === null) {
      toast('合并失败。外部 PDF 需要 PDF Kit');
      return;
    }
    toast('已合并为 ' + saved.name);
    this.picked = [];
    this.reload();
  }

  private compress(small: boolean): void {
    if (AppHost.compress(this.active, small)) {
      toast(small ? '已生成较小文件' : '已压缩');
      this.reload();
      return;
    }
    toast('这份外部 PDF 还不能在核心里重采样，需要可解码的卷舒文档');
  }

  private async importPdf(): Promise<void> {
    const saved = await AppHost.pickPdf();
    if (saved === null) {
      toast('没有导入文件');
      return;
    }
    toast('已导入 ' + saved.name);
    this.reload();
  }
}

@Builder
export function ManagePageBuilder(name: string, param: Object) {
  if (name.length >= 0 && param !== undefined) {
    ManagePage()
  }
}
