import { Point, RgbaImage, cloneImage } from './Image';

/** 批注种类。数值稳定，写入 PDF 元数据。 */
export class AnnKind {
  static readonly TEXT: number = 1;
  static readonly HIGHLIGHT: number = 2;
  static readonly UNDERLINE: number = 3;
  static readonly INK: number = 4;
  static readonly RECT: number = 5;
  static readonly OVAL: number = 6;
  static readonly COMMENT: number = 7;
  static readonly SIGNATURE: number = 8;
}

export class ScanFilter {
  static readonly ORIGINAL: number = 0;
  static readonly GRAY: number = 1;
  static readonly BW: number = 2;
  static readonly COLOR: number = 3;
}

export class DocKind {
  static readonly JUANSHU: number = 0;
  static readonly EXTERNAL: number = 1;
}

/**
 * 批注坐标相对页面宽高，原点左上，范围 0–1。
 * 手写点同样使用归一化坐标。签名图自带透明通道。
 */
export class Annotation {
  type: number = AnnKind.HIGHLIGHT;
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
  color: number = 0xFFE14A;
  text: string = '';
  fontSize: number = 16;
  points: Point[] = [];
  image: RgbaImage | null = null;

  constructor(type: number) {
    this.type = type;
  }
}

export class PdfPageModel {
  widthPt: number = 595;
  heightPt: number = 842;
  rotation: number = 0;
  image: RgbaImage | null = null;
  text: string = '';
  ocrText: string = '';
  annotations: Annotation[] = [];
}

export class PdfDocumentModel {
  title: string = '未命名';
  pages: PdfPageModel[] = [];
}

export class DocSummary {
  id: string = '';
  name: string = '';
  pageCount: number = 0;
  updatedAt: number = 0;
  bytes: number = 0;
  kind: number = DocKind.JUANSHU;
}

export class OcrBlock {
  text: string = '';
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;

  constructor(text: string, x: number, y: number, w: number, h: number) {
    this.text = text;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
}

export class OcrResult {
  text: string = '';
  blocks: OcrBlock[] = [];
  engine: string = '';
}

export function cloneAnnotation(src: Annotation): Annotation {
  const copy = new Annotation(src.type);
  copy.x = src.x;
  copy.y = src.y;
  copy.w = src.w;
  copy.h = src.h;
  copy.color = src.color;
  copy.text = src.text;
  copy.fontSize = src.fontSize;
  for (let i = 0; i < src.points.length; i++) {
    copy.points.push(new Point(src.points[i].x, src.points[i].y));
  }
  if (src.image !== null) {
    copy.image = cloneImage(src.image);
  }
  return copy;
}

export function clonePage(src: PdfPageModel): PdfPageModel {
  const page = new PdfPageModel();
  page.widthPt = src.widthPt;
  page.heightPt = src.heightPt;
  page.rotation = src.rotation;
  page.text = src.text;
  page.ocrText = src.ocrText;
  if (src.image !== null) {
    page.image = cloneImage(src.image);
  }
  for (let i = 0; i < src.annotations.length; i++) {
    page.annotations.push(cloneAnnotation(src.annotations[i]));
  }
  return page;
}

export function cloneDoc(src: PdfDocumentModel): PdfDocumentModel {
  const doc = new PdfDocumentModel();
  doc.title = src.title;
  for (let i = 0; i < src.pages.length; i++) {
    doc.pages.push(clonePage(src.pages[i]));
  }
  return doc;
}

export function pagePointsForImage(image: RgbaImage): PdfPageModel {
  const page = new PdfPageModel();
  page.image = cloneImage(image);
  const longEdge = Math.max(image.width, image.height);
  const scale = longEdge > 0 ? 842 / longEdge : 1;
  page.widthPt = Math.max(72, Math.round(image.width * scale));
  page.heightPt = Math.max(72, Math.round(image.height * scale));
  return page;
}
