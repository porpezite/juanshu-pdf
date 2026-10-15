import { Annotation, DocSummary, OcrResult } from '../model/Document';
import { RgbaImage } from '../model/Image';

/** 文件库。平台只负责字节落盘，目录规则在核心。 */
export interface FilePort {
  list(): DocSummary[];
  readBytes(id: string): Uint8Array | null;
  writeNew(summary: DocSummary, bytes: Uint8Array): DocSummary;
  replace(id: string, bytes: Uint8Array, pageCount: number): boolean;
  rename(id: string, name: string): boolean;
  remove(id: string): void;
  pathOf(id: string): string;
}

/** 外部 PDF 交给系统 PDF Kit，卷舒自己生成的文档走核心编码器。 */
export interface NativePdfPort {
  available(): boolean;
  pageCount(path: string): number;
  merge(paths: string[], output: string): boolean;
  split(path: string, groups: number[][], outputs: string[]): boolean;
  deletePage(path: string, index: number): boolean;
  movePage(path: string, from: number, to: number): boolean;
  rotate(path: string, index: number, degrees: number): boolean;
  addMarkup(path: string, pageIndex: number, ann: Annotation, imagePath: string): boolean;
  convertToImages(path: string, directory: string): boolean;
}

/** 文字识别。HarmonyOS 上对应 Core Vision Kit。 */
export interface OcrPort {
  available(): boolean;
  recognize(image: RgbaImage): Promise<OcrResult>;
}

/** 拍照、相册和文件读取。界面上的系统扫描控件仍由页面承载。 */
export interface CapturePort {
  capturePhoto(): Promise<RgbaImage | null>;
  readImages(uris: string[]): Promise<RgbaImage[]>;
  readBytes(uri: string): Promise<Uint8Array | null>;
}

export interface EngineBundle {
  files: FilePort;
  nativePdf: NativePdfPort;
  ocr: OcrPort;
  capture: CapturePort;
}
