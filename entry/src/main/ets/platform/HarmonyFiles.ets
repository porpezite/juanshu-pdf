import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { decodeLibraryIndex, DocSummary, encodeLibraryIndex, FilePort } from 'juanshu_core';
import { utf8Decode, utf8Encode } from 'juanshu_core';
import { writeRawFile } from './PixelBridge';

/** 沙箱文件库：索引是纯文本，PDF 以 id 命名。 */
export class HarmonyFiles implements FilePort {
  private root: string = '';
  private records: DocSummary[] = [];

  bind(context: common.UIAbilityContext): void {
    this.root = context.filesDir + '/juanshu';
    this.ensureDir(this.root);
    this.ensureDir(this.root + '/docs');
    this.ensureDir(this.root + '/exports');
    this.records = this.readIndex();
  }

  list(): DocSummary[] {
    const copy: DocSummary[] = [];
    for (let i = 0; i < this.records.length; i++) {
      copy.push(this.records[i]);
    }
    return copy;
  }

  readBytes(id: string): Uint8Array | null {
    const path = this.pathOf(id);
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } catch (err) {
      return null;
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  writeNew(summary: DocSummary, bytes: Uint8Array): DocSummary {
    writeRawFile(this.pathOf(summary.id), bytes);
    summary.bytes = bytes.byteLength;
    this.records.push(summary);
    this.persist();
    return summary;
  }

  replace(id: string, bytes: Uint8Array, pageCount: number): boolean {
    const item = this.find(id);
    if (item === null) {
      return false;
    }
    writeRawFile(this.pathOf(id), bytes);
    item.bytes = bytes.byteLength;
    item.pageCount = pageCount;
    item.updatedAt = Date.now();
    this.persist();
    return true;
  }

  rename(id: string, name: string): boolean {
    const item = this.find(id);
    if (item === null) {
      return false;
    }
    item.name = name;
    item.updatedAt = Date.now();
    this.persist();
    return true;
  }

  remove(id: string): void {
    const next: DocSummary[] = [];
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].id !== id) {
        next.push(this.records[i]);
      }
    }
    this.records = next;
    try {
      fileIo.unlinkSync(this.pathOf(id));
    } catch (err) {
    }
    this.persist();
  }

  pathOf(id: string): string {
    return this.root + '/docs/' + id + '.pdf';
  }

  exportDir(): string {
    return this.root + '/exports';
  }

  registerExisting(summary: DocSummary): DocSummary {
    this.records.push(summary);
    this.persist();
    return summary;
  }

  touch(id: string, pageCount: number): void {
    const item = this.find(id);
    if (item === null) {
      return;
    }
    item.pageCount = pageCount;
    item.updatedAt = Date.now();
    try {
      const stat = fileIo.statSync(this.pathOf(id));
      item.bytes = stat.size;
    } catch (err) {
    }
    this.persist();
  }

  private find(id: string): DocSummary | null {
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].id === id) {
        return this.records[i];
      }
    }
    return null;
  }

  private persist(): void {
    const text = encodeLibraryIndex(this.records);
    const bytes = utf8Encode(text);
    writeRawFile(this.root + '/library.txt', bytes);
  }

  private readIndex(): DocSummary[] {
    const path = this.root + '/library.txt';
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
      return decodeLibraryIndex(utf8Decode(new Uint8Array(buffer)));
    } catch (err) {
      return [];
    }
  }

  private ensureDir(path: string): void {
    try {
      fileIo.mkdirSync(path);
    } catch (err) {
    }
  }
}
