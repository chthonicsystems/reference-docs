---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [mobile-runtime, force-update]
summary: checkForceUpdate — query /api/app-version/latest at app launch; gate UI if version too old.
---

# Force-update

`checkForceUpdate(apiBaseUrl)` queries `/api/app-version/latest?platform=ios|android` (served by `@chthonic/tenant`).

## Response shape

```json
{
  "version": "14.2.1",
  "versionCode": 142001,
  "forceUpdateBelow": "14.0.0",
  "recommendedBelow": "14.1.0",
  "releaseNotes": "Bug fixes."
}
```

## Decision tree

```mermaid
graph TD
    A[App launch]
    B[GET /api/app-version/latest]
    C{my version<br/>< force_update_below?}
    D[Force-update screen — block app<br/>→ App Store / Play Store]
    E{my version<br/>< recommended_below?}
    F[Soft prompt: 'Update available']
    G[Continue]

    A --> B --> C
    C -->|yes| D
    C -->|no| E
    E -->|yes| F
    E -->|no| G
```

## Force-update screen

Renders a simple full-screen with:

- "Update required" headline.
- Release notes.
- Single button: "Update now" → opens App Store / Play Store URL.

The runtime does NOT ship the screen UI itself (consumer renders); it just returns the `requiresForceUpdate` flag.

## Related

- [`libraries/tenant/appversion.md`](../tenant/appversion.md).
- [`version-sync.md`](version-sync.md).
