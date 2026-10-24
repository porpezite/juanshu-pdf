import { fillQuad, fillRect, Point, Quad, RgbaImage } from '../model/Image';

/** 深色桌面上的一页略微倾斜的纸，供边缘检测与无相机时的扫描演示。 */
export function sampleDocumentImage(): RgbaImage {
  const image = new RgbaImage(180, 240);
  fillRect(image, 0, 0, 180, 240, 32, 34, 36, 255);
  const quad = new Quad(
    new Point(28, 36),
    new Point(156, 30),
    new Point(164, 208),
    new Point(24, 214)
  );
  fillQuad(image, quad, 248, 246, 240, 255);
  fillRect(image, 48, 58, 90, 5, 70, 78, 74, 255);
  fillRect(image, 48, 72, 70, 5, 70, 78, 74, 255);
  fillRect(image, 48, 86, 96, 5, 70, 78, 74, 255);
  return image;
}

export function sampleQuad(): Quad {
  return new Quad(
    new Point(28, 36),
    new Point(156, 30),
    new Point(164, 208),
    new Point(24, 214)
  );
}
