# AGENTS — `chthonicsystems/reference-docs`

**Read this before doing anything else.** This is the single bootstrap document for any agent session working on or with the Chthonic platform's technical reference. Pair it with the doc for the library you're working with under [`libraries/<lib>/`](libraries/) and you have everything you need to consume, extend, or contribute to that library cold.

A thin Kiro-flavoured pointer at [`.kiro/steering/AGENT-CONTEXT.md`](.kiro/steering/AGENT-CONTEXT.md) auto-loads when an agent enters the repo and routes the agent here. This file is the source of truth.

## TL;DR — what this repo is

The Chthonic platform is a portfolio of **25 shared libraries** (`@chthonic/*` and `@chthonicsystems/*`) extracted from [TorqueTech](https://github.com/chthonicsystems/torquetech) between 2026-04 and 2026-05. The platform powers TorqueTech (the founding product) and Phase-1 sister-products (MarineDeck, FlowLift, PetCare OS).

> **Forward-looking (2026-Q3+):** The [Jobs Enhancements program](https://github.com/chthonicsystems/architecture/tree/main/jobs-enhancements) — 17 feature PRs spec'd in `architecture/jobs-enhancements/` per [`business/products/torquetech/job-enhancements.html`](https://github.com/chthonicsystems/business/blob/main/products/torquetech/job-enhancements.html) v1.2 — will introduce **2 new shared libraries** (`@chthonic/scheduling` for staff-side resource dispatch in PR 08; `@chthonic/inventory` for stock-on-hand tracking in PR 09), bringing the inventory from 25 → 27. Per-library deep-refs for the new libs land in their respective PRs' Phase 5 docs-sync gate (no pre-creation of `libraries/scheduling/` or `libraries/inventory/` folders).

This repo is the **AI-first technical reference** for those libraries. It is **NOT**:

- The decision record for *why* a library exists or *how* it was designed → see [`chthonicsystems/architecture`](https://github.com/chthonicsystems/architecture) (RFCs).
- The library source code or tests → see each library repo (`chthonicsystems/<lib>`).
- The end-user product documentation for any product on top of the platform → that lives with the product.

It **IS**:

- A flat, predictable, agent-readable map of every library's public surface.
- The how-to-consume + how-to-extend manual for each library.
- The cross-cutting platform guides (consumption, version-pin policy, extension patterns, forking, adding a new library).

## Three repos you need to know about

| Repo | URL | Purpose |
|---|---|---|
| **architecture** | https://github.com/chthonicsystems/architecture | RFCs (decision records), product architectures, infrastructure plans, TorqueTech extraction sequence + per-PR plans. **The HOW (decisions).** |
| **reference-docs** (this repo) | https://github.com/chthonicsystems/reference-docs | Per-library deep-references + cross-cutting platform guides. **The HOW (current API surface + how to consume).** |
| **torquetech** | https://github.com/chthonicsystems/torquetech | The founding product. Source of every shared library. Reference implementation of "how a product consumes the platform". |

Plus the 25 library repos under `chthonicsystems/<lib>` (one per library), and 3 non-library template/workflow repos: `mobile-shell-template`, `devops-workflows`, `devops-template`.

## How to use this repo (agent flow)

```
1. Read AGENTS.md (you are here) — repo orientation.
2. Identify the library you're working with.
3. Read libraries/<lib>/index.md — public surface + dependencies + consumption snippet.
4. Read the page that matches your task:
   - libraries/<lib>/architecture.md     — internal structure, schema
   - libraries/<lib>/consumption.md      — full integration walkthrough
   - libraries/<lib>/extension-points.md — every interface a consumer can implement
   - libraries/<lib>/<feature>.md        — deep-reference for a specific capability
5. If the task is cross-cutting (auth pattern, version bump, new library, etc.):
   - platform/library-consumption.md  — NuGet/npm auth, package refs, version pinning
   - platform/version-policy.md       — SemVer + breaking-change protocol
   - platform/extension-patterns.md   — polymorphic FK, two-package shape, etc.
   - platform/forking-a-library.md    — last-resort guidance
   - platform/new-library.md          — how to add a 26th library
6. For decisions / rationale (why was X built this way?):
   - chthonicsystems/architecture/rfcs/<NNNN>-<topic>.md
```

`llms.txt` at the repo root is a flat manifest of every page with a one-line summary. Useful when an agent doesn't yet know which library is responsible for a concern.

## 27-library inventory

| # | Library | Purpose | Reference |
|---|---|---|---|
| 1 | `@chthonic/locale` | Date/number/currency formatting + Liquid filters + country defaults | [libraries/locale](libraries/locale/) |
| 2 | `@chthonic/identity` | Auth (JWT + OAuth) + users + customer auth + RBAC + sessions + API keys | [libraries/identity](libraries/identity/) |
| 3 | `@chthonic/tenant` | Multi-tenant root + Config Hub admin shell + generic entitlements + AppVersion + SmartLink | [libraries/tenant](libraries/tenant/) |
| 4 | `@chthonic/parties` | Customers + addresses + contacts + mobile verification | [libraries/parties](libraries/parties/) |
| 5 | `@chthonic/payments` | Provider abstraction (Stripe Phase-1) + webhook idempotency + Money type | [libraries/payments](libraries/payments/) |
| 6 | `@chthonic/audit` | Append-only audit log + IAuditLogger contract + RabbitMQ async write pipeline | [libraries/audit](libraries/audit/) |
| 7 | `@chthonic/files` | S3 + ImageSharp + signed URLs + polymorphic FK + multipart upload + DB-blob fallback | [libraries/files](libraries/files/) |
| 8 | `@chthonic/assets` | Polymorphic Asset root + IAssetSubtypeRegistry + RegisterAssetSubtype<T> | [libraries/assets](libraries/assets/) |
| 9 | `@chthonic/catalog` | Service & Product Catalog spine | [libraries/catalog](libraries/catalog/) |
| 10 | `@chthonic/templating` | Liquid engine + validator + AI-output sanitization + iframe isolation | [libraries/templating](libraries/templating/) |
| 11 | `@chthonic/notifications` | Multi-channel publisher + Liquid templates + reminders + comms | [libraries/notifications](libraries/notifications/) |
| 12 | `@chthonic/views` | Custom field definitions + per-role view configurations + ScreenSectionsRenderer | [libraries/views](libraries/views/) |
| 13 | `@chthonic/notes` | Entity annotations with polymorphic FK + threading + unread tracking | [libraries/notes](libraries/notes/) |
| 14 | `@chthonic/work` | Slimmed Job spine — Job + JobMechanic + JobApproval + auto-comments | [libraries/work](libraries/work/) |
| 15 | `@chthonic/booking` | Customer bookings + time slots + off-days + availability service | [libraries/booking](libraries/booking/) |
| 16 | `@chthonic/billing` | Estimates + invoices + Xero + QuickBooks + token encryption + inventory sync | [libraries/billing](libraries/billing/) |
| 17 | `@chthonic/ai` | Bedrock + AiToolLoop + IToolExecutor pattern + ECDSA keypair auth + AI UI shells | [libraries/ai](libraries/ai/) |
| 18 | `@chthonic/documents` | Liquid + CSS + Gotenberg PDF pipeline + 4 themes + Document Designer + AI generation | [libraries/documents](libraries/documents/) |
| 19 | `@chthonic/listings` | Public marketplace listings + 4 themes + slug rules + AI generation + listing media | [libraries/listings](libraries/listings/) |
| 20 | `@chthonic/feedback` | Internal reviews + Google Reviews integration + weighted aggregate ratings | [libraries/feedback](libraries/feedback/) |
| 21 | `@chthonic/support` | Support tickets + CTI routing + GitHub issue sync + IIssueTrackerProvider abstraction | [libraries/support](libraries/support/) |
| 22 | `@chthonic/data` | Per-tenant SQLite export | [libraries/data](libraries/data/) |
| 23 | `@chthonic/ui` | Foundational design system — MD3 + app-* + 5 page patterns + brand tokens | [libraries/ui](libraries/ui/) |
| 24 | `@chthonicsystems/mobile-runtime` | Capacitor runtime — push, deep-link, force-update, biometric, camera/file, version sync | [libraries/mobile-runtime](libraries/mobile-runtime/) |
| 25 | `@chthonicsystems/devops-scripts` | DevOps CLI: dev-start, setup-server, setup-ssl, setup-github-envs, db-backup, pre-deploy-check | [libraries/devops-scripts](libraries/devops-scripts/) |
| 26 | `@chthonicsystems/scheduling` | Vertical-agnostic staff-initiated resource scheduling — Resource + ScheduleSlot + IDispatchBoardService + 3 hooks. Distinct from `@chthonic/booking` (customer-initiated). NEW v0.1.0 in PR 08. | [libraries/scheduling](libraries/scheduling/) |
| 27 | `@chthonicsystems/inventory` | Stock-on-hand tracking — InventoryLevel + StockMovement append-only ledger + IStockService + 2 hooks. Alongside `@chthonic/catalog` (what we sell). NEW v0.1.0 in PR 09. | [libraries/inventory](libraries/inventory/) |

## Per-library page contract

Every `libraries/<lib>/index.md` follows the **same shape**, so an agent can extract identical sections from any library:

```markdown
---
library: <name>
package-nuget: Chthonic.<X>
package-npm: '@chthonicsystems/<lib>'
version: <latest published>
related-rfcs: [NNNN, NNNN]
related-libs: [<lib>, <lib>]
last-verified: 2026-05-22
tags: [<tag>, <tag>]
summary: <one-line summary>
---

# @chthonic/<lib>

## Purpose
## Public surface
### .NET
### npm
## Dependencies
## Extension points
## Consuming this library
## Related
```

Companion pages within `libraries/<lib>/`:

- `architecture.md` — internal structure, key types, schema (bare table names)
- `consumption.md` — full code-level integration walkthrough
- `extension-points.md` — every interface a consumer would implement
- `<feature>.md` × 2–4 — deep-reference for a specific capability (e.g. `liquid-filters.md` for locale, `rbac.md` for identity)

## Cross-cutting platform guides

| Page | Owns |
|---|---|
| [`platform/overview.md`](platform/overview.md) | 26-library map, tier mental model, dependency DAG |
| [`platform/library-consumption.md`](platform/library-consumption.md) | NuGet `nuget.config` + npm `.npmrc` + `GITHUB_PACKAGES_PAT` setup |
| [`platform/version-policy.md`](platform/version-policy.md) | SemVer + Conventional Commits + release-please + breaking-change protocol |
| [`platform/extension-patterns.md`](platform/extension-patterns.md) | Polymorphic FK, two-package shape, generic entitlements, Option C UI shells, migration coexistence, cross-library FK-only typing |
| [`platform/forking-a-library.md`](platform/forking-a-library.md) | Last-resort divergence guidance |
| [`platform/new-library.md`](platform/new-library.md) | How to add a 26th library |

## AI-consumption conventions

Every page in this repo follows these rules so AI agents (Kiro, Claude Code, future) get reliable retrieval:

1. **YAML front-matter on every page.** Required keys: `library`, `version`, `last-verified`. Optional but encouraged: `related-rfcs`, `related-libs`, `tags`, `summary`. The `summary` line feeds `llms.txt`.
2. **Stable, predictable paths.** `libraries/<lib>/<feature>.md`, `platform/<topic>.md`, `_archive/<deprecated>.md`. An agent can construct a path from a library name without searching.
3. **Per-library shape contract.** Every `libraries/<lib>/index.md` has the seven H2 headings above (`Purpose`, `Public surface`, `Dependencies`, `Extension points`, `Consuming this library`, `Related`) plus the two H3 sub-headings (`### .NET`, `### npm`). The shape contract is validated by [`scripts/check-shape.sh`](scripts/check-shape.sh).
4. **Self-contained pages.** Each page is useful read alone. Cross-links exist for context but the primary reading path is "open one page, learn one thing".
5. **Dense, fact-first prose.** No marketing fluff. Same density as this file. If a fact has a file path or a code snippet, include it.
6. **Mermaid for graphs, fenced code with file paths for examples.** Both render natively on github.com.
7. **No prose duplication of RFC rationale**, but all current-state facts (signatures, schemas, examples) are duplicated in this repo so a reader doesn't need to cross to `architecture/`. Decisions live in RFCs; current state lives here.

## When a doc is wrong

If an agent finds a divergence between this repo and the actual library code:

1. **Stop.** Do not improvise.
2. **Read the latest tag** of the library repo. Has the library moved? Has a new feature shipped without doc update?
3. **If the divergence is significant** (new public type, removed method, changed signature): update the relevant page in this repo first, commit with `docs(<lib>): <description>`, and bump the page's `last-verified` front-matter field.
4. **If the divergence is small** (a typo, a stale version number): fix in passing.

The page is a contract between past-author and future-executor. Keep it accurate.

## Decision log (key conventions)

| Decision | Rationale |
|---|---|
| **Plain markdown, no static site** | Primary consumer is AI; static-site HTML chrome is overhead, not signal. github.com renders markdown + mermaid natively. Humans browse rarely. |
| **AI-first conventions** (front-matter, llms.txt, AGENTS.md, shape contract) | Reliable retrieval beats prose readability. Both Claude Code and Kiro consume these natively. |
| **One repo for all libraries** (vs per-library `docs/`) | Cross-library lookup is the dominant access pattern. Centralised lets agents grep one repo. |
| **Self-contained pages** (vs link-back to RFC) | RFCs are decision records; they aren't current-state truth. Duplicating the current-state facts here means agents don't need to merge two sources. |
| **Stable paths** (`libraries/<lib>/<feature>.md`) | Agents can construct URLs without searching. |
| **Per-library shape contract** | Same questions get same-positioned answers across all 25 libraries. Predictable retrieval. |
| **No version inventory** in this repo | Library versions in consumer repos drift; a snapshot would be wrong within days. Run `grep '@chthonicsystems\|Chthonic\.' api/<Project>.csproj web/package.json` in the consumer for live truth. |

## Repo statistics

- 25 libraries, each with `index.md` + `architecture.md` + `consumption.md` + `extension-points.md` + 2–4 feature deep-refs
- 6 cross-cutting platform guides
- 1 root manifest (`llms.txt`) + 1 README + 1 CONTRIBUTING + this AGENTS.md (and its Kiro-mirror)
- ~150 markdown files at v0.1.0
- 750+ internal cross-links

## Repo-local tooling

| Script | Purpose |
|---|---|
| [`scripts/check-shape.sh`](scripts/check-shape.sh) | Validate every `libraries/*/index.md` has the seven required H2 headings + valid YAML front-matter. |
| [`scripts/check-links.sh`](scripts/check-links.sh) | Validate every relative link resolves and every `chthonicsystems/<repo>` reference points to a real repo. |
| [`scripts/regen-llms.sh`](scripts/regen-llms.sh) | Regenerate `llms.txt` from filesystem walk + page front-matter `summary` field. |

Run all three before opening a PR:

```bash
scripts/check-shape.sh && scripts/check-links.sh && scripts/regen-llms.sh
```

## Quick links

- [`README.md`](README.md) — short human-facing landing
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — front-matter spec, shape contract, how to add a new library doc
- [`llms.txt`](llms.txt) — flat manifest
- [`platform/`](platform/) — six cross-cutting guides
- [`libraries/`](libraries/) — 25 library directories
- [`_archive/`](_archive/) — frozen pre-extraction docs that don't apply post-platform-extraction
- [`chthonicsystems/architecture`](https://github.com/chthonicsystems/architecture) — RFCs (decision records)
- [`chthonicsystems/torquetech`](https://github.com/chthonicsystems/torquetech) — founding product, reference consumer

You now have everything you need. Read the page for your library and execute.
