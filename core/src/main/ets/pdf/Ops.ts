import { cloneDoc, clonePage, pagePointsForImage, PdfDocumentModel, PdfPageModel, ScanFilter } from '../model/Document';
import { RgbaImage, downscaleMax } from '../model/Image';
import { applyFilter } from '../scan/Filters';
import { wrapUnits } from './PdfCodec';

export function createImageDocument(images: RgbaImage[], title: string): PdfDocumentModel {
  const doc = new PdfDocumentModel();
  doc.title = title;
  for (let i = 0; i < images.length; i++) {
    doc.pages.push(pagePointsForImage(images[i]));
  }
  if (doc.pages.length === 0) {
    doc.pages.push(new PdfPageModel());
  }
  return doc;
}

export function createTextDocument(text: string, title: string): PdfDocumentModel {
  const doc = new PdfDocumentModel();
  doc.title = title;
  const lines = wrapUnits(text, 36);
  const perPage = 34;
  if (text.length === 0) {
    const page = new PdfPageModel();
    page.text = '';
    doc.pages.push(page);
    return doc;
  }
  for (let i = 0; i < lines.length; i += perPage) {
    const page = new PdfPageModel();
    let body = '';
    const end = Math.min(lines.length, i + perPage);
    for (let j = i; j < end; j++) {
      if (body.length > 0) {
        body += '\n';
      }
      body += lines[j];
    }
    page.text = body;
    doc.pages.push(page);
  }
  return doc;
}

export function mergeDocuments(docs: PdfDocumentModel[]): PdfDocumentModel {
  const out = new PdfDocumentModel();
  out.title = docs.length > 0 ? docs[0].title : '合并文档';
  for (let d = 0; d < docs.length; d++) {
    for (let p = 0; p < docs[d].pages.length; p++) {
      out.pages.push(clonePage(docs[d].pages[p]));
    }
  }
  if (out.pages.length === 0) {
    out.pages.push(new PdfPageModel());
  }
  return out;
}

export function splitDocument(doc: PdfDocumentModel, groups: number[][]): PdfDocumentModel[] {
  const out: PdfDocumentModel[] = [];
  for (let g = 0; g < groups.length; g++) {
    const part = new PdfDocumentModel();
    part.title = doc.title + ' ' + (g + 1);
    const group = groups[g];
    for (let i = 0; i < group.length; i++) {
      const index = group[i];
      if (index >= 0 && index < doc.pages.length) {
        part.pages.push(clonePage(doc.pages[index]));
      }
    }
    if (part.pages.length > 0) {
      out.push(part);
    }
  }
  return out;
}

export function deletePageIndexes(doc: PdfDocumentModel, indexes: number[]): PdfDocumentModel {
  const drop = new Uint8Array(doc.pages.length);
  for (let i = 0; i < indexes.length; i++) {
    const index = indexes[i];
    if (index >= 0 && index < drop.length) {
      drop[index] = 1;
    }
  }
  const out = new PdfDocumentModel();
  out.title = doc.title;
  for (let i = 0; i < doc.pages.length; i++) {
    if (drop[i] === 0) {
      out.pages.push(clonePage(doc.pages[i]));
    }
  }
  return out;
}

export function reorderPages(doc: PdfDocumentModel, order: number[]): PdfDocumentModel {
  const out = new PdfDocumentModel();
  out.title = doc.title;
  for (let i = 0; i < order.length; i++) {
    const index = order[i];
    if (index >= 0 && index < doc.pages.length) {
      out.pages.push(clonePage(doc.pages[index]));
    }
  }
  return out;
}

export function rotatePage(doc: PdfDocumentModel, index: number, delta: number): PdfDocumentModel {
  const out = cloneDoc(doc);
  if (index >= 0 && index < out.pages.length) {
    const next = out.pages[index].rotation + delta;
    out.pages[index].rotation = ((Math.round(next / 90) % 4) + 4) % 4 * 90;
  }
  return out;
}

export class CompressSettings {
  maxEdge: number = 800;
  grayscale: boolean = false;
}

export function compressDocument(doc: PdfDocumentModel, settings: CompressSettings): PdfDocumentModel {
  const out = cloneDoc(doc);
  for (let i = 0; i < out.pages.length; i++) {
    const image = out.pages[i].image;
    if (image === null) {
      continue;
    }
    let next = image;
    if (Math.max(image.width, image.height) > settings.maxEdge) {
      next = downscaleMax(image, settings.maxEdge);
    }
    if (settings.grayscale) {
      next = applyFilter(next, ScanFilter.GRAY);
    }
    out.pages[i].image = next;
  }
  return out;
}

export function movePage(order: number[], from: number, to: number): number[] {
  if (from < 0 || to < 0 || from >= order.length || to >= order.length || from === to) {
    return order.slice();
  }
  const next = order.slice();
  const item = next[from];
  next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

export function identityOrder(count: number): number[] {
  const order: number[] = [];
  for (let i = 0; i < count; i++) {
    order.push(i);
  }
  return order;
}
