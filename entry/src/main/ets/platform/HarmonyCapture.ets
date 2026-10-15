import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CapturePort, RgbaImage } from 'juanshu_core';
import { fromPixelMap, readImageUri, readRawFile } from './PixelBridge';

export class HarmonyCapture implements CapturePort {
  private context: common.UIAbilityContext | null = null;

  bind(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async capturePhoto(): Promise<RgbaImage | null> {
    if (this.context === null) {
      return null;
    }
    const allowed = await ensureCamera(this.context);
    if (!allowed) {
      return null;
    }
    try {
      const picked = await cameraPicker.pick(this.context, [cameraPicker.PickerMediaType.PHOTO], {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      });
      return readImageUri(picked.resultUri);
    } catch (err) {
      return null;
    }
  }

  async pickFromAlbum(maxCount: number): Promise<string[]> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = maxCount;
      const result = await picker.select(options);
      return result.photoUris;
    } catch (err) {
      return [];
    }
  }

  async readImages(uris: string[]): Promise<RgbaImage[]> {
    const images: RgbaImage[] = [];
    for (let i = 0; i < uris.length; i++) {
      const image = await readImageUri(uris[i]);
      if (image !== null) {
        images.push(image);
      }
    }
    return images;
  }

  async readBytes(uri: string): Promise<Uint8Array | null> {
    return readRawFile(uri);
  }
}

export async function ensureCamera(context: common.UIAbilityContext): Promise<boolean> {
  try {
    const manager = abilityAccessCtrl.createAtManager();
    const grant = await manager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
    return grant.authResults.length > 0 && grant.authResults[0] === 0;
  } catch (err) {
    return false;
  }
}

/** 应用内取景。拍照结果从 PhotoOutput 的主图转成 RGBA。 */
export class HarmonyCameraSession {
  private cameraInput: camera.CameraInput | null = null;
  private photoOutput: camera.PhotoOutput | null = null;
  private session: camera.PhotoSession | null = null;
  private waiter: ((image: RgbaImage | null) => void) | null = null;

  async open(context: common.Context, surfaceId: string): Promise<boolean> {
    await this.close();
    try {
      const manager = camera.getCameraManager(context);
      const devices = manager.getSupportedCameras();
      if (devices.length === 0) {
        return false;
      }
      let device = devices[0];
      for (let i = 0; i < devices.length; i++) {
        if (devices[i].cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK) {
          device = devices[i];
          break;
        }
      }
      this.cameraInput = manager.createCameraInput(device);
      await this.cameraInput.open();
      const capability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const preview = manager.createPreviewOutput(capability.previewProfiles[0], surfaceId);
      this.photoOutput = manager.createPhotoOutput(capability.photoProfiles[0]);
      this.photoOutput.on('photoAvailable', (err: BusinessError, photo: camera.Photo) => {
        this.onPhoto(err, photo);
      });
      const created = manager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
      this.session = created;
      created.beginConfig();
      created.addInput(this.cameraInput);
      created.addOutput(preview);
      created.addOutput(this.photoOutput);
      await created.commitConfig();
      await created.start();
      return true;
    } catch (err) {
      await this.close();
      return false;
    }
  }

  capture(): Promise<RgbaImage | null> {
    return new Promise((resolve: (image: RgbaImage | null) => void) => {
      if (this.photoOutput === null) {
        resolve(null);
        return;
      }
      this.waiter = resolve;
      try {
        this.photoOutput.capture();
      } catch (err) {
        this.waiter = null;
        resolve(null);
      }
    });
  }

  async close(): Promise<void> {
    try {
      if (this.session !== null) {
        await this.session.stop();
        await this.session.release();
      }
    } catch (err) {
    }
    try {
      if (this.cameraInput !== null) {
        await this.cameraInput.close();
      }
    } catch (err) {
    }
    this.session = null;
    this.cameraInput = null;
    this.photoOutput = null;
  }

  private onPhoto(err: BusinessError, photo: camera.Photo): void {
    const done = this.waiter;
    this.waiter = null;
    if (done === null) {
      return;
    }
    if (err.code !== 0) {
      done(null);
      return;
    }
    fromPixelMap(photo.main).then((image: RgbaImage) => {
      done(image);
    }).catch(() => {
      done(null);
    });
  }
}
