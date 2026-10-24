import { utf16beHex, utf8Decode, utf8Encode } from '../model/Utf8';
import { colorChannel, RgbaImage } from '../model/Image';
import { Annotation, AnnKind, cloneAnnotation, PdfDocumentModel, PdfPageModel } from '../model/Document';
import { Point } from '../model/Image';

const META = '/Type /JuanshuMeta';

export function isJuanshuPdf(bytes: Uint8Array): boolean {
  if (bytes.length < 8 || bytes[0] !== 0x25 || bytes[1] !== 0x50 || bytes[2] !== 0x44 || bytes[3] !== 0x46) {
    return false;
  }
  return indexOfAscii(bytes, META) >= 0;
}

export function encodePdf(doc: PdfDocumentModel): Uint8Array {
  const built = layout(doc);
  const bodies: Uint8Array[] = new Array(built.count + 1);
  bodies[built.catalog] = plain(built.catalog, '<< /Type /Catalog /Pages ' + built.pagesId + ' 0 R >>');
  bodies[built.pagesId] = plain(built.pagesId,
    '<< /Type /Pages /Count ' + built.pages.length + ' /Kids [' + kids(built.pages) + '] >>');
  bodies[built.info] = plain(built.info,
    '<< /Title ' + pdfHex(doc.title) + ' /Producer (Juanshu PDF) /Creator ' + pdfHex('卷舒 PDF') + ' >>');
  bodies[built.font] = plain(built.font,
    '<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light /Encoding /UniGB-UTF16-H /DescendantFonts [' +
    built.cid + ' 0 R] >>');
  bodies[built.cid] = plain(built.cid,
    '<< /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light /CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 4 >> /FontDescriptor ' +
    built.descriptor + ' 0 R /DW 1000 >>');
  bodies[built.descriptor] = plain(built.descriptor,
    '<< /Type /FontDescriptor /FontName /STSong-Light /Flags 6 /FontBBox [-25 -254 1000 880] /ItalicAngle 0 /Ascent 880 /Descent -120 /CapHeight 620 /StemV 80 >>');
  bodies[built.gs] = plain(built.gs, '<< /Type /ExtGState /ca 0.35 /CA 0.35 >>');
  bodies[built.meta] = streamObject(built.meta, META, encodeMeta(doc, built.pages));
  for (let i = 0; i < built.pages.length; i++) {
    const page = built.pages[i];
    bodies[page.pageId] = plain(page.pageId, pageDictionary(page, built));
    bodies[page.contentId] = streamObject(page.contentId, '', utf8Encode(pageContent(page)));
    if (page.imageId !== 0 && page.model.image !== null) {
      bodies[page.imageId] = imageObject(page.imageId, page.model.image, 0);
    }
    for (let s = 0; s < page.sigs.length; s++) {
      const sig = page.sigs[s];
      if (sig.ann.image === null) {
        continue;
      }
      bodies[sig.imageId] = imageObject(sig.imageId, sig.ann.image, sig.maskId);
      bodies[sig.maskId] = maskObject(sig.maskId, sig.ann.image);
    }
  }
  return pack(bodies);
}

export function decodePdf(bytes: Uint8Array): PdfDocumentModel | null {
  if (!isJuanshuPdf(bytes)) {
    return null;
  }
  const xref = parseXref(bytes);
  if (xref === null) {
    return null;
  }
  let meta: Uint8Array | null = null;
  for (let id = 1; id < xref.length; id++) {
    if (xref[id] < 0) {
      continue;
    }
    const head = latin1(bytes, xref[id], Math.min(400, bytes.length - xref[id]));
    if (head.indexOf(META) >= 0) {
      meta = readStream(bytes, xref[id]);
      break;
    }
  }
  if (meta === null || meta.length < 6) {
    return null;
  }
  return decodeMeta(meta, bytes, xref);
}

class BuiltSig {
  ann: Annotation;
  imageId: number;
  maskId: number;

  constructor(ann: Annotation, imageId: number, maskId: number) {
    this.ann = ann;
    this.imageId = imageId;
    this.maskId = maskId;
  }
}

class BuiltPage {
  model: PdfPageModel;
  pageId: number;
  contentId: number;
  imageId: number;
  sigs: BuiltSig[] = [];

  constructor(model: PdfPageModel, pageId: number, contentId: number, imageId: number) {
    this.model = model;
    this.pageId = pageId;
    this.contentId = contentId;
    this.imageId = imageId;
  }
}

class BuiltDoc {
  count: number = 0;
  catalog: number;
  pagesId: number;
  info: number;
  meta: number;
  font: number;
  cid: number;
  descriptor: number;
  gs: number;
  pages: BuiltPage[] = [];

  constructor(catalog: number, pagesId: number, info: number, meta: number, font: number, cid: number,
    descriptor: number, gs: number) {
    this.catalog = catalog;
    this.pagesId = pagesId;
    this.info = info;
    this.meta = meta;
    this.font = font;
    this.cid = cid;
    this.descriptor = descriptor;
    this.gs = gs;
  }
}

function layout(doc: PdfDocumentModel): BuiltDoc {
  let next = 1;
  const catalog = next++;
  const pagesId = next++;
  const info = next++;
  const meta = next++;
  const font = next++;
  const cid = next++;
  const descriptor = next++;
  const gs = next++;
  const built = new BuiltDoc(catalog, pagesId, info, meta, font, cid, descriptor, gs);
  for (let i = 0; i < doc.pages.length; i++) {
    const model = doc.pages[i];
    const pageId = next++;
    const contentId = next++;
    const imageId = model.image !== null ? next++ : 0;
    const page = new BuiltPage(model, pageId, contentId, imageId);
    for (let a = 0; a < model.annotations.length; a++) {
      const ann = model.annotations[a];
      if (ann.type === AnnKind.SIGNATURE && ann.image !== null) {
        const imageObj = next++;
        const maskObj = next++;
        page.sigs.push(new BuiltSig(ann, imageObj, maskObj));
      }
    }
    built.pages.push(page);
  }
  built.count = next - 1;
  return built;
}

function kids(pages: BuiltPage[]): string {
  let out = '';
  for (let i = 0; i < pages.length; i++) {
    if (i > 0) {
      out += ' ';
    }
    out += pages[i].pageId + ' 0 R';
  }
  return out;
}

function pageDictionary(page: BuiltPage, doc: BuiltDoc): string {
  let xobjects = '';
  if (page.imageId !== 0) {
    xobjects += '/Im0 ' + page.imageId + ' 0 R ';
  }
  for (let i = 0; i < page.sigs.length; i++) {
    xobjects += '/Sg' + i + ' ' + page.sigs[i].imageId + ' 0 R ';
  }
  const rotate = ((Math.round(page.model.rotation / 90) % 4) + 4) % 4 * 90;
  return '<< /Type /Page /Parent ' + doc.pagesId + ' 0 R /Rotate ' + rotate +
    ' /MediaBox [0 0 ' + num(page.model.widthPt) + ' ' + num(page.model.heightPt) + '] ' +
    '/Resources << /Font << /F1 ' + doc.font + ' 0 R >> /ExtGState << /GS1 ' + doc.gs +
    ' 0 R >> /XObject << ' + xobjects + '>> >> /Contents ' + page.contentId + ' 0 R >>';
}

function pageContent(page: BuiltPage): string {
  const w = page.model.widthPt;
  const h = page.model.heightPt;
  let out = 'q\n1 1 1 rg\n0 0 ' + num(w) + ' ' + num(h) + ' re\nf\nQ\n';
  if (page.imageId !== 0) {
    out += 'q\n' + num(w) + ' 0 0 ' + num(h) + ' 0 0 cm\n/Im0 Do\nQ\n';
  }
  out += textLayer(page.model, page.model.image === null);
  for (let i = 0; i < page.model.annotations.length; i++) {
    out += annotationOps(page.model, page.model.annotations[i], page);
  }
  return out;
}

function textLayer(page: PdfPageModel, visible: boolean): string {
  const merged = joinText(page.text, page.ocrText);
  if (merged.length === 0) {
    return '';
  }
  const lines = wrapUnits(merged, 36);
  let out = 'BT\n/F1 12 Tf\n';
  out += visible ? '0 Tr\n0 0 0 rg\n' : '3 Tr\n';
  let y = page.heightPt - 42;
  for (let i = 0; i < lines.length; i++) {
    if (y < 36) {
      break;
    }
    out += '1 0 0 1 42 ' + num(y) + ' Tm <' + utf16beHex(lines[i]) + '> Tj\n';
    y -= 18;
  }
  out += 'ET\n';
  return out;
}

function annotationOps(page: PdfPageModel, ann: Annotation, built: BuiltPage): string {
  const box = pdfBox(page, ann);
  const color = pdfRgb(ann.color);
  if (ann.type === AnnKind.HIGHLIGHT) {
    return 'q\n/GS1 gs\n' + color + ' rg\n' + rect(box) + ' re\nf\nQ\n';
  }
  if (ann.type === AnnKind.UNDERLINE) {
    const y = box[1] + 2;
    return 'q\n' + num(1.4) + ' w\n' + color + ' RG\n' + num(box[0]) + ' ' + num(y) + ' m ' +
      num(box[0] + box[2]) + ' ' + num(y) + ' l\nS\nQ\n';
  }
  if (ann.type === AnnKind.RECT) {
    return 'q\n1.4 w\n' + color + ' RG\n' + rect(box) + ' re\nS\nQ\n';
  }
  if (ann.type === AnnKind.OVAL) {
    return ovalOps(box, color);
  }
  if (ann.type === AnnKind.INK) {
    return inkOps(page, ann, color);
  }
  if (ann.type === AnnKind.COMMENT || ann.type === AnnKind.TEXT) {
    const baseline = box[1] + Math.min(ann.fontSize, box[3]);
    return 'BT\n/F1 ' + num(ann.fontSize) + ' Tf\n0 Tr\n' + color + ' rg\n1 0 0 1 ' +
      num(box[0]) + ' ' + num(baseline) + ' Tm <' + utf16beHex(ann.text) + '> Tj\nET\n';
  }
  if (ann.type === AnnKind.SIGNATURE) {
    const index = signatureIndex(built, ann);
    if (index < 0) {
      return '';
    }
    return 'q\n' + num(box[2]) + ' 0 0 ' + num(box[3]) + ' ' + num(box[0]) + ' ' + num(box[1]) +
      ' cm\n/Sg' + index + ' Do\nQ\n';
  }
  return '';
}

function signatureIndex(page: BuiltPage, ann: Annotation): number {
  for (let i = 0; i < page.sigs.length; i++) {
    if (page.sigs[i].ann === ann) {
      return i;
    }
  }
  return -1;
}

function ovalOps(box: number[], color: string): string {
  const x = box[0];
  const y = box[1];
  const w = box[2];
  const h = box[3];
  const cx = x + w / 2;
  const cy = y + h / 2;
  const rx = w / 2;
  const ry = h / 2;
  const k = 0.5522847498;
  return 'q\n1.4 w\n' + color + ' RG\n' +
    num(cx) + ' ' + num(cy + ry) + ' m\n' +
    num(cx + rx * k) + ' ' + num(cy + ry) + ' ' + num(cx + rx) + ' ' + num(cy + ry * k) + ' ' + num(cx + rx) + ' ' + num(cy) + ' c\n' +
    num(cx + rx) + ' ' + num(cy - ry * k) + ' ' + num(cx + rx * k) + ' ' + num(cy - ry) + ' ' + num(cx) + ' ' + num(cy - ry) + ' c\n' +
    num(cx - rx * k) + ' ' + num(cy - ry) + ' ' + num(cx - rx) + ' ' + num(cy - ry * k) + ' ' + num(cx - rx) + ' ' + num(cy) + ' c\n' +
    num(cx - rx) + ' ' + num(cy + ry * k) + ' ' + num(cx - rx * k) + ' ' + num(cy + ry) + ' ' + num(cx) + ' ' + num(cy + ry) + ' c\nS\nQ\n';
}

function inkOps(page: PdfPageModel, ann: Annotation, color: string): string {
  if (ann.points.length === 0) {
    return '';
  }
  let out = 'q\n1.6 w\n1 J\n' + color + ' RG\n';
  for (let i = 0; i < ann.points.length; i++) {
    const x = ann.points[i].x * page.widthPt;
    const y = (1 - ann.points[i].y) * page.heightPt;
    out += num(x) + ' ' + num(y) + (i === 0 ? ' m\n' : ' l\n');
  }
  out += 'S\nQ\n';
  return out;
}

function pdfBox(page: PdfPageModel, ann: Annotation): number[] {
  const w = Math.max(1, ann.w * page.widthPt);
  const h = Math.max(1, ann.h * page.heightPt);
  const x = ann.x * page.widthPt;
  const y = (1 - ann.y) * page.heightPt - h;
  return [x, y, w, h];
}

function rect(box: number[]): string {
  return num(box[0]) + ' ' + num(box[1]) + ' ' + num(box[2]) + ' ' + num(box[3]);
}

function pdfRgb(color: number): string {
  return num(colorChannel(color, 16) / 255) + ' ' + num(colorChannel(color, 8) / 255) + ' ' +
    num(colorChannel(color, 0) / 255);
}

function joinText(a: string, b: string): string {
  if (a.length === 0) {
    return b;
  }
  if (b.length === 0) {
    return a;
  }
  return a + '\n' + b;
}

export function wrapUnits(text: string, maxUnits: number): string[] {
  const lines: string[] = [];
  let line = '';
  let units = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text.charAt(i);
    if (ch === '\n') {
      lines.push(line);
      line = '';
      units = 0;
      continue;
    }
    const weight = text.charCodeAt(i) < 128 ? 1 : 2;
    if (units + weight > maxUnits && line.length > 0) {
      lines.push(line);
      line = ch;
      units = weight;
    } else {
      line += ch;
      units += weight;
    }
  }
  if (line.length > 0 || lines.length === 0) {
    lines.push(line);
  }
  return lines;
}

function imageObject(id: number, image: RgbaImage, maskId: number): Uint8Array {
  let dict = '/Type /XObject /Subtype /Image /Width ' + image.width + ' /Height ' + image.height +
    ' /ColorSpace /DeviceRGB /BitsPerComponent 8';
  if (maskId !== 0) {
    dict += ' /SMask ' + maskId + ' 0 R';
  }
  return streamObject(id, dict, rgbBytes(image));
}

function maskObject(id: number, image: RgbaImage): Uint8Array {
  const dict = '/Type /XObject /Subtype /Image /Width ' + image.width + ' /Height ' + image.height +
    ' /ColorSpace /DeviceGray /BitsPerComponent 8';
  const alpha = new Uint8Array(image.width * image.height);
  for (let i = 0; i < alpha.length; i++) {
    alpha[i] = image.data[i * 4 + 3];
  }
  return streamObject(id, dict, alpha);
}

function rgbBytes(image: RgbaImage): Uint8Array {
  const rgb = new Uint8Array(image.width * image.height * 3);
  for (let i = 0; i < image.width * image.height; i++) {
    rgb[i * 3] = image.data[i * 4];
    rgb[i * 3 + 1] = image.data[i * 4 + 1];
    rgb[i * 3 + 2] = image.data[i * 4 + 2];
  }
  return rgb;
}

function encodeMeta(doc: PdfDocumentModel, pages: BuiltPage[]): Uint8Array {
  const w = new ByteWriter();
  w.bytes(utf8Encode('JSH1'));
  w.u16(1);
  w.text(doc.title);
  w.u16(pages.length);
  for (let i = 0; i < pages.length; i++) {
    const page = pages[i].model;
    w.f64(page.widthPt);
    w.f64(page.heightPt);
    w.u16(((Math.round(page.rotation / 90) % 4) + 4) % 4 * 90);
    w.text(page.text);
    w.text(page.ocrText);
    w.u32(pages[i].imageId);
    w.u16(page.image !== null ? page.image.width : 0);
    w.u16(page.image !== null ? page.image.height : 0);
    w.u16(page.annotations.length);
    for (let a = 0; a < page.annotations.length; a++) {
      writeAnnotation(w, page.annotations[a], pages[i]);
    }
  }
  return w.toUint8Array();
}

function writeAnnotation(w: ByteWriter, ann: Annotation, page: BuiltPage): void {
  w.u8(ann.type);
  w.f64(ann.x);
  w.f64(ann.y);
  w.f64(ann.w);
  w.f64(ann.h);
  w.u32(ann.color >>> 0);
  w.f64(ann.fontSize);
  w.text(ann.text);
  w.u16(ann.points.length);
  for (let i = 0; i < ann.points.length; i++) {
    w.f64(ann.points[i].x);
    w.f64(ann.points[i].y);
  }
  let imageId = 0;
  let iw = 0;
  let ih = 0;
  for (let i = 0; i < page.sigs.length; i++) {
    if (page.sigs[i].ann === ann) {
      imageId = page.sigs[i].imageId;
      if (ann.image !== null) {
        iw = ann.image.width;
        ih = ann.image.height;
      }
    }
  }
  w.u32(imageId);
  w.u32(maskIdOf(page, ann));
  w.u16(iw);
  w.u16(ih);
}

function maskIdOf(page: BuiltPage, ann: Annotation): number {
  for (let i = 0; i < page.sigs.length; i++) {
    if (page.sigs[i].ann === ann) {
      return page.sigs[i].maskId;
    }
  }
  return 0;
}

function decodeMeta(meta: Uint8Array, pdf: Uint8Array, xref: number[]): PdfDocumentModel | null {
  const r = new ByteReader(meta);
  const magic = r.bytes(4);
  if (utf8Decode(magic) !== 'JSH1' || r.u16() !== 1) {
    return null;
  }
  const doc = new PdfDocumentModel();
  doc.title = r.text();
  const count = r.u16();
  for (let i = 0; i < count; i++) {
    const page = new PdfPageModel();
    page.widthPt = r.f64();
    page.heightPt = r.f64();
    page.rotation = r.u16();
    page.text = r.text();
    page.ocrText = r.text();
    const imageId = r.u32();
    const iw = r.u16();
    const ih = r.u16();
    if (imageId !== 0 && iw > 0 && ih > 0) {
      page.image = readRgbImage(pdf, xref, imageId, iw, ih, 0);
    }
    const annCount = r.u16();
    for (let a = 0; a < annCount; a++) {
      const ann = readAnnotation(r, pdf, xref);
      if (ann !== null) {
        page.annotations.push(ann);
      }
    }
    doc.pages.push(page);
  }
  if (r.failed) {
    return null;
  }
  return doc;
}

function readAnnotation(r: ByteReader, pdf: Uint8Array, xref: number[]): Annotation | null {
  const ann = new Annotation(r.u8());
  ann.x = r.f64();
  ann.y = r.f64();
  ann.w = r.f64();
  ann.h = r.f64();
  ann.color = r.u32();
  ann.fontSize = r.f64();
  ann.text = r.text();
  const points = r.u16();
  for (let i = 0; i < points; i++) {
    ann.points.push(new Point(r.f64(), r.f64()));
  }
  const imageId = r.u32();
  const maskId = r.u32();
  const iw = r.u16();
  const ih = r.u16();
  if (imageId !== 0 && iw > 0 && ih > 0) {
    ann.image = readRgbImage(pdf, xref, imageId, iw, ih, maskId);
  }
  if (r.failed) {
    return null;
  }
  return ann;
}

function readRgbImage(pdf: Uint8Array, xref: number[], id: number, width: number, height: number, maskId: number): RgbaImage | null {
  if (id <= 0 || id >= xref.length || xref[id] < 0) {
    return null;
  }
  const rgb = readStream(pdf, xref[id]);
  if (rgb === null || rgb.length < width * height * 3) {
    return null;
  }
  const image = new RgbaImage(width, height);
  for (let i = 0; i < width * height; i++) {
    image.data[i * 4] = rgb[i * 3];
    image.data[i * 4 + 1] = rgb[i * 3 + 1];
    image.data[i * 4 + 2] = rgb[i * 3 + 2];
    image.data[i * 4 + 3] = 255;
  }
  if (maskId > 0 && maskId < xref.length && xref[maskId] >= 0) {
    const mask = readStream(pdf, xref[maskId]);
    if (mask !== null && mask.length >= width * height) {
      for (let i = 0; i < width * height; i++) {
        image.data[i * 4 + 3] = mask[i];
      }
    }
  }
  return image;
}

function pack(bodies: Uint8Array[]): Uint8Array {
  const header = pdfHeader();
  const offsets: number[] = [];
  offsets.push(0);
  let cursor = header.length;
  for (let id = 1; id < bodies.length; id++) {
    offsets.push(cursor);
    cursor += bodies[id].length;
  }
  let xref = 'xref\n0 ' + bodies.length + '\n';
  xref += pad10(0) + ' 65535 f \n';
  for (let id = 1; id < bodies.length; id++) {
    xref += pad10(offsets[id]) + ' 00000 n \n';
  }
  xref += 'trailer\n<< /Size ' + bodies.length + ' /Root 1 0 R /Info 3 0 R >>\nstartxref\n' + cursor + '\n%%EOF\n';
  const xrefBytes = utf8Encode(xref);
  const out = new Uint8Array(cursor + xrefBytes.length);
  out.set(header, 0);
  let at = header.length;
  for (let id = 1; id < bodies.length; id++) {
    out.set(bodies[id], at);
    at += bodies[id].length;
  }
  out.set(xrefBytes, at);
  return out;
}

function plain(id: number, body: string): Uint8Array {
  return utf8Encode(id + ' 0 obj\n' + body + '\nendobj\n');
}

function streamObject(id: number, dict: string, data: Uint8Array): Uint8Array {
  const prefix = dict.length > 0 ? dict + ' ' : '';
  const head = utf8Encode(id + ' 0 obj\n<< ' + prefix + '/Length ' + data.length + ' >>\nstream\n');
  const tail = utf8Encode('\nendstream\nendobj\n');
  const out = new Uint8Array(head.length + data.length + tail.length);
  out.set(head, 0);
  out.set(data, head.length);
  out.set(tail, head.length + data.length);
  return out;
}

function pdfHex(text: string): string {
  return '<' + utf16beHex(text) + '>';
}

function num(value: number): string {
  if (!isFinite(value)) {
    return '0';
  }
  const rounded = Math.round(value * 100) / 100;
  return String(rounded);
}

function pdfHeader(): Uint8Array {
  const text = utf8Encode('%PDF-1.4\n');
  const mark = new Uint8Array([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  const out = new Uint8Array(text.length + mark.length);
  out.set(text, 0);
  out.set(mark, text.length);
  return out;
}

function pad10(value: number): string {
  const raw = String(Math.max(0, Math.floor(value)));
  let out = '';
  for (let i = raw.length; i < 10; i++) {
    out += '0';
  }
  return out + raw;
}

function parseXref(pdf: Uint8Array): number[] | null {
  const marker = lastIndexOfAscii(pdf, 'startxref');
  if (marker < 0) {
    return null;
  }
  let i = marker + 'startxref'.length;
  while (i < pdf.length && (pdf[i] === 10 || pdf[i] === 13 || pdf[i] === 32)) {
    i++;
  }
  let digits = '';
  while (i < pdf.length && pdf[i] >= 48 && pdf[i] <= 57) {
    digits += String.fromCharCode(pdf[i]);
    i++;
  }
  const xrefAt = parseInt(digits, 10);
  if (isNaN(xrefAt) || xrefAt < 0 || xrefAt >= pdf.length) {
    return null;
  }
  const head = latin1(pdf, xrefAt, Math.min(64, pdf.length - xrefAt));
  const firstBreak = head.indexOf('\n');
  const secondBreak = firstBreak >= 0 ? head.indexOf('\n', firstBreak + 1) : -1;
  if (secondBreak < 0) {
    return null;
  }
  const countLine = head.substring(firstBreak + 1, secondBreak).trim();
  const parts = countLine.split(' ');
  if (parts.length < 2) {
    return null;
  }
  const count = parseInt(parts[1], 10);
  if (isNaN(count) || count <= 0) {
    return null;
  }
  const entryAt = xrefAt + secondBreak + 1;
  const offsets: number[] = [];
  for (let n = 0; n < count; n++) {
    const start = entryAt + n * 20;
    if (start + 18 > pdf.length) {
      return null;
    }
    const flag = pdf[start + 17];
    if (flag === 110) {
      offsets.push(parseInt(latin1(pdf, start, 10), 10));
    } else {
      offsets.push(-1);
    }
  }
  return offsets;
}

function readStream(pdf: Uint8Array, objOffset: number): Uint8Array | null {
  if (objOffset < 0 || objOffset >= pdf.length) {
    return null;
  }
  const window = latin1(pdf, objOffset, Math.min(1800, pdf.length - objOffset));
  let rel = window.indexOf('stream\n');
  let skip = 7;
  if (rel < 0) {
    rel = window.indexOf('stream\r\n');
    skip = 8;
  }
  if (rel < 0) {
    return null;
  }
  const length = dictLength(window.substring(0, rel));
  if (length < 0) {
    return null;
  }
  const start = objOffset + rel + skip;
  if (start + length > pdf.length) {
    return null;
  }
  return pdf.slice(start, start + length);
}

function dictLength(dict: string): number {
  const key = '/Length ';
  const at = dict.lastIndexOf(key);
  if (at < 0) {
    return -1;
  }
  let j = at + key.length;
  let digits = '';
  while (j < dict.length && dict.charAt(j) >= '0' && dict.charAt(j) <= '9') {
    digits += dict.charAt(j);
    j++;
  }
  const value = parseInt(digits, 10);
  return isNaN(value) ? -1 : value;
}

function latin1(bytes: Uint8Array, start: number, length: number): string {
  const end = Math.min(bytes.length, start + length);
  let out = '';
  for (let i = start; i < end; i++) {
    out += String.fromCharCode(bytes[i]);
  }
  return out;
}

function indexOfAscii(bytes: Uint8Array, needle: string): number {
  return lastOrFirst(bytes, needle, false);
}

function lastIndexOfAscii(bytes: Uint8Array, needle: string): number {
  return lastOrFirst(bytes, needle, true);
}

function lastOrFirst(bytes: Uint8Array, needle: string, last: boolean): number {
  const n = needle.length;
  if (n === 0 || bytes.length < n) {
    return -1;
  }
  let found = -1;
  for (let i = 0; i <= bytes.length - n; i++) {
    let ok = true;
    for (let j = 0; j < n; j++) {
      if (bytes[i + j] !== needle.charCodeAt(j)) {
        ok = false;
        break;
      }
    }
    if (ok) {
      found = i;
      if (!last) {
        return found;
      }
    }
  }
  return found;
}

class ByteWriter {
  private parts: Uint8Array[] = [];
  private length: number = 0;

  u8(value: number): void {
    const bytes = new Uint8Array(1);
    bytes[0] = value & 255;
    this.push(bytes);
  }

  u16(value: number): void {
    const bytes = new Uint8Array(2);
    const view = new DataView(bytes.buffer);
    view.setUint16(0, value & 0xFFFF);
    this.push(bytes);
  }

  u32(value: number): void {
    const bytes = new Uint8Array(4);
    const view = new DataView(bytes.buffer);
    view.setUint32(0, value >>> 0);
    this.push(bytes);
  }

  f64(value: number): void {
    const bytes = new Uint8Array(8);
    const view = new DataView(bytes.buffer);
    view.setFloat64(0, value);
    this.push(bytes);
  }

  bytes(value: Uint8Array): void {
    this.push(value);
  }

  text(value: string): void {
    const encoded = utf8Encode(value);
    const len = Math.min(65535, encoded.length);
    this.u16(len);
    this.push(encoded.slice(0, len));
  }

  toUint8Array(): Uint8Array {
    const out = new Uint8Array(this.length);
    let at = 0;
    for (let i = 0; i < this.parts.length; i++) {
      out.set(this.parts[i], at);
      at += this.parts[i].length;
    }
    return out;
  }

  private push(value: Uint8Array): void {
    this.parts.push(value);
    this.length += value.length;
  }
}

class ByteReader {
  private view: DataView;
  private offset: number = 0;
  failed: boolean = false;

  constructor(bytes: Uint8Array) {
    this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  }

  u8(): number {
    if (this.offset + 1 > this.view.byteLength) {
      this.failed = true;
      return 0;
    }
    const value = this.view.getUint8(this.offset);
    this.offset += 1;
    return value;
  }

  u16(): number {
    if (this.offset + 2 > this.view.byteLength) {
      this.failed = true;
      return 0;
    }
    const value = this.view.getUint16(this.offset);
    this.offset += 2;
    return value;
  }

  u32(): number {
    if (this.offset + 4 > this.view.byteLength) {
      this.failed = true;
      return 0;
    }
    const value = this.view.getUint32(this.offset);
    this.offset += 4;
    return value;
  }

  f64(): number {
    if (this.offset + 8 > this.view.byteLength) {
      this.failed = true;
      return 0;
    }
    const value = this.view.getFloat64(this.offset);
    this.offset += 8;
    return value;
  }

  bytes(length: number): Uint8Array {
    if (this.offset + length > this.view.byteLength) {
      this.failed = true;
      return new Uint8Array(0);
    }
    const out = new Uint8Array(this.view.buffer, this.view.byteOffset + this.offset, length);
    this.offset += length;
    return out.slice();
  }

  text(): string {
    const len = this.u16();
    return utf8Decode(this.bytes(len));
  }
}

export function exportPlainText(doc: PdfDocumentModel): string {
  let out = '';
  for (let i = 0; i < doc.pages.length; i++) {
    const page = doc.pages[i];
    if (out.length > 0) {
      out += '\n\n';
    }
    out += '第 ' + (i + 1) + ' 页';
    const body = joinText(page.text, page.ocrText);
    if (body.length > 0) {
      out += '\n' + body;
    }
    for (let a = 0; a < page.annotations.length; a++) {
      const ann = page.annotations[a];
      if ((ann.type === AnnKind.TEXT || ann.type === AnnKind.COMMENT) && ann.text.length > 0) {
        out += '\n' + ann.text;
      }
    }
  }
  return out;
}

export function cloneAnnotationList(list: Annotation[]): Annotation[] {
  const out: Annotation[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(cloneAnnotation(list[i]));
  }
  return out;
}
