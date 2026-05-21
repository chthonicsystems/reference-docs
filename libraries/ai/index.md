---
library: ai
package-nuget: Chthonic.AI
package-npm: '@chthonicsystems/ai'
version: 0.1.0
related-rfcs: [0013]
related-libs: [tenant, identity, audit]
last-verified: 2026-05-22
tags: [feature, ai, bedrock]
summary: Bedrock + AiToolLoop + IToolExecutor pattern + ECDSA keypair auth + AI UI shells.
---

# `@chthonicsystems/ai` / `Chthonic.AI`

Bedrock + AiToolLoop + IToolExecutor pattern + ECDSA keypair auth + AI UI shells.

## Purpose

_Reference docs in progress — see [governing RFC](https://github.com/chthonicsystems/architecture/blob/main/rfcs/) and [library README](https://github.com/chthonicsystems/ai/blob/main/README.md) for current intent._

## Public surface

### .NET

_See [`architecture.md`](architecture.md) and [`consumption.md`](consumption.md)._

### npm

_See [`consumption.md`](consumption.md)._

## Dependencies

Library deps: `[tenant, identity, audit]`. See [`platform/library-consumption.md`](../../platform/library-consumption.md) for resolution rules.

## Extension points

_See [`extension-points.md`](extension-points.md)._

## Consuming this library

_See [`consumption.md`](consumption.md)._

## Related

- Library repo: [chthonicsystems/ai](https://github.com/chthonicsystems/ai)
- RFCs: [0013]
- Related libraries: [tenant, identity, audit]
