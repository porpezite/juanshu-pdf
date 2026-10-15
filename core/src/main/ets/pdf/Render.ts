import { Annotation, AnnKind, PdfPageModel } from '../model/Document';
import { blendPixel, colorChannel, fillRect, RgbaImage, rotateImage } from '../model/Image';

/** 把扫描图和栅格批注合成预览。文字由界面叠加，并写入 PDF 文字层。 */
export function renderPage(page: PdfPageModel): RgbaImage {
  let canvas: RgbaImage;
  if (page.image !== null) {
    canvas = new RgbaImage(page.image.width, page.image.height);
    canvas.data.set(page.image.data);
  } else {
    canvas = new RgbaImage(248, 350);
    fillRect(canvas, 0, 0, canvas.width, canvas.height, 255, 255, 255, 255);
  }
  for (let i = 0; i < page.annotations.length; i++) {
    paintAnnotation(canvas, page.annotations[i]);
  }
  const turns = ((Math.round(page.rotation / 90) % 4) + 4) % 4;
  if (turns === 0) {
    return canvas;
  }
  return rotateImage(canvas, page.rotation);
}

function paintAnnotation(canvas: RgbaImage, ann: Annotation): void {
  const box = pixelBox(canvas, ann.x, ann.y, ann.w, ann.h);
  const r = colorChannel(ann.color, 16);
  const g = colorChannel(ann.color, 8);
  const b = colorChannel(ann.color, 0);
  if (ann.type === AnnKind.HIGHLIGHT) {
    fillAlpha(canvas, box[0], box[1], box[2], box[3], r, g, b, 90);
  } else if (ann.type === AnnKind.UNDERLINE) {
    fillRect(canvas, box[0], box[1] + Math.max(0, box[3] - 3), box[2], 3, r, g, b, 255);
  } else if (ann.type === AnnKind.RECT) {
    strokeRect(canvas, box[0], box[1], box[2], box[3], r, g, b);
  } else if (ann.type === AnnKind.OVAL) {
    strokeOval(canvas, box[0], box[1], box[2], box[3], r, g, b);
  } else if (ann.type === AnnKind.INK) {
    paintInk(canvas, ann, r, g, b);
  } else if (ann.type === AnnKind.SIGNATURE && ann.image !== null) {
    blit(canvas, ann.image, box[0], box[1], box[2], box[3]);
  } else if (ann.type === AnnKind.COMMENT) {
    fillAlpha(canvas, box[0], box[1], Math.max(18, box[2]), Math.max(18, box[3]), 255, 214, 90, 220);
  }
}

function pixelBox(canvas: RgbaImage, x: number, y: number, w: number, h: number): number[] {
  const px = Math.round(x * canvas.width);
  const py = Math.round(y * canvas.height);
  const pw = Math.max(1, Math.round(w * canvas.width));
  const ph = Math.max(1, Math.round(h * canvas.height));
  return [px, py, pw, ph];
}

function fillAlpha(image: RgbaImage, x: number, y: number, w: number, h: number,
  r: number, g: number, b: number, a: number): void {
  const x1 = Math.min(image.width, x + w);
  const y1 = Math.min(image.height, y + h);
  for (let py = Math.max(0, y); py < y1; py++) {
    for (let px = Math.max(0, x); px < x1; px++) {
      blendPixel(image, px, py, r, g, b, a);
    }
  }
}

function strokeRect(image: RgbaImage, x: number, y: number, w: number, h: number, r: number, g: number, b: number): void {
  fillRect(image, x, y, w, 2, r, g, b, 255);
  fillRect(image, x, y + h - 2, w, 2, r, g, b, 255);
  fillRect(image, x, y, 2, h, r, g, b, 255);
  fillRect(image, x + w - 2, y, 2, h, r, g, b, 255);
}

function strokeOval(image: RgbaImage, x: number, y: number, w: number, h: number, r: number, g: number, b: number): void {
  const cx = x + w / 2;
  const cy = y + h / 2;
  const rx = Math.max(1, w / 2);
  const ry = Math.max(1, h / 2);
  const steps = 96;
  for (let i = 0; i < steps; i++) {
    const t = (i / steps) * Math.PI * 2;
    const px = Math.round(cx + Math.cos(t) * rx);
    const py = Math.round(cy + Math.sin(t) * ry);
    fillRect(image, px, py, 2, 2, r, g, b, 255);
  }
}

function paintInk(canvas: RgbaImage, ann: Annotation, r: number, g: number, b: number): void {
  if (ann.points.length === 0) {
    return;
  }
  for (let i = 1; i < ann.points.length; i++) {
    const x0 = ann.points[i - 1].x * canvas.width;
    const y0 = ann.points[i - 1].y * canvas.height;
    const x1 = ann.points[i].x * canvas.width;
    const y1 = ann.points[i].y * canvas.height;
    const steps = Math.max(1, Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))));
    for (let s = 0; s <= steps; s++) {
      const t = s / steps;
      blendPixel(canvas, Math.round(x0 + (x1 - x0) * t), Math.round(y0 + (y1 - y0) * t), r, g, b, 255);
    }
  }
}

function blit(dst: RgbaImage, src: RgbaImage, x: number, y: number, w: number, h: number): void {
  for (let py = 0; py < h; py++) {
    for (let px = 0; px < w; px++) {
      const sx = Math.min(src.width - 1, Math.floor(px * src.width / Math.max(1, w)));
      const sy = Math.min(src.height - 1, Math.floor(py * src.height / Math.max(1, h)));
      const o = src.offset(sx, sy);
      blendPixel(dst, x + px, y + py, src.data[o], src.data[o + 1], src.data[o + 2], src.data[o + 3]);
    }
  }
}
