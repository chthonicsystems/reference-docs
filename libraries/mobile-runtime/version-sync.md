---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
last-verified: 2026-05-22
tags: [mobile-runtime, version-sync]
summary: getResolvedVersion — reads web/app_version.json + platform-specific override.
---

# Version sync

`getResolvedVersion(platform)` reads the consumer's `web/app_version.json` and returns the version string for the given platform.

## `app_version.json` shape

```json
{
  "latest": "14.2.1",
  "14.2.1": {
    "versionCode": 142001,
    "releaseNotes": "Bug fixes",
    "ios": { "version": "14.2.1" },
    "android": { "version": "14.2.1" },
    "web": { "version": "14.2.1" }
  }
}
```

`d.latest` is the version string; `d[d.latest]` carries metadata + per-platform overrides.

## Build pipeline integration

- `web/get-version.js <platform>` — outputs the resolved version.
- `web/sync-version.js <platform>` — writes the version into `build.gradle` (Android) or `project.pbxproj` (iOS).

GitHub Actions deploy workflows call these scripts to stamp native builds before submission.

## Server-side registration

When a new version ships, the workflow also POSTs to `/api/app-version` (`@chthonic/tenant`) to register the new version + release notes for the force-update flow.

## Related

- [`force-update.md`](force-update.md), [`libraries/tenant/appversion.md`](../tenant/appversion.md).
