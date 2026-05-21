---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, extension-points]
summary: Extension points — subcommand registration + .chthonicrc.json + pre/post hooks.
---

# Extension points

| Hook | Use |
|---|---|
| Subcommand registration | Add a new command via plugin (future v0.4+) |
| `.chthonicrc.json` | Per-product config |
| Pre/post shell hooks | `.chthonic-hooks/<command>.{pre,post}.sh` |

## Per-command hooks

```bash
# Per-command pre-hook
.chthonic-hooks/dev-start.pre.sh
.chthonic-hooks/dev-start.post.sh
```

Run automatically before/after the named command. Useful for product-specific integrations (e.g. seed extra DBs, notify Slack on deploy).

## Custom subcommand (future)

v0.4+ may support plugins:

```bash
npm install --save-dev @my-org/chthonic-devops-plugin
```

The plugin registers via `package.json`:

```json
{
  "chthonic-devops-plugin": {
    "commands": ["my-custom-command"]
  }
}
```

## Related

- [`dev-start.md`](dev-start.md), [`pre-deploy-check.md`](pre-deploy-check.md).
