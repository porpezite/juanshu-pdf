import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { RgbaImage } from 'juanshu_core';

export async function toPixelMap(pixels: RgbaImage): Promise<image.PixelMap> {
  const copy = new Uint8Array(pixels.data.byteLength);
  copy.set(pixels.data);
  const options: image.InitializationOptions = {
    editable: true,
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    size: { width: pixels.width, height: pixels.height }
  };
  return image.createPixelMap(copy.buffer, options);
}

export async function fromPixelMap(pixel: image.PixelMap): Promise<RgbaImage> {
  const info = await pixel.getImageInfo();
  const width = info.size.width;
  const height = info.size.height;
  const buffer = new ArrayBuffer(width * height * 4);
  await pixel.readPixelsToBuffer(buffer);
  return new RgbaImage(width, height, new Uint8Array(buffer));
}

export async function readImageUri(uri: string): Promise<RgbaImage | null> {
  let file: fileIo.File | null = null;
  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const source = image.createImageSource(file.fd);
    const decoding: image.DecodingOptions = {
      editable: true,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    };
    const pixel = await source.createPixelMap(decoding);
    const result = await fromPixelMap(pixel);
    await source.release();
    return result;
  } catch (err) {
    return null;
  } finally {
    if (file !== null) {
      fileIo.closeSync(file);
    }
  }
}

export function readRawFile(uri: string): Uint8Array | null {
  let file: fileIo.File | null = null;
  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(file.fd);
    const buffer = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buffer);
    return new Uint8Array(buffer);
  } catch (err) {
    return null;
  } finally {
    if (file !== null) {
      fileIo.closeSync(file);
    }
  }
}

export function writeRawFile(path: string, bytes: Uint8Array): void {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
  fileIo.writeSync(file.fd, copy.buffer);
  fileIo.closeSync(file);
}
