# Contributing

This file owns the **format rules** for every page in the repo. Before opening a PR, every change must satisfy:

1. Valid YAML front-matter on every modified/new page.
2. The per-library `index.md` shape contract (seven H2 headings, two H3 sub-headings).
3. Every relative link resolves.
4. `llms.txt` regenerated.

The three repo-local scripts at [`scripts/`](scripts/) automate (1)–(4):

```bash
scripts/check-shape.sh && scripts/check-links.sh && scripts/regen-llms.sh
```

## YAML front-matter

Every `.md` page under `libraries/` and `platform/` MUST start with a YAML front-matter block. Required keys:

| Key | Type | Example |
|---|---|---|
| `library` | string | `locale` (use `_platform_` for cross-cutting `platform/` pages) |
| `version` | string | `0.1.0` (latest published library tag, or `2026-05-22` for platform pages) |
| `last-verified` | ISO date | `2026-05-22` |

Optional but encouraged:

| Key | Type | Example |
|---|---|---|
| `related-rfcs` | list of integers | `[0003, 0020]` (RFC numbers in `chthonicsystems/architecture/rfcs/`) |
| `related-libs` | list of strings | `[identity, audit]` |
| `tags` | list of strings | `[foundational, formatting]` |
| `summary` | string | One-line summary; used by `regen-llms.sh` for `llms.txt` |
| `package-nuget` | string | `Chthonic.Locale` (only on library `index.md`) |
| `package-npm` | string | `'@chthonicsystems/locale'` (only on library `index.md`; quote because `@` is YAML-significant) |

Example library `index.md` front-matter:

```yaml
---
library: locale
package-nuget: Chthonic.Locale
package-npm: '@chthonicsystems/locale'
version: 0.1.0
related-rfcs: [0003]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [foundational, formatting]
summary: Date/number/currency formatting + Liquid filters + country defaults.
---
```

## Per-library `index.md` shape contract

Every `libraries/<lib>/index.md` has these headings, in this order, with no extras above the first H2:

```markdown
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

Validated by [`scripts/check-shape.sh`](scripts/check-shape.sh).

## Companion pages within `libraries/<lib>/`

Every library has these companion pages alongside `index.md`:

| Page | Purpose |
|---|---|
| `architecture.md` | Internal structure, key types with file paths, schema (bare table names), EF migration registration |
| `consumption.md` | Full code-level integration walkthrough (nuget.config + .npmrc + DI + bootstrap) |
| `extension-points.md` | Every interface a consumer would implement, with TT and sister-product examples |
| `<feature>.md` × 2–4 | Deep-reference for a specific capability (e.g. `liquid-filters.md`, `rbac.md`) |

Pick feature pages that match the library's actual capabilities. Examples:

- `locale/`: `liquid-filters.md`, `country-defaults.md`, `terminology.md`, `timezone-validation.md`
- `identity/`: `auth-flow.md`, `rbac.md`, `customer-auth.md`, `api-keys.md`
- `payments/`: `provider-abstraction.md`, `webhook-idempotency.md`, `money-type.md`, `stripe-integration.md`

## Cross-cutting `platform/` pages

These six pages own the cross-library guidance:

| Page | Owns |
|---|---|
| `platform/overview.md` | 25-library map, tier mental model, dependency DAG |
| `platform/library-consumption.md` | NuGet/npm package consumption, GITHUB_PACKAGES_PAT setup |
| `platform/version-policy.md` | SemVer, Conventional Commits, breaking-change protocol |
| `platform/extension-patterns.md` | The 6 reusable patterns: polymorphic FK, two-package shape, generic entitlements, Option C UI shells, migration coexistence, cross-library FK-only typing |
| `platform/forking-a-library.md` | Last-resort divergence guidance |
| `platform/new-library.md` | How to add a 26th library |

Use `library: _platform_` in the front-matter for these pages.

## `llms.txt`

A flat manifest of every page in the repo, one per line, format:

```
<path><tab><summary>
```

`scripts/regen-llms.sh` walks `platform/` + `libraries/`, reads each page's `summary` front-matter field (falling back to the page's first sentence), and emits `llms.txt`. Always re-run before opening a PR.

## Adding a new library doc (e.g. when a 26th library ships)

1. **Create the directory.**

   ```bash
   mkdir libraries/<new-lib>
   ```

2. **Author `index.md` from the shape contract.** Front-matter + the seven H2 headings + the two H3 sub-headings. Fill each section with current-state facts from the library's source.

3. **Author the four mandatory companion pages:** `architecture.md`, `consumption.md`, `extension-points.md`, plus 2–4 feature deep-refs.

4. **Update [`AGENTS.md`](AGENTS.md)** — add a row to the 25-library inventory (now 26) and update the count.

5. **Run the three scripts** in order:

   ```bash
   scripts/check-shape.sh   # validates the shape contract
   scripts/check-links.sh   # validates every relative link resolves
   scripts/regen-llms.sh    # regenerates llms.txt
   ```

6. **Commit** with a Conventional Commits message:

   ```bash
   git commit -m "docs(<new-lib>): author initial reference docs"
   ```

7. **Open a PR.** The CI workflow runs the three scripts and blocks merge on failure.

## Updating an existing library doc (when a library releases a new version)

1. **Read the changelog** of the library (the library repo's `CHANGELOG.md` or release notes).

2. **Update affected pages** under `libraries/<lib>/`:
   - New public type / method / interface → update `index.md` § Public surface and the relevant deep-ref page.
   - Schema change → update `architecture.md`.
   - New extension point → update `extension-points.md`.
   - New feature with non-obvious behaviour → add a new `<feature>.md` deep-ref.

3. **Bump `version` and `last-verified`** in the front-matter of every modified page.

4. **Run the three scripts.**

5. **Commit + PR.**

## Pre-extraction TT docs being migrated

Some early reference content was lifted from TorqueTech's `docs/*.md` during the platform extraction. Where those files are migrated wholesale (rare), the originals are placed under [`_archive/`](_archive/) for historical traceability. Do not edit `_archive/` content; treat it as a frozen historical record.

## Style guide

- **Dense, fact-first prose.** Same density as [`AGENTS.md`](AGENTS.md). No marketing fluff.
- **Short paragraphs**, 2–4 lines.
- **Mermaid for graphs**, fenced code with file paths for examples (e.g. `**File:** `src/Chthonic.Locale/FormatHelper.cs``).
- **British English** for prose ("organisation", "favour", "behaviour"). American English in code identifiers (`color`, not `colour`) — match the source.
- **Headings sentence case** (`## Public surface`, not `## Public Surface`).
- **Tables for enumerations**; bullets for non-parallel lists.

## When in doubt

Read [`AGENTS.md`](AGENTS.md) — it links to the closest analogous page. If still unclear, open an issue in this repo or in `chthonicsystems/architecture` for a decision-level question.
