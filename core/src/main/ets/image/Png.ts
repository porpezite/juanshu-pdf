import { RgbaImage } from '../model/Image';

/** 无压缩 deflate 的 PNG，方便在没有 zlib 的核心里导出页面和签名。 */
export function encodePng(image: RgbaImage): Uint8Array {
  const rowBytes = 1 + image.width * 4;
  const raw = new Uint8Array(rowBytes * image.height);
  for (let y = 0; y < image.height; y++) {
    const row = y * rowBytes;
    raw[row] = 0;
    const src = y * image.width * 4;
    raw.set(image.data.subarray(src, src + image.width * 4), row + 1);
  }
  const zlib = zlibStore(raw);
  const ihdr = new Uint8Array(13);
  const view = new DataView(ihdr.buffer);
  view.setUint32(0, image.width);
  view.setUint32(4, image.height);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const signature = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
  const parts: Uint8Array[] = [signature, chunk(ascii('IHDR'), ihdr), chunk(ascii('IDAT'), zlib), chunk(ascii('IEND'), new Uint8Array(0))];
  let len = 0;
  for (let i = 0; i < parts.length; i++) {
    len += parts[i].length;
  }
  const out = new Uint8Array(len);
  let offset = 0;
  for (let i = 0; i < parts.length; i++) {
    out.set(parts[i], offset);
    offset += parts[i].length;
  }
  return out;
}

function chunk(type: Uint8Array, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out.set(type, 4);
  out.set(data, 8);
  const crc = crc32(out.subarray(4, 8 + data.length));
  view.setUint32(8 + data.length, crc);
  return out;
}

function zlibStore(data: Uint8Array): Uint8Array {
  const blocks: Uint8Array[] = [];
  const max = 65535;
  let offset = 0;
  while (offset < data.length || blocks.length === 0) {
    const remain = data.length - offset;
    const take = Math.min(max, remain);
    const last = offset + take >= data.length;
    const block = new Uint8Array(5 + take);
    block[0] = last ? 1 : 0;
    block[1] = take & 255;
    block[2] = (take >> 8) & 255;
    const nlen = (~take) & 0xFFFF;
    block[3] = nlen & 255;
    block[4] = (nlen >> 8) & 255;
    if (take > 0) {
      block.set(data.subarray(offset, offset + take), 5);
    }
    blocks.push(block);
    offset += take;
    if (data.length === 0) {
      break;
    }
  }
  const adler = adler32(data);
  let body = 2;
  for (let i = 0; i < blocks.length; i++) {
    body += blocks[i].length;
  }
  const out = new Uint8Array(body + 4);
  out[0] = 0x78;
  out[1] = 0x01;
  let cursor = 2;
  for (let i = 0; i < blocks.length; i++) {
    out.set(blocks[i], cursor);
    cursor += blocks[i].length;
  }
  const view = new DataView(out.buffer);
  view.setUint32(cursor, adler);
  return out;
}

function adler32(data: Uint8Array): number {
  let a = 1;
  let b = 0;
  for (let i = 0; i < data.length; i++) {
    a = (a + data[i]) % 65521;
    b = (b + a) % 65521;
  }
  return ((b << 16) | a) >>> 0;
}

let crcTable: Uint32Array | null = null;

function crc32(data: Uint8Array): number {
  if (crcTable === null) {
    crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) {
        if ((c & 1) !== 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      crcTable[n] = c >>> 0;
    }
  }
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < data.length; i++) {
    const idx = (crc ^ data[i]) & 255;
    crc = (crcTable[idx] ^ (crc >>> 8)) >>> 0;
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

function ascii(text: string): Uint8Array {
  const out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) {
    out[i] = text.charCodeAt(i);
  }
  return out;
}
