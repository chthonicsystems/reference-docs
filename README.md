# `chthonicsystems/reference-docs`

AI-first technical reference for the [Chthonic platform](https://github.com/chthonicsystems/architecture/blob/main/AGENT-CONTEXT.md) — 25 shared libraries (`@chthonic/*` and `@chthonicsystems/*`) extracted from [TorqueTech](https://github.com/chthonicsystems/torquetech) between 2026-04 and 2026-05.

## Where to start

- **Agents** (Claude Code, Kiro, others): read [`AGENTS.md`](AGENTS.md) — repo orientation + 25-library inventory + shape contract.
- **Humans**: also start at [`AGENTS.md`](AGENTS.md). github.com renders the markdown + mermaid natively. There's no static site.

## Repo layout

```
.
├── AGENTS.md                    # Bootstrap: read this first
├── llms.txt                     # Flat manifest of every page
├── CONTRIBUTING.md              # Front-matter spec, shape contract
├── .kiro/steering/AGENT-CONTEXT.md   # Kiro-flavoured mirror of AGENTS.md
├── platform/                    # 6 cross-cutting guides
├── libraries/                   # 25 library directories
└── _archive/                    # frozen pre-extraction docs
```

## Conventions

- Plain markdown. github.com renders mermaid + fenced code blocks. No build step.
- YAML front-matter on every page (`library`, `version`, `last-verified`, optional `related-rfcs`/`related-libs`/`tags`/`summary`).
- Per-library `index.md` shape contract — every library has the same seven H2 headings.
- Stable paths: `libraries/<lib>/<feature>.md`, `platform/<topic>.md`.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full spec.

## Related repos

- [`chthonicsystems/architecture`](https://github.com/chthonicsystems/architecture) — RFCs (decision records).
- [`chthonicsystems/torquetech`](https://github.com/chthonicsystems/torquetech) — founding product, reference consumer.
- [`chthonicsystems/<lib>`](https://github.com/chthonicsystems/) — 25 library repos (one per library).

## Versioning

This repo follows the platform release cadence. v0.1.0 corresponds to the post-extraction state at 2026-05-22 — every library at its current published version. Subsequent releases reflect doc updates (no library code lives here).
