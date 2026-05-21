---
library: assets
package-nuget: Chthonic.Assets
package-npm: '@chthonicsystems/assets'
version: 0.1.0
related-rfcs: [0008]
related-libs: [tenant, parties, audit]
last-verified: 2026-05-22
tags: [core-domain, polymorphism, tph]
summary: Polymorphic Asset root + IAssetSubtypeRegistry + RegisterAssetSubtype<T>.
---

# `@chthonicsystems/assets` / `Chthonic.Assets`

Polymorphic Asset root + IAssetSubtypeRegistry + RegisterAssetSubtype<T>.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/assets/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[tenant, parties, audit]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/assets](https://github.com/chthonicsystems/assets)
- RFCs: [0008]
- Related libraries: [tenant, parties, audit]
