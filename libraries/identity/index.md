---
library: identity
package-nuget: Chthonic.Identity
package-npm: '@chthonicsystems/identity'
version: 0.1.4
related-rfcs: [0004]
related-libs: [locale, tenant, audit]
last-verified: 2026-05-22
tags: [foundational, auth, rbac]
summary: Auth (JWT + OAuth) + users + customer auth + RBAC + sessions + API keys.
---

# `@chthonicsystems/identity` / `Chthonic.Identity`

Auth (JWT + OAuth) + users + customer auth + RBAC + sessions + API keys.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/identity/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[locale, tenant, audit]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/identity](https://github.com/chthonicsystems/identity)
- RFCs: [0004]
- Related libraries: [locale, tenant, audit]
