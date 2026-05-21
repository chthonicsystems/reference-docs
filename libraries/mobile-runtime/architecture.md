---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, architecture]
summary: mobile-runtime internals — Capacitor plugins + initMobileRuntime bootstrap.
---

# Architecture

```
npm/src/
├── index.ts
├── initMobileRuntime.ts          # single bootstrap call
├── push/
│   ├── registerPushNotifications.ts
│   └── handlePushReceived.ts
├── deepLinks/
│   └── setupDeepLinks.ts
├── version/
│   ├── checkForceUpdate.ts
│   └── getResolvedVersion.ts
├── biometric/
│   └── useBiometric.ts
├── camera/
│   ├── useCamera.ts
│   └── useFilePicker.ts
└── types.ts
```

## Bootstrap

`initMobileRuntime(opts)` is the single entry point. Consumers call it once at app start (typically in `main.tsx`):

```ts
initMobileRuntime({
  apiBaseUrl,
  platform: Capacitor.getPlatform(),
  history,
  fcmTokenCallback: async (token) => await api.post('/api/notifications/register-token', { token }),
});
```

Internally, the function:

1. Calls `registerPushNotifications` (skipped on web).
2. Calls `setupDeepLinks(history)` (skipped on web).
3. Calls `checkForceUpdate(apiBaseUrl)` (returns true if force-update screen needs to render).
4. Returns `{ pushReady, deepLinksReady, requiresForceUpdate }`.

## Companion template

`chthonicsystems/mobile-shell-template` is a **git template repo**, not an npm package. Forking it gives you a Capacitor + React app with `mobile-runtime` already wired. See [RFC 0018](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0018-mobile-shell-strategy.md).

## Tests

Vitest for pure-logic helpers (`getResolvedVersion`, version comparison). Native plugin behaviour mocked.

## Related

- [`capacitor-bridge.md`](capacitor-bridge.md), [`push-notifications.md`](push-notifications.md).
