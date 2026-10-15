import { RgbaImage, cloneImage } from '../model/Image';
import { ScanFilter } from '../model/Document';

export function applyFilter(image: RgbaImage, filter: number): RgbaImage {
  if (filter === ScanFilter.GRAY) {
    return toGray(image, false);
  }
  if (filter === ScanFilter.BW) {
    return toGray(image, true);
  }
  if (filter === ScanFilter.COLOR) {
    return colorBoost(image);
  }
  return cloneImage(image);
}

function toGray(image: RgbaImage, threshold: boolean): RgbaImage {
  const out = new RgbaImage(image.width, image.height);
  const hist: number[] = [];
  for (let i = 0; i < 256; i++) {
    hist.push(0);
  }
  const gray = new Uint8Array(image.width * image.height);
  for (let i = 0; i < gray.length; i++) {
    const o = i * 4;
    const y = Math.round(image.data[o] * 0.299 + image.data[o + 1] * 0.587 + image.data[o + 2] * 0.114);
    gray[i] = y;
    hist[y] = hist[y] + 1;
  }
  const cut = threshold ? otsu(hist, gray.length) : -1;
  for (let i = 0; i < gray.length; i++) {
    let v = gray[i];
    if (threshold) {
      v = v >= cut ? 255 : 0;
    }
    const o = i * 4;
    out.data[o] = v;
    out.data[o + 1] = v;
    out.data[o + 2] = v;
    out.data[o + 3] = 255;
  }
  return out;
}

function otsu(hist: number[], total: number): number {
  let sum = 0;
  for (let i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  let sumB = 0;
  let wB = 0;
  let maxVar = -1;
  let threshold = 128;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB === 0) {
      continue;
    }
    const wF = total - wB;
    if (wF === 0) {
      break;
    }
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const variance = wB * wF * (mB - mF) * (mB - mF);
    if (variance > maxVar) {
      maxVar = variance;
      threshold = t;
    }
  }
  return threshold;
}

function colorBoost(image: RgbaImage): RgbaImage {
  const out = cloneImage(image);
  for (let i = 0; i < image.width * image.height; i++) {
    const o = i * 4;
    let r = out.data[o] / 255;
    let g = out.data[o + 1] / 255;
    let b = out.data[o + 2] / 255;
    const max = Math.max(r, Math.max(g, b));
    const min = Math.min(r, Math.min(g, b));
    const l = (max + min) / 2;
    let s = 0;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      s = Math.min(1, s * 1.45);
      const rgb = hslToRgb(hue(r, g, b, max, min), s, l);
      r = rgb[0];
      g = rgb[1];
      b = rgb[2];
    }
    out.data[o] = contrast(r);
    out.data[o + 1] = contrast(g);
    out.data[o + 2] = contrast(b);
    out.data[o + 3] = 255;
  }
  return out;
}

function hue(r: number, g: number, b: number, max: number, min: number): number {
  const d = max - min;
  let h = 0;
  if (d === 0) {
    return 0;
  }
  if (max === r) {
    h = ((g - b) / d) % 6;
  } else if (max === g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h = h * 60;
  if (h < 0) {
    h += 360;
  }
  return h;
}

function hslToRgb(h: number, s: number, l: number): number[] {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const hp = h / 60;
  const x = c * (1 - Math.abs(hp % 2 - 1));
  let r = 0;
  let g = 0;
  let b = 0;
  if (hp < 1) {
    r = c;
    g = x;
  } else if (hp < 2) {
    r = x;
    g = c;
  } else if (hp < 3) {
    g = c;
    b = x;
  } else if (hp < 4) {
    g = x;
    b = c;
  } else if (hp < 5) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  const m = l - c / 2;
  return [r + m, g + m, b + m];
}

function contrast(channel: number): number {
  const v = (channel * 255 - 128) * 1.08 + 128;
  if (v < 0) {
    return 0;
  }
  if (v > 255) {
    return 255;
  }
  return Math.round(v);
}
