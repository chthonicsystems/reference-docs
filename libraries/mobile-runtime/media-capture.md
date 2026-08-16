---
library: mobile-runtime
version: 0.3.0
related-rfcs: [0024]
related-libs: [files]
last-verified: 2026-05-26
tags: [mobile-runtime, capacitor, camera, video, media-capture]
summary: useMediaCapture() — unified namespace returning { capturePhoto, captureVideo, pickFromLibrary, isVideoSupported }. Photo via @capacitor/camera; video via HTML5 input[capture].
---

# Media capture (`useMediaCapture`)

`@chthonicsystems/mobile-runtime` v0.3.0+ exposes
**`useMediaCapture()`** — a unified namespace covering photo + video
capture + library picking, matching the F3 QC evidence flow's needs.
Per [RFC 0024 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26).

## Surface

```ts
import { useMediaCapture } from '@chthonicsystems/mobile-runtime';

interface MediaCaptureApi {
  /** Capture a photo via the device camera. Native only — throws on web. */
  capturePhoto: (opts?: CameraOptions) => Promise<File>;

  /**
   * Capture a video via the device camera. Uses HTML5
   * `<input type="file" accept="video/*" capture="environment">` which
   * launches the native camera in video mode on iOS Safari + Android
   * Chrome (including Capacitor WebViews).
   */
  captureVideo: (opts?: VideoCaptureOptions) => Promise<File>;

  /**
   * Open a media library picker. `mediaTypes` controls what's selectable
   * (image only, video only, or both).
   */
  pickFromLibrary: (opts?: PickFromLibraryOptions) => Promise<File[]>;

  /** Whether video capture is supported on the current platform. */
  isVideoSupported: () => boolean;
}

interface VideoCaptureOptions {
  /** Soft client-side max duration in seconds. Server enforces hard cap. */
  maxDurationSeconds?: number;
  /** Soft client-side max size in bytes. Server enforces MaxVideoSizeBytes. */
  maxSizeBytes?: number;
}

interface PickFromLibraryOptions {
  /** Default: ['image']. Pass ['image', 'video'] to allow both. */
  mediaTypes?: ('image' | 'video')[];
  multiple?: boolean;
}
```

## Despite the name, it's not a React hook

`useMediaCapture` returns stable function references and is safe to
call from anywhere — event handlers, effects, non-React code. The
`use*` prefix matches the existing `useCamera` / `useFilePicker`
shape from v0.1.x and signals "function namespace" rather than
"data hook with state".

## How video capture works

The HTML5 `<input type="file" accept="video/*" capture="environment">`
attribute launches the device's native camera in video mode on every
modern mobile browser + every Capacitor WebView. On desktop browsers,
it opens a regular file picker.

This was chosen over `@capacitor-community/camera-preview` for v0.3.0
to avoid a new native dependency. The `useMediaCapture` API is stable;
the implementation can swap to a native plugin in a future release
without changing call sites.

## Permissions

Consumers register the permissions in their native shell:

### iOS (`Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to your camera to take photos and videos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone to record audio for videos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to attach photos and videos.</string>
```

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

> **Do not add `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`.** Google Play's
> [photo and video permissions policy](https://support.google.com/googleplay/android-developer/answer/14115180)
> prohibits these broad permissions for apps targeting Android 13+ unless
> system pickers are technically insufficient. They are not needed here:
> `pickFromLibrary` uses an HTML5 file input (system picker, no permission),
> and `@capacitor/camera` uses the Android photo picker for gallery access
> on API 33+.

## Example (TorqueTech QC evidence flow)

```tsx
import { useMediaCapture } from '@chthonicsystems/mobile-runtime';
import { useFeatureGate } from '../hooks/useFeatureGate';

const QcEvidenceSlot = ({ field, qcSignoffItemResultId, jobId }) => {
  const photoGate = useFeatureGate('PhotoAttachments');
  const videoGate = useFeatureGate('VideoAttachments');
  const mc = useMediaCapture();

  const handleTakePhoto = async () => {
    const file = await mc.capturePhoto();
    await uploadEvidence(file, 'Photo');
  };

  const handleRecordVideo = async () => {
    const file = await mc.captureVideo({ maxDurationSeconds: 60 });
    await uploadEvidence(file, 'Video');
  };

  return (
    <div className="qc-evidence-capture-row">
      {photoGate.enabled && <button onClick={handleTakePhoto}>Photo</button>}
      {videoGate.enabled && mc.isVideoSupported() && (
        <button onClick={handleRecordVideo}>Video</button>
      )}
    </div>
  );
};
```

## Deprecation: `useCamera()`

The pre-v0.3.0 `captureCameraPhoto` (from the `useCamera` namespace)
is still exported but marked `@deprecated`. Prefer
`useMediaCapture().capturePhoto` for new code; the underlying
implementation is identical (delegates to `@capacitor/camera`).

## Tests

7 vitest tests in `npm/src/__tests__/media-capture.test.ts` covering:

- `capturePhoto` delegates to `captureCameraPhoto`
- `captureVideo` opens an `<input>` with `accept=video/*` and `capture=environment`
- Soft `maxSizeBytes` rejection
- "no video selected" rejection
- `pickFromLibrary` accepts both image + video MIME types
- `pickFromLibrary` defaults to image-only
- `isVideoSupported` returns `true` in jsdom

## Cross-references

- [`index.md`](index.md), [`capacitor-bridge.md`](capacitor-bridge.md), [`extension-points.md`](extension-points.md).
- [`../files/qc-evidence.md`](../files/qc-evidence.md) — TT consumer pattern that wires `useMediaCapture` to `/api/files`.
- [RFC 0024 § 12 Amendment 1 (d)](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26).
