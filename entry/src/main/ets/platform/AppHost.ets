import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import {
  Annotation, AnnKind, CapturePort, CompressSettings, DocKind, DocSummary, NativePdfPort, OcrPort,
  PdfDocumentModel, RgbaImage, createImageDocument, createTextDocument, decodePdf, deletePageIndexes,
  compressDocument, encodePdf, encodePng, ensurePdfExtension, exportPlainText, identityOrder, mergeDocuments,
  movePage, nextDocId, parsePageRanges, recentRecords, renderPage, reorderPages, rotatePage, sanitizeFileName,
  searchRecords, splitDocument
} from 'juanshu_core';
import { HarmonyCapture } from './HarmonyCapture';
import { HarmonyFiles } from './HarmonyFiles';
import { HarmonyNativePdf } from './HarmonyPdf';
import { HarmonyOcr } from './HarmonyOcr';
import { readImageUri, writeRawFile } from './PixelBridge';

/** 页面只依赖这个门面。平台能力都在 Port 实现后面。 */
export class AppHost {
  private static files: HarmonyFiles = new HarmonyFiles();
  private static native: HarmonyNativePdf = new HarmonyNativePdf();
  private static ocrEngine: HarmonyOcr = new HarmonyOcr();
  private static camera: HarmonyCapture = new HarmonyCapture();
  private static ability: common.UIAbilityContext | null = null;

  static init(context: common.UIAbilityContext): void {
    AppHost.ability = context;
    AppHost.files.bind(context);
    AppHost.camera.bind(context);
  }

  static context(): common.UIAbilityContext | null {
    return AppHost.ability;
  }

  static nativePdf(): NativePdfPort {
    return AppHost.native;
  }

  static ocr(): OcrPort {
    return AppHost.ocrEngine;
  }

  static capture(): CapturePort {
    return AppHost.camera;
  }

  static album(): HarmonyCapture {
    return AppHost.camera;
  }

  static list(): DocSummary[] {
    return AppHost.files.list();
  }

  static search(query: string): DocSummary[] {
    return searchRecords(AppHost.files.list(), query);
  }

  static recent(limit: number): DocSummary[] {
    return recentRecords(AppHost.files.list(), limit);
  }

  static find(id: string): DocSummary | null {
    const all = AppHost.files.list();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        return all[i];
      }
    }
    return null;
  }

  static load(id: string): PdfDocumentModel | null {
    const bytes = AppHost.files.readBytes(id);
    if (bytes === null) {
      return null;
    }
    return decodePdf(bytes);
  }

  static path(id: string): string {
    return AppHost.files.pathOf(id);
  }

  static saveNew(name: string, doc: PdfDocumentModel): DocSummary {
    const summary = AppHost.summaryFor(name, doc.pages.length, DocKind.JUANSHU);
    doc.title = summary.name;
    return AppHost.files.writeNew(summary, encodePdf(doc));
  }

  static saveExisting(id: string, doc: PdfDocumentModel): boolean {
    return AppHost.files.replace(id, encodePdf(doc), doc.pages.length);
  }

  static importBytes(name: string, bytes: Uint8Array): DocSummary | null {
    const model = decodePdf(bytes);
    if (model !== null) {
      model.title = sanitizeFileName(name);
      return AppHost.saveNew(name, model);
    }
    const summary = AppHost.summaryFor(name, 0, DocKind.EXTERNAL);
    const saved = AppHost.files.writeNew(summary, bytes);
    const count = AppHost.native.pageCount(AppHost.files.pathOf(saved.id));
    if (count > 0) {
      AppHost.files.touch(saved.id, count);
      saved.pageCount = count;
    }
    return saved;
  }

  static rename(id: string, name: string): boolean {
    return AppHost.files.rename(id, ensurePdfExtension(name));
  }

  static remove(id: string): void {
    AppHost.files.remove(id);
  }

  static newBlank(name: string): DocSummary {
    return AppHost.saveNew(name, createTextDocument('在此写下正文。', sanitizeFileName(name)));
  }

  static merge(ids: string[], name: string): DocSummary | null {
    if (ids.length < 2) {
      return null;
    }
    let external = false;
    const models: PdfDocumentModel[] = [];
    const paths: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      const item = AppHost.find(ids[i]);
      if (item === null) {
        return null;
      }
      paths.push(AppHost.files.pathOf(item.id));
      if (item.kind === DocKind.EXTERNAL) {
        external = true;
      }
      const model = AppHost.load(item.id);
      if (model !== null) {
        models.push(model);
      }
    }
    if (!external && models.length === ids.length) {
      return AppHost.saveNew(name, mergeDocuments(models));
    }
    const summary = AppHost.summaryFor(name, 0, DocKind.EXTERNAL);
    const output = AppHost.files.pathOf(summary.id);
    if (!AppHost.native.merge(paths, output)) {
      return null;
    }
    const count = AppHost.native.pageCount(output);
    summary.pageCount = count;
    try {
      summary.bytes = fileIo.statSync(output).size;
    } catch (err) {
      summary.bytes = 0;
    }
    return AppHost.files.registerExisting(summary);
  }

  static split(id: string, spec: string): DocSummary[] {
    const item = AppHost.find(id);
    if (item === null) {
      return [];
    }
    const model = AppHost.load(id);
    if (model !== null) {
      const groups = parsePageRanges(spec, model.pages.length);
      const parts = splitDocument(model, groups);
      const saved: DocSummary[] = [];
      for (let i = 0; i < parts.length; i++) {
        saved.push(AppHost.saveNew(item.name.replace('.pdf', '') + '-' + (i + 1), parts[i]));
      }
      return saved;
    }
    const count = item.pageCount > 0 ? item.pageCount : AppHost.native.pageCount(AppHost.path(id));
    const groups = parsePageRanges(spec, count);
    const outputs: string[] = [];
    const summaries: DocSummary[] = [];
    for (let i = 0; i < groups.length; i++) {
      const summary = AppHost.summaryFor(item.name.replace('.pdf', '') + '-' + (i + 1), groups[i].length, DocKind.EXTERNAL);
      outputs.push(AppHost.files.pathOf(summary.id));
      summaries.push(summary);
    }
    if (!AppHost.native.split(AppHost.path(id), groups, outputs)) {
      return [];
    }
    for (let i = 0; i < summaries.length; i++) {
      try {
        summaries[i].bytes = fileIo.statSync(outputs[i]).size;
      } catch (err) {
        summaries[i].bytes = 0;
      }
      AppHost.files.registerExisting(summaries[i]);
    }
    return summaries;
  }

  static rotate(id: string, index: number): boolean {
    const model = AppHost.load(id);
    if (model !== null) {
      return AppHost.saveExisting(id, rotatePage(model, index, 90));
    }
    const item = AppHost.find(id);
    if (item === null) {
      return false;
    }
    const ok = AppHost.native.rotate(AppHost.path(id), index, 90);
    if (ok) {
      AppHost.files.touch(id, item.pageCount);
    }
    return ok;
  }

  static removePage(id: string, index: number): boolean {
    const model = AppHost.load(id);
    if (model !== null) {
      if (model.pages.length <= 1) {
        return false;
      }
      const indexes: number[] = [];
      indexes.push(index);
      return AppHost.saveExisting(id, deletePageIndexes(model, indexes));
    }
    const ok = AppHost.native.deletePage(AppHost.path(id), index);
    if (ok) {
      const item = AppHost.find(id);
      const count = item === null ? 0 : Math.max(0, item.pageCount - 1);
      AppHost.files.touch(id, count);
    }
    return ok;
  }

  static move(id: string, from: number, to: number): boolean {
    const model = AppHost.load(id);
    if (model !== null) {
      const order = movePage(identityOrder(model.pages.length), from, to);
      return AppHost.saveExisting(id, reorderPages(model, order));
    }
    const ok = AppHost.native.movePage(AppHost.path(id), from, to);
    if (ok) {
      const item = AppHost.find(id);
      AppHost.files.touch(id, item === null ? 0 : item.pageCount);
    }
    return ok;
  }

  static compress(id: string, small: boolean): boolean {
    const model = AppHost.load(id);
    if (model === null) {
      return false;
    }
    const settings = new CompressSettings();
    settings.maxEdge = small ? 900 : 1400;
    settings.grayscale = small;
    return AppHost.saveExisting(id, compressDocument(model, settings));
  }

  static textOf(id: string): string {
    const model = AppHost.load(id);
    if (model === null) {
      return '';
    }
    return exportPlainText(model);
  }

  static async recognizePage(id: string, pageIndex: number): Promise<string> {
    const model = AppHost.load(id);
    if (model !== null && pageIndex >= 0 && pageIndex < model.pages.length) {
      const image = renderPage(model.pages[pageIndex]);
      const result = await AppHost.ocrEngine.recognize(image);
      if (result.text.length > 0) {
        model.pages[pageIndex].ocrText = result.text;
        AppHost.saveExisting(id, model);
      }
      return result.engine === 'unavailable' ? '' : result.text;
    }
    const directory = AppHost.files.exportDir() + '/ocr-' + id;
    const one = directory + '/page.pdf';
    const groups: number[][] = [];
    const indexes: number[] = [];
    indexes.push(pageIndex);
    groups.push(indexes);
    const outputs: string[] = [];
    outputs.push(one);
    if (!AppHost.native.split(AppHost.path(id), groups, outputs)) {
      return '';
    }
    if (!AppHost.native.convertToImages(one, directory)) {
      return '';
    }
    const images = listPng(directory);
    if (images.length === 0) {
      return '';
    }
    const pixels = await readImageUri(images[0]);
    if (pixels === null) {
      return '';
    }
    const result = await AppHost.ocrEngine.recognize(pixels);
    return result.text;
  }

  static exportImages(id: string): string[] {
    const model = AppHost.load(id);
    const paths: string[] = [];
    if (model !== null) {
      for (let i = 0; i < model.pages.length; i++) {
        const path = AppHost.files.exportDir() + '/' + id + '-' + (i + 1) + '.png';
        writeRawFile(path, encodePng(renderPage(model.pages[i])));
        paths.push(path);
      }
      return paths;
    }
    const directory = AppHost.files.exportDir() + '/' + id;
    if (AppHost.native.convertToImages(AppHost.path(id), directory)) {
      return listPng(directory);
    }
    return paths;
  }

  static imagesToPdf(images: RgbaImage[], name: string): DocSummary {
    return AppHost.saveNew(name, createImageDocument(images, sanitizeFileName(name)));
  }

  static textToPdf(text: string, name: string): DocSummary {
    return AppHost.saveNew(name, createTextDocument(text, sanitizeFileName(name)));
  }

  static async pickPdf(): Promise<DocSummary | null> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.pdf'];
      const uris = await documentPicker.select(options);
      if (uris.length === 0) {
        return null;
      }
      const bytes = await AppHost.camera.readBytes(uris[0]);
      if (bytes === null) {
        return null;
      }
      return AppHost.importBytes(fileName(uris[0]), bytes);
    } catch (err) {
      return null;
    }
  }

  static writeSignature(id: string, image: RgbaImage): string {
    const path = AppHost.files.exportDir() + '/' + id + '-sign.png';
    writeRawFile(path, encodePng(image));
    return path;
  }

  static addNativeMarkup(id: string, pageIndex: number, ann: Annotation, image: RgbaImage | null): boolean {
    let imagePath = '';
    if (ann.type === AnnKind.SIGNATURE && image !== null) {
      imagePath = AppHost.writeSignature(id, image);
    }
    const ok = AppHost.native.addMarkup(AppHost.path(id), pageIndex, ann, imagePath);
    if (ok) {
      const item = AppHost.find(id);
      AppHost.files.touch(id, item === null ? 0 : item.pageCount);
    }
    return ok;
  }

  private static summaryFor(name: string, pageCount: number, kind: number): DocSummary {
    const summary = new DocSummary();
    summary.id = nextDocId(Date.now());
    summary.name = ensurePdfExtension(name);
    summary.pageCount = pageCount;
    summary.updatedAt = Date.now();
    summary.kind = kind;
    return summary;
  }
}

function listPng(directory: string): string[] {
  const paths: string[] = [];
  try {
    const names = fileIo.listFileSync(directory);
    names.sort();
    for (let i = 0; i < names.length; i++) {
      if (names[i].toLowerCase().endsWith('.png')) {
        paths.push(directory + '/' + names[i]);
      }
    }
  } catch (err) {
  }
  return paths;
}

function fileName(uri: string): string {
  const slash = uri.lastIndexOf('/');
  const raw = slash >= 0 ? uri.substring(slash + 1) : uri;
  return raw.length > 0 ? raw : '导入文档.pdf';
}
