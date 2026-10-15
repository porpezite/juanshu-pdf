/** 与平台像素格式无关的 RGBA 图。坐标原点在左上角，y 向下。 */
export class RgbaImage {
  width: number;
  height: number;
  data: Uint8Array;

  constructor(width: number, height: number, data?: Uint8Array) {
    this.width = width;
    this.height = height;
    if (data !== undefined && data.length === width * height * 4) {
      this.data = data;
    } else {
      this.data = new Uint8Array(width * height * 4);
    }
  }

  offset(x: number, y: number): number {
    return (y * this.width + x) * 4;
  }

  inBounds(x: number, y: number): boolean {
    return x >= 0 && y >= 0 && x < this.width && y < this.height;
  }
}

export class Point {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

/** 文档四角，顺序为左上、右上、右下、左下。 */
export class Quad {
  topLeft: Point;
  topRight: Point;
  bottomRight: Point;
  bottomLeft: Point;

  constructor(topLeft: Point, topRight: Point, bottomRight: Point, bottomLeft: Point) {
    this.topLeft = topLeft;
    this.topRight = topRight;
    this.bottomRight = bottomRight;
    this.bottomLeft = bottomLeft;
  }
}

export function cloneImage(image: RgbaImage): RgbaImage {
  const data = new Uint8Array(image.data.length);
  data.set(image.data);
  return new RgbaImage(image.width, image.height, data);
}

export function fillRect(image: RgbaImage, x: number, y: number, w: number, h: number,
  r: number, g: number, b: number, a: number): void {
  const x0 = clampInt(x, 0, image.width);
  const y0 = clampInt(y, 0, image.height);
  const x1 = clampInt(x + w, 0, image.width);
  const y1 = clampInt(y + h, 0, image.height);
  for (let py = y0; py < y1; py++) {
    for (let px = x0; px < x1; px++) {
      const o = image.offset(px, py);
      image.data[o] = r;
      image.data[o + 1] = g;
      image.data[o + 2] = b;
      image.data[o + 3] = a;
    }
  }
}

export function fillQuad(image: RgbaImage, quad: Quad, r: number, g: number, b: number, a: number): void {
  const pts: Point[] = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft];
  let minY = pts[0].y;
  let maxY = pts[0].y;
  for (let i = 1; i < pts.length; i++) {
    minY = Math.min(minY, pts[i].y);
    maxY = Math.max(maxY, pts[i].y);
  }
  const yStart = clampInt(Math.floor(minY), 0, image.height - 1);
  const yEnd = clampInt(Math.ceil(maxY), 0, image.height - 1);
  for (let y = yStart; y <= yEnd; y++) {
    const xs: number[] = [];
    for (let i = 0; i < 4; i++) {
      const p = pts[i];
      const q = pts[(i + 1) % 4];
      const y1 = p.y;
      const y2 = q.y;
      if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
        const t = (y - y1) / (y2 - y1);
        xs.push(p.x + t * (q.x - p.x));
      }
    }
    xs.sort((m, n) => m - n);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      const x0 = clampInt(Math.floor(xs[i]), 0, image.width);
      const x1 = clampInt(Math.ceil(xs[i + 1]), 0, image.width);
      for (let x = x0; x < x1; x++) {
        const o = image.offset(x, y);
        image.data[o] = r;
        image.data[o + 1] = g;
        image.data[o + 2] = b;
        image.data[o + 3] = a;
      }
    }
  }
}

export function luminanceAt(image: RgbaImage, x: number, y: number): number {
  const o = image.offset(x, y);
  return image.data[o] * 0.299 + image.data[o + 1] * 0.587 + image.data[o + 2] * 0.114;
}

export function blendPixel(image: RgbaImage, x: number, y: number, r: number, g: number, b: number, a: number): void {
  if (!image.inBounds(x, y) || a <= 0) {
    return;
  }
  const o = image.offset(x, y);
  const aa = a / 255;
  image.data[o] = clampInt(image.data[o] * (1 - aa) + r * aa, 0, 255);
  image.data[o + 1] = clampInt(image.data[o + 1] * (1 - aa) + g * aa, 0, 255);
  image.data[o + 2] = clampInt(image.data[o + 2] * (1 - aa) + b * aa, 0, 255);
  image.data[o + 3] = 255;
}

export function downscale(image: RgbaImage, nw: number, nh: number): RgbaImage {
  const out = new RgbaImage(Math.max(1, nw), Math.max(1, nh));
  for (let y = 0; y < out.height; y++) {
    const sy0 = Math.floor(y * image.height / out.height);
    const sy1 = Math.max(sy0 + 1, Math.floor((y + 1) * image.height / out.height));
    for (let x = 0; x < out.width; x++) {
      const sx0 = Math.floor(x * image.width / out.width);
      const sx1 = Math.max(sx0 + 1, Math.floor((x + 1) * image.width / out.width));
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      let n = 0;
      const yLimit = Math.min(sy1, image.height);
      const xLimit = Math.min(sx1, image.width);
      for (let py = sy0; py < yLimit; py++) {
        for (let px = sx0; px < xLimit; px++) {
          const o = image.offset(px, py);
          r += image.data[o];
          g += image.data[o + 1];
          b += image.data[o + 2];
          a += image.data[o + 3];
          n++;
        }
      }
      const o = out.offset(x, y);
      if (n === 0) {
        continue;
      }
      out.data[o] = Math.round(r / n);
      out.data[o + 1] = Math.round(g / n);
      out.data[o + 2] = Math.round(b / n);
      out.data[o + 3] = Math.round(a / n);
    }
  }
  return out;
}

export function downscaleMax(image: RgbaImage, maxEdge: number): RgbaImage {
  const edge = Math.max(image.width, image.height);
  if (edge <= maxEdge) {
    return image;
  }
  const scale = maxEdge / edge;
  return downscale(image, Math.max(1, Math.round(image.width * scale)), Math.max(1, Math.round(image.height * scale)));
}

export function rotateImage(image: RgbaImage, degrees: number): RgbaImage {
  const turns = ((Math.round(degrees / 90) % 4) + 4) % 4;
  if (turns === 0) {
    return cloneImage(image);
  }
  const swap = turns === 1 || turns === 3;
  const out = new RgbaImage(swap ? image.height : image.width, swap ? image.width : image.height);
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      let dx = x;
      let dy = y;
      if (turns === 1) {
        dx = image.height - 1 - y;
        dy = x;
      } else if (turns === 2) {
        dx = image.width - 1 - x;
        dy = image.height - 1 - y;
      } else {
        dx = y;
        dy = image.width - 1 - x;
      }
      const s = image.offset(x, y);
      const d = out.offset(dx, dy);
      out.data[d] = image.data[s];
      out.data[d + 1] = image.data[s + 1];
      out.data[d + 2] = image.data[s + 2];
      out.data[d + 3] = image.data[s + 3];
    }
  }
  return out;
}

export function colorChannel(color: number, shift: number): number {
  return (color >> shift) & 255;
}

export function clampInt(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return Math.round(value);
}

export function dist(a: Point, b: Point): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}
