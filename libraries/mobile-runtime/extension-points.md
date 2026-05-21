---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, extension-points]
summary: Extension points — initMobileRuntime opts, fcmTokenCallback, biometric prompt config.
---

# Extension points

| Hook | Use |
|---|---|
| `initMobileRuntime(opts.fcmTokenCallback)` | Persist FCM token (consumer's `/api/notifications/register-token` call) |
| `initMobileRuntime(opts.apiBaseUrl)` | Per-product API base for force-update + push registration |
| `useBiometric` config | Prompt copy ("Sign in to TorqueTech" vs "Sign in to MarineDeck") |
| Custom deep-link handler | Override default `setupDeepLinks` if non-trivial routing |

## Custom FCM token persistence

```ts
initMobileRuntime({
  apiBaseUrl,
  fcmTokenCallback: async (token) => {
    // Persist to backend
    await api.post('/api/notifications/register-token', { token, platform: 'ios' });
  },
});
```

## Custom biometric prompt

```ts
const { authenticate } = useBiometric({
  promptTitle: 'Sign in to MarineDeck',
  promptSubtitle: 'Use Face ID to sign in',
});
```

## Related

- [`consumption.md`](consumption.md), [`force-update.md`](force-update.md).
