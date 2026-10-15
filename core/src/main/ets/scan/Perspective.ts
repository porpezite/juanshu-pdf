import { Point, Quad, RgbaImage, dist } from '../model/Image';

const MAX_EDGE = 2000;

/** 把四角拉成矩形。目标像素映射回源图后做双线性采样。 */
export function warpPerspective(image: RgbaImage, quad: Quad): RgbaImage {
  const top = dist(quad.topLeft, quad.topRight);
  const bottom = dist(quad.bottomLeft, quad.bottomRight);
  const left = dist(quad.topLeft, quad.bottomLeft);
  const right = dist(quad.topRight, quad.bottomRight);
  let outW = Math.max(1, Math.round(Math.max(top, bottom)));
  let outH = Math.max(1, Math.round(Math.max(left, right)));
  const edge = Math.max(outW, outH);
  if (edge > MAX_EDGE) {
    const scale = MAX_EDGE / edge;
    outW = Math.max(1, Math.round(outW * scale));
    outH = Math.max(1, Math.round(outH * scale));
  }
  const src: Point[] = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft];
  const dst: Point[] = [
    new Point(0, 0),
    new Point(outW - 1, 0),
    new Point(outW - 1, outH - 1),
    new Point(0, outH - 1)
  ];
  const h = homography(dst, src);
  const out = new RgbaImage(outW, outH);
  if (h === null) {
    return out;
  }
  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      const den = h[6] * x + h[7] * y + 1;
      const sx = (h[0] * x + h[1] * y + h[2]) / den;
      const sy = (h[3] * x + h[4] * y + h[5]) / den;
      const sample = bilinear(image, sx, sy);
      const o = out.offset(x, y);
      out.data[o] = sample[0];
      out.data[o + 1] = sample[1];
      out.data[o + 2] = sample[2];
      out.data[o + 3] = sample[3];
    }
  }
  return out;
}

function homography(src: Point[], dst: Point[]): number[] | null {
  const a: number[][] = [];
  const b: number[] = [];
  for (let i = 0; i < 4; i++) {
    const x = src[i].x;
    const y = src[i].y;
    const u = dst[i].x;
    const v = dst[i].y;
    const row1: number[] = [x, y, 1, 0, 0, 0, -x * u, -y * u];
    const row2: number[] = [0, 0, 0, x, y, 1, -x * v, -y * v];
    a.push(row1);
    b.push(u);
    a.push(row2);
    b.push(v);
  }
  return solve8(a, b);
}

function solve8(a: number[][], b: number[]): number[] | null {
  const n = 8;
  const m: number[][] = [];
  for (let i = 0; i < n; i++) {
    const row: number[] = [];
    for (let j = 0; j < n; j++) {
      row.push(a[i][j]);
    }
    row.push(b[i]);
    m.push(row);
  }
  for (let col = 0; col < n; col++) {
    let pivot = col;
    for (let r = col + 1; r < n; r++) {
      if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) {
        pivot = r;
      }
    }
    if (Math.abs(m[pivot][col]) < 1e-10) {
      return null;
    }
    if (pivot !== col) {
      const tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
    }
    const div = m[col][col];
    for (let j = col; j <= n; j++) {
      m[col][j] = m[col][j] / div;
    }
    for (let r = 0; r < n; r++) {
      if (r === col) {
        continue;
      }
      const factor = m[r][col];
      for (let j = col; j <= n; j++) {
        m[r][j] = m[r][j] - factor * m[col][j];
      }
    }
  }
  const x: number[] = [];
  for (let i = 0; i < n; i++) {
    x.push(m[i][n]);
  }
  return x;
}

function bilinear(image: RgbaImage, x: number, y: number): number[] {
  if (x < 0 || y < 0 || x > image.width - 1 || y > image.height - 1) {
    return [255, 255, 255, 255];
  }
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const x1 = Math.min(x0 + 1, image.width - 1);
  const y1 = Math.min(y0 + 1, image.height - 1);
  const tx = x - x0;
  const ty = y - y0;
  const o00 = image.offset(x0, y0);
  const o10 = image.offset(x1, y0);
  const o01 = image.offset(x0, y1);
  const o11 = image.offset(x1, y1);
  const out: number[] = [0, 0, 0, 0];
  for (let c = 0; c < 4; c++) {
    const v0 = image.data[o00 + c] * (1 - tx) + image.data[o10 + c] * tx;
    const v1 = image.data[o01 + c] * (1 - tx) + image.data[o11 + c] * tx;
    out[c] = Math.round(v0 * (1 - ty) + v1 * ty);
  }
  return out;
}
