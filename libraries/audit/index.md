---
library: audit
package-nuget: Chthonic.Audit
package-npm: '@chthonicsystems/audit'
version: 0.1.4
related-rfcs: [0006]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [core-domain, observability]
summary: Append-only audit log + IAuditLogger contract + RabbitMQ async write pipeline.
---

# `@chthonicsystems/audit` / `Chthonic.Audit`

Append-only audit log + IAuditLogger contract + RabbitMQ async write pipeline.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/audit/blob/main/README.md) for current intent._

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

- Library repo: [chthonicsystems/audit](https://github.com/chthonicsystems/audit)
- RFCs: [0006]
- Related libraries: [tenant]
