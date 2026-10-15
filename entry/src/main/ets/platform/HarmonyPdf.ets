import { fileIo } from '@kit.CoreFileKit';
import { pdfService } from '@kit.PDFKit';
import { Annotation, AnnKind, NativePdfPort } from 'juanshu_core';

/** PDF Kit 适配器。颜色按接口要求转成 BGR。 */
export class HarmonyNativePdf implements NativePdfPort {
  available(): boolean {
    return canIUse('SystemCapability.OfficeService.PDFService.Core');
  }

  pageCount(path: string): number {
    const doc = this.open(path);
    if (doc === null) {
      return 0;
    }
    const count = doc.getPageCount();
    doc.releaseDocument();
    return count;
  }

  merge(paths: string[], output: string): boolean {
    if (paths.length === 0) {
      return false;
    }
    const target = this.open(paths[0]);
    if (target === null) {
      return false;
    }
    try {
      for (let i = 1; i < paths.length; i++) {
        const source = this.open(paths[i]);
        if (source === null) {
          continue;
        }
        const count = source.getPageCount();
        target.insertPageFromDocument(source, 0, count, target.getPageCount());
        source.releaseDocument();
      }
      return target.saveDocument(output);
    } catch (err) {
      return false;
    } finally {
      target.releaseDocument();
    }
  }

  split(path: string, groups: number[][], outputs: string[]): boolean {
    let ok = true;
    for (let g = 0; g < groups.length && g < outputs.length; g++) {
      const doc = this.open(path);
      if (doc === null) {
        ok = false;
        continue;
      }
      try {
        const keep = groups[g];
        const total = doc.getPageCount();
        for (let index = total - 1; index >= 0; index--) {
          if (!contains(keep, index)) {
            doc.deletePage(index, 1);
          }
        }
        if (!doc.saveDocument(outputs[g])) {
          ok = false;
        }
      } catch (err) {
        ok = false;
      }
      doc.releaseDocument();
    }
    return ok;
  }

  deletePage(path: string, index: number): boolean {
    return this.edit(path, (doc: pdfService.PdfDocument) => {
      doc.deletePage(index, 1);
    });
  }

  movePage(path: string, from: number, to: number): boolean {
    return this.edit(path, (doc: pdfService.PdfDocument) => {
      doc.movePage(from, to);
    });
  }

  rotate(path: string, index: number, delta: number): boolean {
    return this.edit(path, (doc: pdfService.PdfDocument) => {
      const page = doc.getPage(index);
      page.setRotation(rotationOf(degreesOf(page.getRotation()) + delta));
    });
  }

  addMarkup(path: string, pageIndex: number, ann: Annotation, imagePath: string): boolean {
    return this.edit(path, (doc: pdfService.PdfDocument) => {
      const page = doc.getPage(pageIndex);
      applyMarkup(page, ann, imagePath);
    });
  }

  convertToImages(path: string, directory: string): boolean {
    const doc = this.open(path);
    if (doc === null) {
      return false;
    }
    try {
      fileIo.mkdirSync(directory);
    } catch (err) {
    }
    try {
      return doc.convertToImage(directory, pdfService.ImageFormat.PNG);
    } catch (err) {
      return false;
    } finally {
      doc.releaseDocument();
    }
  }

  private open(path: string): pdfService.PdfDocument | null {
    if (!this.available()) {
      return null;
    }
    try {
      const doc = new pdfService.PdfDocument();
      if (doc.loadDocument(path, '') !== pdfService.ParseResult.PARSE_SUCCESS) {
        return null;
      }
      return doc;
    } catch (err) {
      return null;
    }
  }

  private edit(path: string, change: (doc: pdfService.PdfDocument) => void): boolean {
    const doc = this.open(path);
    if (doc === null) {
      return false;
    }
    try {
      change(doc);
      const tmp = path + '.writing';
      const saved = doc.saveDocument(tmp);
      doc.releaseDocument();
      if (!saved) {
        return false;
      }
      try {
        fileIo.unlinkSync(path);
      } catch (err) {
      }
      fileIo.renameSync(tmp, path);
      return true;
    } catch (err) {
      try {
        doc.releaseDocument();
      } catch (closeErr) {
      }
      return false;
    }
  }
}

function contains(values: number[], target: number): boolean {
  for (let i = 0; i < values.length; i++) {
    if (values[i] === target) {
      return true;
    }
  }
  return false;
}

function degreesOf(angle: pdfService.RotationAngle): number {
  if (angle === pdfService.RotationAngle.ANGLE_90) {
    return 90;
  }
  if (angle === pdfService.RotationAngle.ANGLE_180) {
    return 180;
  }
  if (angle === pdfService.RotationAngle.ANGLE_270) {
    return 270;
  }
  return 0;
}

function rotationOf(degrees: number): pdfService.RotationAngle {
  const turn = ((Math.round(degrees / 90) % 4) + 4) % 4;
  if (turn === 1) {
    return pdfService.RotationAngle.ANGLE_90;
  }
  if (turn === 2) {
    return pdfService.RotationAngle.ANGLE_180;
  }
  if (turn === 3) {
    return pdfService.RotationAngle.ANGLE_270;
  }
  return pdfService.RotationAngle.ANGLE_0;
}

function toBgr(rgb: number): number {
  const r = (rgb >> 16) & 255;
  const g = (rgb >> 8) & 255;
  const b = rgb & 255;
  return (b << 16) | (g << 8) | r;
}

function pointAt(x: number, y: number): pdfService.PdfPoint {
  const point = new pdfService.PdfPoint();
  point.x = x;
  point.y = y;
  return point;
}

function applyMarkup(page: pdfService.PdfPage, ann: Annotation, imagePath: string): void {
  const width = page.getWidth();
  const height = page.getHeight();
  const left = ann.x * width;
  const right = (ann.x + ann.w) * width;
  const top = (1 - ann.y) * height;
  const bottom = top - ann.h * height;
  if (ann.type === AnnKind.HIGHLIGHT || ann.type === AnnKind.UNDERLINE) {
    const points: pdfService.PdfPoint[] = [
      pointAt(left, top),
      pointAt(right, top),
      pointAt(left, bottom),
      pointAt(right, bottom)
    ];
    if (ann.type === AnnKind.HIGHLIGHT) {
      const info = new pdfService.HighlightAnnotationInfo();
      info.quadPoints = points;
      info.color = toBgr(ann.color);
      info.content = ann.text;
      page.addAnnotation(info);
    } else {
      const info = new pdfService.UnderlineAnnotationInfo();
      info.quadPoints = points;
      page.addAnnotation(info);
    }
    return;
  }
  if (ann.type === AnnKind.INK) {
    const info = new pdfService.InkAnnotationInfo();
    const ink: pdfService.PdfPoint[] = [];
    for (let i = 0; i < ann.points.length; i++) {
      ink.push(pointAt(ann.points[i].x * width, (1 - ann.points[i].y) * height));
    }
    info.inkPoints = ink;
    info.lineColor = toBgr(ann.color);
    page.addAnnotation(info);
    return;
  }
  if (ann.type === AnnKind.RECT || ann.type === AnnKind.OVAL) {
    if (ann.type === AnnKind.RECT) {
      const info = new pdfService.SquareAnnotationInfo();
      info.left = left;
      info.bottom = bottom;
      info.right = right;
      info.top = top;
      info.lineColor = toBgr(ann.color);
      page.addAnnotation(info);
    } else {
      const info = new pdfService.OvalAnnotationInfo();
      info.left = left;
      info.bottom = bottom;
      info.right = right;
      info.top = top;
      info.lineColor = toBgr(ann.color);
      page.addAnnotation(info);
    }
    return;
  }
  if (ann.type === AnnKind.COMMENT) {
    const info = new pdfService.TextAnnotationInfo();
    info.iconName = 'Comment';
    info.x = left;
    info.y = bottom;
    info.state = pdfService.TextAnnotationState.MARKED;
    info.flag = pdfService.AnnotationFlag.PRINTED;
    info.content = ann.text;
    info.color = toBgr(ann.color);
    page.addAnnotation(info);
    return;
  }
  if (ann.type === AnnKind.TEXT) {
    const style = new pdfService.TextStyle();
    const font = new pdfService.FontInfo();
    font.fontPath = '/system/fonts/HarmonyOS_Sans_SC.ttf';
    style.fontInfo = font;
    style.textSize = ann.fontSize;
    style.textColor = toBgr(ann.color);
    page.addTextObject(ann.text, left, bottom, style);
    return;
  }
  if (ann.type === AnnKind.SIGNATURE && imagePath.length > 0) {
    const info = new pdfService.StampAnnotationInfo();
    info.imagePath = imagePath;
    info.left = left;
    info.bottom = bottom;
    info.right = right;
    info.top = top;
    page.addAnnotation(info);
  }
}
