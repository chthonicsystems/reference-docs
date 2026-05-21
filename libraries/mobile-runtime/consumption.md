---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, consumption]
summary: Code-level integration — fork mobile-shell-template; configure 4 env vars; install runtime.
---

# Consuming `@chthonicsystems/mobile-runtime`

The canonical path is **fork `chthonicsystems/mobile-shell-template`** which ships with mobile-runtime pre-wired.

## 1. Fork the template

```bash
gh repo create my-org/<product>-mobile --template chthonicsystems/mobile-shell-template --clone
cd <product>-mobile
./scripts/customize.sh    # prompts for app name, bundle id, brand colours
```

## 2. Or wire from scratch

If you need to wire into an existing Capacitor app:

```json
"@chthonicsystems/mobile-runtime": "0.1.0",
"@capacitor/core": "^7.0.0",
"@capacitor/app": "^7.0.0",
"@capacitor/push-notifications": "^7.0.0"
```

```ts
// File: src/main.tsx
import { initMobileRuntime } from '@chthonicsystems/mobile-runtime';

initMobileRuntime({
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL,
  platform: Capacitor.getPlatform(),
  history,
});
```

## 3. Force-update screen

`checkForceUpdate` returns `requiresForceUpdate: boolean`. Render an update-required screen + link to App Store / Play Store if true.

## 4. Push token registration

After `registerPushNotifications` succeeds, the runtime calls your `fcmTokenCallback` with the FCM token. Persist via `@chthonic/notifications` registration endpoint.

## Related

- [`force-update.md`](force-update.md), [`push-notifications.md`](push-notifications.md), [`deep-links.md`](deep-links.md).
- Template repo: [chthonicsystems/mobile-shell-template](https://github.com/chthonicsystems/mobile-shell-template).
