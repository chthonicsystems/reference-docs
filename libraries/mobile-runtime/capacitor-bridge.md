---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, capacitor]
summary: Capacitor bridge — which plugins the runtime expects + initialisation order.
---

# Capacitor bridge

`@chthonicsystems/mobile-runtime` requires these Capacitor plugins:

```json
{
  "dependencies": {
    "@capacitor/core": "^7.0.0",
    "@capacitor/app": "^7.0.0",
    "@capacitor/push-notifications": "^7.0.0",
    "@capacitor/preferences": "^7.0.0",
    "@capacitor/camera": "^7.0.0",
    "@capacitor/filesystem": "^7.0.0"
  }
}
```

## Initialisation order

```
1. initMobileRuntime called once at app start.
2. Detects platform via Capacitor.getPlatform().
3. Web: skips push + deep-links + force-update (no native plugin).
4. iOS / Android: registers all three.
```

## Plugin compatibility

Runtime tested against Capacitor 7.x. Lower versions (5.x, 6.x) work in practice but not in CI.

## Native config

The mobile-shell-template's `customize.sh` prompts for:

- App display name
- Bundle ID (iOS) / Application ID (Android)
- Brand primary colour (splash + status bar)

…then writes to `Info.plist` + `AndroidManifest.xml`.

## Related

- [`push-notifications.md`](push-notifications.md), [`deep-links.md`](deep-links.md).
