---
library: _platform_
version: 2026-05-22
related-rfcs: [0002]
last-verified: 2026-05-22
tags: [platform, consumption, nuget, npm, github-packages]
summary: How to consume Chthonic libraries — NuGet config, npm registry, GITHUB_PACKAGES_PAT setup.
---

# Library consumption

The Chthonic platform publishes every library to **GitHub Packages**:

- **NuGet** (.NET libraries) → `https://nuget.pkg.github.com/chthonicsystems/index.json`
- **npm** (TypeScript libraries) → `https://npm.pkg.github.com/` (scope `@chthonicsystems`)

Every library follows the same publishing pipeline (see [`version-policy.md`](version-policy.md)). Every consumer repo follows the same auth setup, documented here verbatim.

## NuGet — `api/nuget.config`

Place this file at the repo root next to your `.sln`:

**File:** `api/nuget.config`

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="github-chthonic" value="https://nuget.pkg.github.com/chthonicsystems/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <github-chthonic>
      <add key="Username" value="%GITHUB_USERNAME%" />
      <add key="ClearTextPassword" value="%GITHUB_PACKAGES_PAT%" />
    </github-chthonic>
  </packageSourceCredentials>
</configuration>
```

Then add a package reference in your `.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Chthonic.Identity" Version="0.1.4" />
  <PackageReference Include="Chthonic.Tenant" Version="0.5.0" />
</ItemGroup>
```

Use **exact versions** (no `^`/`~`/version ranges). See [`version-policy.md`](version-policy.md) § "Version pinning discipline".

## npm — `web/.npmrc`

Place this file at the repo root or in your `web/`:

**File:** `web/.npmrc`

```
@chthonicsystems:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_PACKAGES_PAT}
```

Then add to `web/package.json` `dependencies`:

```json
{
  "dependencies": {
    "@chthonicsystems/identity": "0.1.4",
    "@chthonicsystems/tenant": "0.5.0"
  }
}
```

## Auth — `GITHUB_PACKAGES_PAT`

Both NuGet and npm read `GITHUB_PACKAGES_PAT` from environment variables. The PAT must have **`read:packages`** scope.

### Local dev

1. Create a fine-grained PAT at https://github.com/settings/tokens → Personal access tokens (classic) → Generate new token. Scope: `read:packages` (and `write:packages` if you publish).
2. Export in your shell rc (`~/.bashrc` / `~/.zshrc`):

   ```bash
   export GITHUB_USERNAME="your-github-username"
   export GITHUB_PACKAGES_PAT="ghp_..."
   ```

3. `source ~/.zshrc` and verify:

   ```bash
   cd ~/chthonicsystems/torquetech/api && dotnet restore
   cd ~/chthonicsystems/torquetech/web && npm install
   ```

### CI (GitHub Actions)

GitHub Actions auto-provides `secrets.GITHUB_TOKEN` with `read:packages` access to org packages. Map it into the workflow env:

```yaml
- name: Restore dependencies
  env:
    GITHUB_USERNAME: ${{ github.actor }}
    GITHUB_PACKAGES_PAT: ${{ secrets.GITHUB_TOKEN }}
  run: |
    dotnet restore
```

Or for cross-repo access (when consuming libraries from a different org or when finer-grained tokens are needed), provision a **`CHTHONIC_PACKAGES_PAT`** repo secret:

```yaml
env:
  GITHUB_USERNAME: ${{ github.actor }}
  GITHUB_PACKAGES_PAT: ${{ secrets.CHTHONIC_PACKAGES_PAT }}
```

CHTHONIC_PACKAGES_PAT was added to TT as a fix-forward during PR 03c (when cross-repo NuGet auth needed elevated scope beyond the default GITHUB_TOKEN).

## Publishing (library author side)

If you maintain a library, the canonical CI workflow lives at `.github/workflows/release.yml` in each library repo. It:

1. Triggers on `push: tags: ['v*']`.
2. Builds the .NET project + the npm sub-package.
3. Runs xUnit + vitest.
4. `dotnet pack` → `dotnet nuget push` to GitHub Packages.
5. `npm publish` to GitHub Packages with `--registry=https://npm.pkg.github.com/`.

Tag with `git tag v0.1.4 && git push --tags` to trigger.

The workflow uses `secrets.GITHUB_TOKEN` for both pushes; no PAT needed for publishing within the org.

## Verification

After consuming a new library, verify the resolution:

```bash
# .NET
dotnet restore --verbosity normal | grep "Chthonic.Identity"
# expected output:
#   Restored .../api/Project.csproj (in xxx ms).

# npm
npm ls @chthonicsystems/identity
# expected output:
#   project@version
#   └── @chthonicsystems/identity@0.1.4
```

If resolution fails:

- **Auth error**: re-check `GITHUB_USERNAME` + `GITHUB_PACKAGES_PAT` env vars; confirm PAT scope includes `read:packages`.
- **Version not found**: confirm the version exists at https://github.com/chthonicsystems/<lib>/packages.
- **Old version cached**: `dotnet nuget locals all --clear` (NuGet) or `rm -rf node_modules package-lock.json && npm install` (npm).

## Multiple libraries from the same org

The `nuget.config` and `.npmrc` shown above scope the registry to `chthonicsystems` once. Adding a 5th, 10th, 25th library is just adding another `<PackageReference>` or `dependencies` entry — no per-library config.

## Bumping a library version

See [`version-policy.md`](version-policy.md) § "Bumping a library version" for the canonical sequence.

## Related

- [`platform/version-policy.md`](version-policy.md) — SemVer + Conventional Commits + breaking-change protocol.
- [`platform/extension-patterns.md`](extension-patterns.md) — the 6 reusable patterns once libraries are imported.
- [RFC 0002 — Shared Library Strategy](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0002-shared-library-strategy.md) — governing decision record (polyrepo + GitHub Packages + SemVer).
