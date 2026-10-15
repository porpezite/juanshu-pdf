import { Point, Quad, RgbaImage, dist, downscaleMax, luminanceAt } from '../model/Image';

const BG_DELTA = 28;

/**
 * 在对比背景下估计文档四角。
 * 先缩小，用边框中值亮度分离纸张，填掉文字孔洞，再取凸包并简化成四边形。
 * 失败时退回略微内缩的整页四角，方便用户再拖动。
 */
export function detectDocumentQuad(image: RgbaImage): Quad {
  if (image.width < 4 || image.height < 4) {
    return insetQuad(image.width, image.height, 0.04);
  }
  const small = downscaleMax(image, 180);
  const mask = documentMask(small);
  const boundary = boundaryPixels(mask, small.width, small.height);
  const minArea = Math.floor(small.width * small.height * 0.04);
  if (boundary.length < minArea / 8) {
    return insetQuad(image.width, image.height, 0.04);
  }
  const hull = convexHull(boundary);
  const simplified = simplifyToQuad(hull);
  if (simplified.length !== 4) {
    return insetQuad(image.width, image.height, 0.04);
  }
  const ordered = orderQuad(simplified);
  const sx = image.width / small.width;
  const sy = image.height / small.height;
  return new Quad(
    new Point(ordered.topLeft.x * sx, ordered.topLeft.y * sy),
    new Point(ordered.topRight.x * sx, ordered.topRight.y * sy),
    new Point(ordered.bottomRight.x * sx, ordered.bottomRight.y * sy),
    new Point(ordered.bottomLeft.x * sx, ordered.bottomLeft.y * sy)
  );
}

export function insetQuad(width: number, height: number, ratio: number): Quad {
  const dx = width * ratio;
  const dy = height * ratio;
  return new Quad(
    new Point(dx, dy),
    new Point(width - 1 - dx, dy),
    new Point(width - 1 - dx, height - 1 - dy),
    new Point(dx, height - 1 - dy)
  );
}

function documentMask(image: RgbaImage): Uint8Array {
  const bg = borderMedian(image);
  const mask = new Uint8Array(image.width * image.height);
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (Math.abs(luminanceAt(image, x, y) - bg) > BG_DELTA) {
        mask[y * image.width + x] = 1;
      }
    }
  }
  const outside = new Uint8Array(mask.length);
  const queue: number[] = [];
  for (let x = 0; x < image.width; x++) {
    pushOutside(mask, outside, queue, x, 0, image.width);
    pushOutside(mask, outside, queue, x, image.height - 1, image.width);
  }
  for (let y = 0; y < image.height; y++) {
    pushOutside(mask, outside, queue, 0, y, image.width);
    pushOutside(mask, outside, queue, image.width - 1, y, image.width);
  }
  let head = 0;
  const dirs = [1, -1, image.width, -image.width];
  while (head < queue.length) {
    const cur = queue[head];
    head++;
    for (let d = 0; d < dirs.length; d++) {
      const next = cur + dirs[d];
      if (next < 0 || next >= mask.length || outside[next] === 1 || mask[next] === 1) {
        continue;
      }
      const cx = cur % image.width;
      const nx = next % image.width;
      if (dirs[d] === 1 && nx === 0) {
        continue;
      }
      if (dirs[d] === -1 && cx === 0) {
        continue;
      }
      outside[next] = 1;
      queue.push(next);
    }
  }
  for (let i = 0; i < mask.length; i++) {
    if (mask[i] === 0 && outside[i] === 0) {
      mask[i] = 1;
    }
  }
  return mask;
}

function pushOutside(mask: Uint8Array, outside: Uint8Array, queue: number[], x: number, y: number, width: number): void {
  const i = y * width + x;
  if (mask[i] === 0 && outside[i] === 0) {
    outside[i] = 1;
    queue.push(i);
  }
}

function borderMedian(image: RgbaImage): number {
  const values: number[] = [];
  for (let x = 0; x < image.width; x++) {
    values.push(luminanceAt(image, x, 0));
    if (image.height > 1) {
      values.push(luminanceAt(image, x, image.height - 1));
    }
  }
  for (let y = 1; y < image.height - 1; y++) {
    values.push(luminanceAt(image, 0, y));
    if (image.width > 1) {
      values.push(luminanceAt(image, image.width - 1, y));
    }
  }
  values.sort((a, b) => a - b);
  if (values.length === 0) {
    return 0;
  }
  return values[Math.floor(values.length / 2)];
}

function boundaryPixels(mask: Uint8Array, width: number, height: number): Point[] {
  const points: Point[] = [];
  let count = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = y * width + x;
      if (mask[i] === 0) {
        continue;
      }
      count++;
      let edge = x === 0 || y === 0 || x === width - 1 || y === height - 1;
      if (!edge && (mask[i - 1] === 0 || mask[i + 1] === 0 || mask[i - width] === 0 || mask[i + width] === 0)) {
        edge = true;
      }
      if (edge) {
        points.push(new Point(x, y));
      }
    }
  }
  if (count < width * height * 0.04) {
    return [];
  }
  return points;
}

function cross(o: Point, a: Point, b: Point): number {
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
}

function convexHull(points: Point[]): Point[] {
  if (points.length <= 3) {
    return points.slice();
  }
  const pts = points.slice();
  pts.sort((p, q) => {
    if (p.x === q.x) {
      return p.y - q.y;
    }
    return p.x - q.x;
  });
  const lower: Point[] = [];
  for (let i = 0; i < pts.length; i++) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], pts[i]) <= 0) {
      lower.pop();
    }
    lower.push(pts[i]);
  }
  const upper: Point[] = [];
  for (let i = pts.length - 1; i >= 0; i--) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], pts[i]) <= 0) {
      upper.pop();
    }
    upper.push(pts[i]);
  }
  lower.pop();
  upper.pop();
  const hull: Point[] = [];
  for (let i = 0; i < lower.length; i++) {
    hull.push(lower[i]);
  }
  for (let i = 0; i < upper.length; i++) {
    hull.push(upper[i]);
  }
  return hull;
}

function perpDist(p: Point, a: Point, b: Point): number {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len = Math.sqrt(dx * dx + dy * dy);
  if (len < 1e-6) {
    return dist(p, a);
  }
  return Math.abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / len;
}

function simplifyToQuad(hull: Point[]): Point[] {
  if (hull.length <= 4) {
    return hull.slice();
  }
  let current = hull.slice();
  while (current.length > 4) {
    let minD = 1e9;
    let minI = 0;
    for (let i = 0; i < current.length; i++) {
      const prev = current[(i + current.length - 1) % current.length];
      const next = current[(i + 1) % current.length];
      const d = perpDist(current[i], prev, next);
      if (d < minD) {
        minD = d;
        minI = i;
      }
    }
    const nextPts: Point[] = [];
    for (let i = 0; i < current.length; i++) {
      if (i !== minI) {
        nextPts.push(current[i]);
      }
    }
    current = nextPts;
  }
  return current;
}

function orderQuad(pts: Point[]): Quad {
  let tl = pts[0];
  let tr = pts[0];
  let br = pts[0];
  let bl = pts[0];
  for (let i = 1; i < pts.length; i++) {
    const p = pts[i];
    if (p.x + p.y < tl.x + tl.y) {
      tl = p;
    }
    if (p.x + p.y > br.x + br.y) {
      br = p;
    }
    if (p.y - p.x < tr.y - tr.x) {
      tr = p;
    }
    if (p.y - p.x > bl.y - bl.x) {
      bl = p;
    }
  }
  if (samePoint(tl, tr) || samePoint(tl, bl) || samePoint(br, tr) || samePoint(br, bl)) {
    return orderByAngle(pts);
  }
  return new Quad(tl, tr, br, bl);
}

function samePoint(a: Point, b: Point): boolean {
  return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5;
}

function orderByAngle(pts: Point[]): Quad {
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < pts.length; i++) {
    cx += pts[i].x;
    cy += pts[i].y;
  }
  cx /= pts.length;
  cy /= pts.length;
  const sorted = pts.slice();
  sorted.sort((a, b) => Math.atan2(a.y - cy, a.x - cx) - Math.atan2(b.y - cy, b.x - cx));
  let start = 0;
  let best = sorted[0].x + sorted[0].y;
  for (let i = 1; i < sorted.length; i++) {
    const score = sorted[i].x + sorted[i].y;
    if (score < best) {
      best = score;
      start = i;
    }
  }
  return new Quad(
    sorted[start % 4],
    sorted[(start + 1) % 4],
    sorted[(start + 2) % 4],
    sorted[(start + 3) % 4]
  );
}
