---
library: files
package-nuget: Chthonic.Files
package-npm: '@chthonicsystems/files'
version: 0.1.2
related-rfcs: [0007]
related-libs: [audit, tenant]
last-verified: 2026-05-22
tags: [core-domain, storage, polymorphic-fk]
summary: S3 + ImageSharp + signed URLs + polymorphic FK + multipart upload + DB-blob fallback.
---

# `@chthonicsystems/files` / `Chthonic.Files`

S3 + ImageSharp + signed URLs + polymorphic FK + multipart upload + DB-blob fallback.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/files/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[audit, tenant]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/files](https://github.com/chthonicsystems/files)
- RFCs: [0007]
- Related libraries: [audit, tenant]
