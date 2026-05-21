---
library: mobile-runtime
package-npm: '@chthonicsystems/mobile-runtime'
version: 0.1.0
related-rfcs: [0018]
related-libs: [tenant, notifications, ui]
last-verified: 2026-05-22
tags: [mobile, capacitor, push-notifications, deep-links]
summary: Capacitor runtime — push, deep-link, force-update, biometric, camera/file, version sync. npm-only.
---

# `@chthonicsystems/mobile-runtime`

npm-only library. Capacitor runtime helpers shared by every product's mobile shell.

## Purpose

Mobile shells (iOS + Android) for each product reuse the same Capacitor wiring:

- Firebase Cloud Messaging (FCM) push registration + handler.
- Universal Links (iOS) + App Links (Android) deep-link pickup.
- Force-update / recommended-update gate at app launch.
- Biometric (Face ID / Touch ID) helpers.
- Camera + file-picker wrappers.
- Version sync from `app_version.json`.

Companion repo: `chthonicsystems/mobile-shell-template` (a git template repo for forking new product mobile apps).

## Public surface

### .NET

n/a — `@chthonicsystems/mobile-runtime` is an npm-only library. There is no `Chthonic.MobileRuntime` NuGet package.

### npm

| Export | Role |
|---|---|
| `initMobileRuntime(opts)` | Single bootstrap call at app start |
| `registerPushNotifications(fcmTokenCallback)` | FCM token registration |
| `setupDeepLinks(history)` | Wires `appUrlOpen` → React Router |
| `checkForceUpdate(apiBaseUrl)` | Calls `/api/app-version/latest`; shows force-update screen if needed |
| `useBiometric()` | Hook for Face ID / Touch ID auth |
| `useCamera()`, `useFilePicker()` | Camera + file pickers |
| `getResolvedVersion()` | Reads `app_version.json` |

## Dependencies

| Dep | Purpose |
|---|---|
| `@capacitor/core`, `@capacitor/app`, `@capacitor/push-notifications`, `@capacitor/preferences`, `@capacitor/camera`, `@capacitor/filesystem` | Capacitor plugins |
| `@chthonic/tenant` | `/api/app-version/latest` consumer |
| `@chthonic/notifications` | Server-side FCM dispatch matches |

## Extension points

| Hook | Use |
|---|---|
| `initMobileRuntime(opts.apiBaseUrl)` | Per-product API base |
| `initMobileRuntime(opts.fcmTokenCallback)` | Custom FCM-token persistence |
| `useBiometric` config | Per-product prompt copy |

## Consuming this library

Forking the template repo `chthonicsystems/mobile-shell-template` is the canonical path. The template ships with mobile-runtime wired in. See [`libraries/devops-scripts/`](../devops-scripts/) for related tooling.

```ts
import { initMobileRuntime } from '@chthonicsystems/mobile-runtime';

initMobileRuntime({
  apiBaseUrl: 'https://torquetech.chthonicsystems.com',
  platform: Capacitor.getPlatform(),
});
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`capacitor-bridge.md`](capacitor-bridge.md), [`push-notifications.md`](push-notifications.md), [`deep-links.md`](deep-links.md), [`force-update.md`](force-update.md), [`biometric.md`](biometric.md), [`version-sync.md`](version-sync.md).
- Library repo: [chthonicsystems/mobile-runtime](https://github.com/chthonicsystems/mobile-runtime).
- Template repo: [chthonicsystems/mobile-shell-template](https://github.com/chthonicsystems/mobile-shell-template).
- [RFC 0018](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0018-mobile-shell-strategy.md).
