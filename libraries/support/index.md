---
library: support
package-nuget: Chthonic.Support
package-npm: '@chthonicsystems/support'
version: 0.1.0
related-rfcs: [0016]
related-libs: [tenant, identity, feedback]
last-verified: 2026-05-22
tags: [communications, ticketing, two-package]
summary: Support tickets + CTI routing + GitHub issue sync + IIssueTrackerProvider abstraction.
---

# `@chthonicsystems/support` / `Chthonic.Support`

Support tickets + CTI routing + GitHub issue sync + IIssueTrackerProvider abstraction.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/support/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[tenant, identity, feedback]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/support](https://github.com/chthonicsystems/support)
- RFCs: [0016]
- Related libraries: [tenant, identity, feedback]
