# Agent context — `chthonicsystems/reference-docs`

**Read [`AGENTS.md`](../../AGENTS.md) at the repo root.** That file is the canonical bootstrap document for any agent session working with this repo.

This file exists so Kiro auto-loads steering when an agent enters the repo. The full content lives in `AGENTS.md` and is intentionally not duplicated here (relative-path links would break under duplication). Open `AGENTS.md` and read from there.

## Navigation summary

```
AGENTS.md        — repo orientation, 25-library inventory, shape contract, AI conventions
README.md        — short human landing
CONTRIBUTING.md  — front-matter spec, shape contract, how to add a library doc
llms.txt         — flat manifest of every page (auto-generated)

platform/        — 6 cross-cutting guides (overview, library-consumption,
                   version-policy, extension-patterns, forking, new-library)
libraries/<lib>/ — per-library deep-refs (index, architecture, consumption,
                   extension-points, plus 2–4 feature pages)
_archive/        — frozen pre-extraction docs

scripts/check-shape.sh   — validate per-library index.md shape
scripts/check-links.sh   — validate every relative link
scripts/regen-llms.sh    — regenerate llms.txt
```

## Two-line agent flow

1. Read [`AGENTS.md`](../../AGENTS.md).
2. Identify the library you need; read [`libraries/<lib>/index.md`](../../libraries/) and the matching deep-ref page.

That's it. The platform guides under [`platform/`](../../platform/) cover cross-cutting concerns (consumption, version policy, extension patterns).
