---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, biometric]
summary: useBiometric — Face ID / Touch ID for re-authentication on app open.
---

# Biometric

`useBiometric()` wraps a Capacitor biometric plugin (e.g. `capacitor-biometric-authentication`). Used for "re-authenticate on app open" flows after a JWT expires.

## Hook

```ts
const { isAvailable, isEnabled, authenticate, enable, disable } = useBiometric({
  promptTitle: 'Sign in to TorqueTech',
  promptSubtitle: 'Use Face ID to sign in',
});

// On user opt-in (e.g. settings page):
await enable();

// On JWT expiry:
const ok = await authenticate();
if (ok) await refreshJwt();
```

## Storage

Biometric flag stored in Capacitor Preferences (NOT iOS Keychain in v0.1.0). The flag indicates "user opted in"; the actual JWT lives in localStorage as before. Future enhancement: store JWT itself in Keychain behind biometric gate.

## Platform availability

| Platform | Available |
|---|---|
| iOS | Face ID + Touch ID |
| Android | Fingerprint + Face Unlock (where supported) |
| Web | `isAvailable: false` always |

## Related

- [`extension-points.md`](extension-points.md), [`capacitor-bridge.md`](capacitor-bridge.md).
