/** UTF-8 编解码。不依赖平台 util，便于核心在各端复用。 */
export function utf8Encode(text: string): Uint8Array {
  const codes: number[] = [];
  for (let i = 0; i < text.length; i++) {
    let c = text.charCodeAt(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
      const next = text.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        c = 0x10000 + ((c - 0xD800) << 10) + (next - 0xDC00);
        i++;
      }
    }
    if (c < 0x80) {
      codes.push(c);
    } else if (c < 0x800) {
      codes.push(0xC0 | (c >> 6));
      codes.push(0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
      codes.push(0xE0 | (c >> 12));
      codes.push(0x80 | ((c >> 6) & 0x3F));
      codes.push(0x80 | (c & 0x3F));
    } else {
      codes.push(0xF0 | (c >> 18));
      codes.push(0x80 | ((c >> 12) & 0x3F));
      codes.push(0x80 | ((c >> 6) & 0x3F));
      codes.push(0x80 | (c & 0x3F));
    }
  }
  const out = new Uint8Array(codes.length);
  for (let i = 0; i < codes.length; i++) {
    out[i] = codes[i];
  }
  return out;
}

export function utf8Decode(bytes: Uint8Array): string {
  let out = '';
  let i = 0;
  while (i < bytes.length) {
    const b0 = bytes[i];
    if (b0 < 0x80) {
      out += String.fromCharCode(b0);
      i++;
    } else if ((b0 & 0xE0) === 0xC0 && i + 1 < bytes.length) {
      const c = ((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
      out += String.fromCharCode(c);
      i += 2;
    } else if ((b0 & 0xF0) === 0xE0 && i + 2 < bytes.length) {
      const c = ((b0 & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
      out += String.fromCharCode(c);
      i += 3;
    } else if ((b0 & 0xF8) === 0xF0 && i + 3 < bytes.length) {
      let c = ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
      c -= 0x10000;
      out += String.fromCharCode(0xD800 + (c >> 10), 0xDC00 + (c & 0x3FF));
      i += 4;
    } else {
      i++;
    }
  }
  return out;
}

export function utf16beHex(text: string): string {
  const hex = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'];
  let out = 'FEFF';
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    out += hex[(c >> 12) & 15];
    out += hex[(c >> 8) & 15];
    out += hex[(c >> 4) & 15];
    out += hex[c & 15];
  }
  return out;
}
