---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [mobile-runtime, deep-links]
summary: setupDeepLinks — Capacitor App plugin appUrlOpen → React Router push.
---

# Deep links

`setupDeepLinks(history)` listens for Capacitor's `appUrlOpen` event:

```ts
import { App } from '@capacitor/app';

App.addListener('appUrlOpen', (event) => {
  const url = new URL(event.url);
  const path = url.pathname;
  history.push(path);
});
```

## URL shapes

| URL | Routes to |
|---|---|
| `https://torquetech.chthonicsystems.com/listing/widgets-co` | `/listing/widgets-co` |
| `https://torquetech.chthonicsystems.com/booking/42` | `/booking/42` |
| `https://torquetech.chthonicsystems.com/share/abc123` | `/share/abc123` (smart-link) |

## iOS Universal Links

`@chthonic/tenant`'s SmartLink endpoint serves `apple-app-site-association` at `/.well-known/`. iOS reads this on install + verifies. Subsequent taps open the app instead of Safari.

## Android App Links

Same shape via `assetlinks.json`. Android verifies the package fingerprint at install.

## Pickup latency

Deep-link events fire **before** React Router mounts. The runtime queues the URL + replays it once `history` is ready.

## Related

- [`libraries/tenant/smartlink.md`](../tenant/smartlink.md).
- [`capacitor-bridge.md`](capacitor-bridge.md).
