---
library: payments
package-nuget: Chthonic.Payments
package-npm: '@chthonicsystems/payments'
version: 0.1.0
related-rfcs: [0005]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [core-domain, payments, two-package]
summary: Provider abstraction + webhook idempotency + Money type. Stripe impl in companion package.
---

# `@chthonicsystems/payments` / `Chthonic.Payments`

Provider abstraction + webhook idempotency + Money type. Stripe impl in companion package.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/payments/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[tenant]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/payments](https://github.com/chthonicsystems/payments)
- RFCs: [0005]
- Related libraries: [tenant]
