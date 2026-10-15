import { textRecognition } from '@kit.CoreVisionKit';
import { OcrBlock, OcrPort, OcrResult, RgbaImage } from 'juanshu_core';
import { toPixelMap } from './PixelBridge';

/**
 * Core Vision Kit 通用文字识别。
 * 稳定字段是整段 value（简体中文、繁体中文、英文、日文、韩文）。
 * 行框排序由核心 layoutReadingOrder 负责，接入块坐标后可直接调用。
 */
export class HarmonyOcr implements OcrPort {
  available(): boolean {
    return canIUse('SystemCapability.AI.OCR.TextRecognition');
  }

  async recognize(pixels: RgbaImage): Promise<OcrResult> {
    const result = new OcrResult();
    if (!this.available()) {
      result.engine = 'unavailable';
      return result;
    }
    try {
      const pixelMap = await toPixelMap(pixels);
      const vision: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const config: textRecognition.TextRecognitionConfiguration = { isDirectionDetectionSupported: true };
      const recognized = await textRecognition.recognizeText(vision, config);
      result.engine = 'core-vision-kit';
      result.text = recognized.value;
      if (result.text.length > 0) {
        result.blocks.push(new OcrBlock(result.text, 0, 0, 1, 1));
      }
      return result;
    } catch (err) {
      result.engine = 'failed';
      return result;
    }
  }
}
