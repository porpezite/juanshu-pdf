import { blendPixel, colorChannel, Point, RgbaImage } from '../model/Image';

/** 把手写折线画进透明底图，供签名和预览。点坐标相对画布，范围 0–1。 */
export function rasterizeStroke(width: number, height: number, points: Point[], color: number, radius: number): RgbaImage {
  const image = new RgbaImage(width, height);
  const r = colorChannel(color, 16);
  const g = colorChannel(color, 8);
  const b = colorChannel(color, 0);
  if (points.length === 0) {
    return image;
  }
  if (points.length === 1) {
    stamp(image, points[0].x * (width - 1), points[0].y * (height - 1), radius, r, g, b);
    return image;
  }
  for (let i = 1; i < points.length; i++) {
    const x0 = points[i - 1].x * (width - 1);
    const y0 = points[i - 1].y * (height - 1);
    const x1 = points[i].x * (width - 1);
    const y1 = points[i].y * (height - 1);
    const steps = Math.max(1, Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))));
    for (let s = 0; s <= steps; s++) {
      const t = s / steps;
      stamp(image, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, r, g, b);
    }
  }
  return image;
}

function stamp(image: RgbaImage, x: number, y: number, radius: number, r: number, g: number, b: number): void {
  const rad = Math.max(1, radius);
  const x0 = Math.floor(x - rad);
  const y0 = Math.floor(y - rad);
  const x1 = Math.ceil(x + rad);
  const y1 = Math.ceil(y + rad);
  for (let py = y0; py <= y1; py++) {
    for (let px = x0; px <= x1; px++) {
      const dx = px - x;
      const dy = py - y;
      if (dx * dx + dy * dy <= rad * rad) {
        blendPixel(image, px, py, r, g, b, 255);
      }
    }
  }
}
