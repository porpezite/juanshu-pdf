import { DocSummary, OcrBlock } from '../model/Document';

export function sanitizeFileName(name: string): string {
  let out = '';
  const trimmed = name.trim();
  for (let i = 0; i < trimmed.length; i++) {
    const ch = trimmed.charAt(i);
    const code = trimmed.charCodeAt(i);
    if (ch === '|' || ch === '/' || ch === '\\' || ch === ':' || code < 32) {
      out += '_';
    } else {
      out += ch;
    }
  }
  if (out.length === 0) {
    return '未命名';
  }
  if (out.length > 80) {
    return out.substring(0, 80);
  }
  return out;
}

export function ensurePdfExtension(name: string): string {
  const clean = sanitizeFileName(name);
  if (clean.toLowerCase().endsWith('.pdf')) {
    return clean;
  }
  return clean + '.pdf';
}

export function searchRecords(records: DocSummary[], query: string): DocSummary[] {
  const q = query.trim().toLowerCase();
  if (q.length === 0) {
    return records.slice();
  }
  const out: DocSummary[] = [];
  for (let i = 0; i < records.length; i++) {
    if (records[i].name.toLowerCase().indexOf(q) >= 0) {
      out.push(records[i]);
    }
  }
  return out;
}

export function recentRecords(records: DocSummary[], limit: number): DocSummary[] {
  const copy = records.slice();
  copy.sort((a, b) => b.updatedAt - a.updatedAt);
  if (copy.length <= limit) {
    return copy;
  }
  return copy.slice(0, limit);
}

export function encodeLibraryIndex(records: DocSummary[]): string {
  let out = 'JUANSHU-LIB 1\n';
  for (let i = 0; i < records.length; i++) {
    const item = records[i];
    out += item.id + '|' + sanitizeFileName(item.name) + '|' + item.pageCount + '|' +
      item.updatedAt + '|' + item.bytes + '|' + item.kind + '\n';
  }
  return out;
}

export function decodeLibraryIndex(text: string): DocSummary[] {
  const lines = text.split('\n');
  const out: DocSummary[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.length === 0 || line.indexOf('JUANSHU-LIB') === 0) {
      continue;
    }
    const parts = line.split('|');
    if (parts.length < 6) {
      continue;
    }
    const item = new DocSummary();
    item.id = parts[0];
    item.name = parts[1];
    item.pageCount = parseInt(parts[2], 10);
    item.updatedAt = parseInt(parts[3], 10);
    item.bytes = parseInt(parts[4], 10);
    item.kind = parseInt(parts[5], 10);
    if (item.id.length > 0 && !isNaN(item.pageCount)) {
      out.push(item);
    }
  }
  return out;
}

/** 按行聚类后从左到右拼文字，供 OCR 结果后处理。 */
export function layoutReadingOrder(blocks: OcrBlock[]): string {
  if (blocks.length === 0) {
    return '';
  }
  const ordered = blocks.slice();
  ordered.sort((a, b) => a.y - b.y);
  const lines: OcrBlock[][] = [];
  for (let i = 0; i < ordered.length; i++) {
    const block = ordered[i];
    let placed = false;
    for (let l = 0; l < lines.length; l++) {
      const line = lines[l];
      const anchor = line[0];
      const threshold = Math.max(anchor.h, block.h) * 0.6;
      if (Math.abs(block.y - anchor.y) <= threshold) {
        line.push(block);
        placed = true;
        break;
      }
    }
    if (!placed) {
      const line: OcrBlock[] = [];
      line.push(block);
      lines.push(line);
    }
  }
  let text = '';
  for (let l = 0; l < lines.length; l++) {
    const line = lines[l];
    line.sort((a, b) => a.x - b.x);
    if (l > 0) {
      text += '\n';
    }
    for (let i = 0; i < line.length; i++) {
      if (i > 0) {
        text += ' ';
      }
      text += line[i].text;
    }
  }
  return text;
}

/**
 * 解析 "1-3,5" 这种从 1 开始的页码。每一段导出为一个文档。
 * 非法页码会被丢掉；整段都非法时该段不产生文档。
 */
export function parsePageRanges(spec: string, pageCount: number): number[][] {
  const groups = spec.split(',');
  const out: number[][] = [];
  for (let g = 0; g < groups.length; g++) {
    const token = groups[g].trim();
    if (token.length === 0) {
      continue;
    }
    const dash = token.indexOf('-');
    let start = 0;
    let end = 0;
    if (dash >= 0) {
      start = parseInt(token.substring(0, dash), 10);
      end = parseInt(token.substring(dash + 1), 10);
    } else {
      start = parseInt(token, 10);
      end = start;
    }
    if (isNaN(start) || isNaN(end)) {
      continue;
    }
    if (start > end) {
      const tmp = start;
      start = end;
      end = tmp;
    }
    const pages: number[] = [];
    for (let n = start; n <= end; n++) {
      if (n >= 1 && n <= pageCount) {
        pages.push(n - 1);
      }
    }
    if (pages.length > 0) {
      out.push(pages);
    }
  }
  return out;
}

let idSeq = 1;

export function nextDocId(now: number): string {
  idSeq++;
  return 'd' + now.toString(16) + idSeq.toString(16);
}
