---
library: tenant
package-nuget: Chthonic.Tenant
package-npm: '@chthonicsystems/tenant'
version: 0.5.0
related-rfcs: [0004]
related-libs: [identity, payments, audit]
last-verified: 2026-05-22
tags: [foundational, multi-tenancy, entitlements]
summary: Multi-tenant root + Config Hub admin shell + generic entitlements + AppVersion + SmartLink.
---

# `@chthonicsystems/tenant` / `Chthonic.Tenant`

Multi-tenant root + Config Hub admin shell + generic entitlements + AppVersion + SmartLink.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/tenant/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[identity, payments, audit]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/tenant](https://github.com/chthonicsystems/tenant)
- RFCs: [0004]
- Related libraries: [identity, payments, audit]
