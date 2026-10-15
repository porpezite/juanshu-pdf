import assert from 'assert';
import { inflateSync } from 'zlib';
import { test } from 'node:test';
import { AnnKind, Annotation, DocSummary, OcrBlock, ScanFilter } from '../core/src/main/ets/model/Document';
import { Point, Quad, RgbaImage, fillRect } from '../core/src/main/ets/model/Image';
import { detectDocumentQuad } from '../core/src/main/ets/scan/EdgeDetect';
import { applyFilter } from '../core/src/main/ets/scan/Filters';
import { rasterizeStroke } from '../core/src/main/ets/scan/Ink';
import { warpPerspective } from '../core/src/main/ets/scan/Perspective';
import { sampleDocumentImage, sampleQuad } from '../core/src/main/ets/scan/Sample';
import { encodePng } from '../core/src/main/ets/image/Png';
import { decodePdf, encodePdf, exportPlainText } from '../core/src/main/ets/pdf/PdfCodec';
import { compressDocument, CompressSettings, createImageDocument, createTextDocument, deletePageIndexes, mergeDocuments, reorderPages, rotatePage, splitDocument } from '../core/src/main/ets/pdf/Ops';
import { decodeLibraryIndex, encodeLibraryIndex, layoutReadingOrder, parsePageRanges, recentRecords, sanitizeFileName, searchRecords } from '../core/src/main/ets/library/Query';
import { renderPage } from '../core/src/main/ets/pdf/Render';

function near(actual: number, expected: number, slack: number): void {
  assert.ok(Math.abs(actual - expected) <= slack, actual + ' not near ' + expected);
}

test('detects a skewed page and ignores inner text', () => {
  const image = sampleDocumentImage();
  const quad = detectDocumentQuad(image);
  const expected = sampleQuad();
  near(quad.topLeft.x, expected.topLeft.x, 8);
  near(quad.topLeft.y, expected.topLeft.y, 8);
  near(quad.topRight.x, expected.topRight.x, 8);
  near(quad.topRight.y, expected.topRight.y, 8);
  near(quad.bottomRight.x, expected.bottomRight.x, 8);
  near(quad.bottomRight.y, expected.bottomRight.y, 8);
  near(quad.bottomLeft.x, expected.bottomLeft.x, 8);
  near(quad.bottomLeft.y, expected.bottomLeft.y, 8);
});

test('perspective warp maps the page interior to the center', () => {
  const image = sampleDocumentImage();
  const warped = warpPerspective(image, sampleQuad());
  assert.ok(warped.width > 100 && warped.height > 150);
  const o = warped.offset(Math.floor(warped.width / 2), Math.floor(warped.height / 2));
  assert.ok(warped.data[o] > 200 && warped.data[o + 1] > 200 && warped.data[o + 2] > 200);
});

test('identity warp keeps a flat color', () => {
  const image = new RgbaImage(20, 16);
  fillRect(image, 0, 0, 20, 16, 20, 140, 90, 255);
  const quad = new Quad(new Point(0, 0), new Point(19, 0), new Point(19, 15), new Point(0, 15));
  const warped = warpPerspective(image, quad);
  const o = warped.offset(Math.floor(warped.width / 2), Math.floor(warped.height / 2));
  near(warped.data[o], 20, 8);
  near(warped.data[o + 1], 140, 8);
  near(warped.data[o + 2], 90, 8);
});

test('filters produce gray, black-white, and stronger color', () => {
  const image = new RgbaImage(8, 8);
  fillRect(image, 0, 0, 8, 8, 180, 40, 40, 255);
  const gray = applyFilter(image, ScanFilter.GRAY);
  const g = gray.offset(3, 3);
  assert.strictEqual(gray.data[g], gray.data[g + 1]);
  assert.strictEqual(gray.data[g + 1], gray.data[g + 2]);
  const bw = applyFilter(image, ScanFilter.BW);
  const b = bw.data[bw.offset(3, 3)];
  assert.ok(b === 0 || b === 255);
  const boosted = applyFilter(image, ScanFilter.COLOR);
  const srcSpread = 180 - 40;
  const o = boosted.offset(3, 3);
  const spread = Math.max(boosted.data[o], boosted.data[o + 1], boosted.data[o + 2]) -
    Math.min(boosted.data[o], boosted.data[o + 1], boosted.data[o + 2]);
  assert.ok(spread >= srcSpread);
});

test('pdf roundtrip keeps image, chinese text, ink, and signature', () => {
  const scan = new RgbaImage(12, 10);
  fillRect(scan, 0, 0, 12, 10, 240, 240, 235, 255);
  fillRect(scan, 2, 2, 4, 2, 20, 20, 20, 255);
  const doc = createImageDocument([scan], '卷舒测试');
  doc.pages[0].text = '正文';
  doc.pages[0].ocrText = '识别结果';
  const highlight = new Annotation(AnnKind.HIGHLIGHT);
  highlight.x = 0.1;
  highlight.y = 0.2;
  highlight.w = 0.4;
  highlight.h = 0.1;
  highlight.color = 0xFFE14A;
  const ink = new Annotation(AnnKind.INK);
  ink.color = 0x15342A;
  ink.points = [new Point(0.2, 0.3), new Point(0.5, 0.6), new Point(0.7, 0.4)];
  const note = new Annotation(AnnKind.TEXT);
  note.text = '批注';
  note.x = 0.1;
  note.y = 0.7;
  note.w = 0.3;
  note.h = 0.08;
  note.fontSize = 14;
  const sign = new Annotation(AnnKind.SIGNATURE);
  sign.x = 0.5;
  sign.y = 0.6;
  sign.w = 0.4;
  sign.h = 0.2;
  sign.image = rasterizeStroke(16, 10, [new Point(0.1, 0.5), new Point(0.8, 0.4)], 0x123456, 1);
  doc.pages[0].annotations = [highlight, ink, note, sign];
  const bytes = encodePdf(doc);
  assert.ok(bytes[0] === 0x25 && bytes[1] === 0x50);
  const loaded = decodePdf(bytes);
  assert.ok(loaded !== null);
  if (loaded === null) {
    return;
  }
  assert.strictEqual(loaded.title, '卷舒测试');
  assert.strictEqual(loaded.pages.length, 1);
  assert.strictEqual(loaded.pages[0].text, '正文');
  assert.strictEqual(loaded.pages[0].ocrText, '识别结果');
  assert.ok(loaded.pages[0].image !== null);
  const image = loaded.pages[0].image;
  if (image === null) {
    return;
  }
  assert.strictEqual(image.width, 12);
  assert.strictEqual(image.data[0], 240);
  assert.strictEqual(loaded.pages[0].annotations.length, 4);
  assert.strictEqual(loaded.pages[0].annotations[2].text, '批注');
  assert.strictEqual(loaded.pages[0].annotations[1].points.length, 3);
  const signature = loaded.pages[0].annotations[3].image;
  assert.ok(signature !== null);
  if (signature !== null) {
    assert.strictEqual(signature.width, 16);
    assert.ok(signature.data[3] === 0 || signature.data[3] === 255);
  }
  const text = exportPlainText(loaded);
  assert.ok(text.indexOf('正文') >= 0);
  assert.ok(text.indexOf('批注') >= 0);
  const preview = renderPage(loaded.pages[0]);
  assert.strictEqual(preview.width, 12);
});

test('merge split rotate delete reorder and compress', () => {
  const first = createTextDocument('卷舒 PDF\n扫描与编辑', '甲');
  const image = new RgbaImage(40, 30);
  fillRect(image, 0, 0, 40, 30, 10, 120, 80, 255);
  const second = createImageDocument([image], '乙');
  const merged = mergeDocuments([first, second]);
  assert.ok(merged.pages.length >= 2);
  const rotated = rotatePage(merged, 0, 90);
  assert.strictEqual(rotated.pages[0].rotation, 90);
  const order = [1, 0];
  for (let i = 2; i < merged.pages.length; i++) {
    order.push(i);
  }
  const reordered = reorderPages(rotated, order);
  assert.strictEqual(reordered.pages[0].image !== null, true);
  const groups: number[][] = [[0], [1]];
  const parts = splitDocument(reordered, groups);
  assert.strictEqual(parts.length, 2);
  const removed = deletePageIndexes(reordered, [0]);
  assert.strictEqual(removed.pages.length, reordered.pages.length - 1);
  const settings = new CompressSettings();
  settings.maxEdge = 16;
  settings.grayscale = true;
  const small = compressDocument(second, settings);
  const before = encodePdf(second).length;
  const after = encodePdf(small).length;
  assert.ok(after < before);
  assert.ok(small.pages[0].image !== null);
  const compressed = small.pages[0].image;
  if (compressed !== null) {
    assert.ok(Math.max(compressed.width, compressed.height) <= 16);
    const o = compressed.offset(0, 0);
    assert.strictEqual(compressed.data[o], compressed.data[o + 1]);
  }
});

test('library index, search, ranges, and reading order', () => {
  const item = new DocSummary();
  item.id = 'd1';
  item.name = sanitizeFileName('合同|草稿');
  item.pageCount = 3;
  item.updatedAt = 20;
  item.bytes = 100;
  item.kind = 0;
  const older = new DocSummary();
  older.id = 'd0';
  older.name = '笔记.pdf';
  older.pageCount = 1;
  older.updatedAt = 5;
  older.bytes = 10;
  const encoded = encodeLibraryIndex([item, older]);
  const decoded = decodeLibraryIndex(encoded);
  assert.strictEqual(decoded.length, 2);
  assert.strictEqual(decoded[0].name, '合同_草稿');
  assert.strictEqual(searchRecords(decoded, '合同').length, 1);
  assert.strictEqual(recentRecords(decoded, 1)[0].id, 'd1');
  const ranges = parsePageRanges('1-2,3,9', 3);
  assert.strictEqual(ranges.length, 2);
  assert.deepStrictEqual(ranges[0], [0, 1]);
  assert.deepStrictEqual(ranges[1], [2]);
  const blocks = [
    new OcrBlock('PDF', 40, 10, 20, 10),
    new OcrBlock('卷舒', 0, 12, 20, 10),
    new OcrBlock('下一行', 0, 40, 30, 10)
  ];
  assert.strictEqual(layoutReadingOrder(blocks), '卷舒 PDF\n下一行');
});

test('png encoder writes a decodable image', () => {
  const image = new RgbaImage(3, 2);
  fillRect(image, 0, 0, 3, 2, 10, 20, 30, 255);
  image.data[3] = 0;
  const png = encodePng(image);
  assert.strictEqual(png[0], 137);
  assert.strictEqual(png[1], 80);
  let offset = 8;
  let inflated: Buffer | null = null;
  while (offset + 8 <= png.length) {
    const length = png[offset] * 16777216 + png[offset + 1] * 65536 + png[offset + 2] * 256 + png[offset + 3];
    const type = String.fromCharCode(png[offset + 4], png[offset + 5], png[offset + 6], png[offset + 7]);
    const data = png.slice(offset + 8, offset + 8 + length);
    if (type === 'IDAT') {
      inflated = inflateSync(data);
    }
    offset += 12 + length;
  }
  assert.ok(inflated !== null);
  if (inflated !== null) {
    assert.strictEqual(inflated.length, 2 * (1 + 3 * 4));
    assert.strictEqual(inflated[1], 10);
    assert.strictEqual(inflated[2], 20);
    assert.strictEqual(inflated[3], 30);
  }
});
