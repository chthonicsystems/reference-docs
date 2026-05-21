---
library: data
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [data, bundling]
summary: Per-tenant bundling — single SQLite + supporting files (logos, photos) in a zip.
---

# Per-tenant bundling

Beyond the SQLite, the export bundles supporting binary files (logos, photos, listing media) into a zip.

## Bundle shape

```
export-{system_id}-{timestamp}.zip
├── data.sqlite                      # main schema + data
├── README.html                      # rendered from embedded resource
└── files/
    ├── system/logo.png
    ├── customers/customer_42_avatar.jpg
    ├── jobs/job_17/photo_1.jpg
    └── ... etc
```

The SQLite's `file` table references `s3_key`; the bundle includes the actual blob at the matching path.

## Bulk import (deferred)

A future RFC may add a corresponding **import** flow:

```
1. Admin uploads export bundle to a fresh tenant.
2. Server unzips; reads SQLite.
3. Maps old IDs → new IDs (tenant becomes a different system_id).
4. Re-uploads files to S3 with new keys.
5. Inserts rows in dependency order.
```

Out of scope for v0.1.0. The SQLite + zip format is stable now so future imports work against today's exports.

## Retention

Generated bundles in S3 expire 7 days after creation. Status row keeps for audit (`expires_at` set; `s3_key` cleared on expiry).

## Related

- [`sqlite-export.md`](sqlite-export.md), [`extension-points.md`](extension-points.md).
