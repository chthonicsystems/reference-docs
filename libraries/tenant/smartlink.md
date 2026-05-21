---
library: tenant
version: 0.5.0
related-rfcs: [0004]
related-libs: [mobile-runtime]
last-verified: 2026-05-22
tags: [tenant, smart-link, deep-links, universal-links]
summary: SmartLink — universal-link redirects + iOS/Android deep-link infrastructure.
---

# SmartLink

`SmartLink` powers universal-links / deep-links across iOS (Universal Links) and Android (App Links).

## Schema

```
smart_link
  smart_link_id  int PK
  type           enum    'invoice', 'estimate', 'job', 'booking', 'public-listing', ...
  target_url     varchar deep-link path
  expires_at     datetime?
  created_at     datetime
```

## Endpoints

```
GET /api/smart-link/{shortCode}
  → 302 redirect to target_url, OR
  → universal-link unfurl response for iOS / Android

POST /api/smart-link
  Body: { type, targetPath, expiresAt? }
  → returns { shortCode, fullUrl }
```

## iOS Universal Links

The library serves the apple-app-site-association file:

```
GET /.well-known/apple-app-site-association
```

Response (Content-Type: application/json):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.com.chthonicsystems.torquetech",
        "paths": ["/listing/*", "/booking/*", "/invoice/*", "/estimate/*", "/job/*", "/share/*"]
      }
    ]
  }
}
```

iOS reads this when the app installs. Tapping a matching link in Safari / Mail / etc. opens the app directly with the path as a route.

## Android App Links

```
GET /.well-known/assetlinks.json
```

Response:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.chthonicsystems.torquetech",
      "sha256_cert_fingerprints": ["..."]
    }
  }
]
```

Android verifies the fingerprint at install time. Verified links open the app directly, bypassing the chooser.

## Mobile pickup

`@chthonicsystems/mobile-runtime` listens for deep-link launches via Capacitor's App plugin:

```ts
App.addListener('appUrlOpen', (event) => {
  const url = new URL(event.url);
  const path = url.pathname;
  history.push(path);
});
```

See [`libraries/mobile-runtime/deep-links.md`](../mobile-runtime/deep-links.md).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md).
- [`libraries/mobile-runtime/deep-links.md`](../mobile-runtime/deep-links.md).
- [RFC 0018 — Mobile Shell Strategy](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0018-mobile-shell-strategy.md).
