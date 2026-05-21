---
library: notes
package-nuget: Chthonic.Notes
package-npm: '@chthonicsystems/notes'
version: 0.1.0
related-rfcs: [0011]
related-libs: [tenant, files, notifications, audit]
last-verified: 2026-05-22
tags: [cross-cutting, polymorphic-fk]
summary: Entity annotations with polymorphic FK + threading + unread tracking.
---

# `@chthonicsystems/notes` / `Chthonic.Notes`

Entity annotations with polymorphic FK + threading + unread tracking.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/notes/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[tenant, files, notifications, audit]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/notes](https://github.com/chthonicsystems/notes)
- RFCs: [0011]
- Related libraries: [tenant, files, notifications, audit]
