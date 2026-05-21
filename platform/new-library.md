---
library: _platform_
version: 2026-05-22
related-rfcs: [0001, 0002]
last-verified: 2026-05-22
tags: [platform, new-library, scaffolding]
summary: How to add a 26th library — repo scaffold, package layout, RFC, extraction-sequence amendment.
---

# Adding a new library

Adding a 26th library follows the same pattern as the 25 already-extracted libraries. This guide is the canonical sequence.

## Pre-flight

Before writing any code:

1. **Author an RFC.** Draft `chthonicsystems/architecture/rfcs/<NNNN>-<topic>.md` from `_template.md`. Cover: context, decision, scope, public API surface, net-new vs reused, implementation steps, open questions.
2. **Get RFC sign-off.** Status: Accepted before extraction begins.
3. **Identify the source surface in TT** (or wherever the code currently lives) and the dependency position relative to existing libraries.
4. **Insert a new row in [`01-extraction-sequence.md`](https://github.com/chthonicsystems/architecture/blob/main/torquetech-refactor/01-extraction-sequence.md).** Pick a slot that respects dependency order. Letter-suffix the new PR number if it slots between existing canonical numbers.

## Phase 1 — library repo setup

### 1.1 Create the repo

```bash
gh repo create chthonicsystems/<new-lib> --public \
  --description "<one-line summary>" \
  --clone
cd <new-lib>
```

### 1.2 Scaffold the .NET solution (most libraries)

```
<new-lib>/
├── Chthonic.<X>.sln
├── README.md
├── LICENSE                                    # Apache-2.0 by convention
├── nuget.config                               # if the lib consumes other Chthonic libs
├── .gitignore
├── .github/workflows/release.yml              # canonical workflow (see below)
├── src/
│   ├── Chthonic.<X>/
│   │   ├── Chthonic.<X>.csproj                # PackageId = Chthonic.<X>
│   │   ├── <X>ModuleMarker.cs                 # marker class for assembly scan
│   │   ├── ServiceCollectionExtensions.cs     # AddChthonic<X>() entry point
│   │   ├── Domain/                            # entities (if applicable)
│   │   ├── Configuration/                     # EF entity configs (if applicable)
│   │   ├── Migrations/                        # EF migrations (if applicable)
│   │   ├── Endpoints/                         # minimal-API endpoints (if applicable)
│   │   ├── Services/                          # interface + implementation pairs
│   │   └── Extensions/                        # extension-point interfaces
│   └── Chthonic.<X>.Tests/
│       ├── Chthonic.<X>.Tests.csproj
│       └── *.cs                               # xUnit tests
└── npm/                                       # if the lib has a frontend surface
    ├── package.json                           # name = @chthonicsystems/<lib>
    ├── tsconfig.json
    ├── vitest.config.ts
    ├── scripts/
    │   └── copy-css.js                        # if shipping CSS modules
    └── src/
        ├── index.ts                           # public exports
        ├── adapters.ts                        # peer-injection (HTTP, auth, etc.)
        ├── types.ts
        ├── use<X>.ts                          # primary React hook
        └── components/                        # UI shells (Option C)
```

### 1.3 `Chthonic.<X>.csproj` content

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <PackageId>Chthonic.<X></PackageId>
    <Version>0.1.0</Version>
    <Authors>Chthonic Systems</Authors>
    <Description><one-line summary></Description>
    <RepositoryUrl>https://github.com/chthonicsystems/<new-lib></RepositoryUrl>
    <PackageLicenseExpression>Apache-2.0</PackageLicenseExpression>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" Version="9.0.0" />
    <!-- Per-library deps go here -->
  </ItemGroup>
</Project>
```

### 1.4 Module marker + DI extension

```csharp
// File: src/Chthonic.<X>/<X>ModuleMarker.cs
namespace Chthonic.<X>;
public sealed class <X>ModuleMarker { }
```

```csharp
// File: src/Chthonic.<X>/ServiceCollectionExtensions.cs
namespace Chthonic.<X>;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddChthonic<X>(
        this IServiceCollection services,
        IConfiguration? config = null)
    {
        services.AddScoped<I<MainService>, <MainService>>();
        // ... per-library registrations
        return services;
    }

    public static WebApplication MapChthonic<X>Endpoints(this WebApplication app)
    {
        // map endpoints if applicable
        return app;
    }
}
```

### 1.5 Frontend npm package (when applicable)

```json
{
  "name": "@chthonicsystems/<lib>",
  "version": "0.1.0",
  "license": "Apache-2.0",
  "publishConfig": { "registry": "https://npm.pkg.github.com/" },
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": ["dist/"],
  "peerDependencies": {
    "react": ">=18",
    "react-dom": ">=18"
  },
  "scripts": {
    "build": "tsc && node scripts/copy-css.js",
    "test": "vitest run"
  }
}
```

### 1.6 CI workflow

Use the canonical `release.yml` from any existing library (e.g. `chthonicsystems/locale/.github/workflows/release.yml`). Tag-driven publish to GitHub Packages. The workflow has three jobs:

```yaml
name: release
on:
  push:
    tags: ['v*']
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.0.x' }
      - run: dotnet test
  publish-nuget:
    needs: test
    runs-on: ubuntu-latest
    permissions: { contents: read, packages: write }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '9.0.x' }
      - run: dotnet pack -c Release
      - run: dotnet nuget push **/*.nupkg
                --source https://nuget.pkg.github.com/chthonicsystems/index.json
                --api-key ${{ secrets.GITHUB_TOKEN }}
                --skip-duplicate
  publish-npm:
    needs: test
    runs-on: ubuntu-latest
    permissions: { contents: read, packages: write }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', registry-url: 'https://npm.pkg.github.com/' }
      - run: cd npm && npm ci && npm run build
      - run: cd npm && npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 1.7 Initial publish

```bash
git add .
git commit -m "feat: scaffold Chthonic.<X> v0.1.0"
git tag v0.1.0
git push -u origin main --tags
```

The workflow publishes both packages to GitHub Packages. Verify at:

- https://github.com/chthonicsystems/<new-lib>/packages
- https://github.com/orgs/chthonicsystems/packages

## Phase 2 — TorqueTech consumption PR (or sister-product)

### 2.1 Add the package reference

```bash
cd ~/chthonicsystems/torquetech
git checkout main && git pull
git checkout -b extract/<new-lib>
```

```xml
<!-- api/TorqueTech.Api.csproj -->
<PackageReference Include="Chthonic.<X>" Version="0.1.0" />
```

```json
// web/package.json
"@chthonicsystems/<lib>": "0.1.0"
```

### 2.2 Wire up DI

```csharp
// File: api/Program.cs
builder.Services.AddChthonic<X>(builder.Configuration);
```

### 2.3 Register EF configs

```csharp
// File: api/Data/TorqueTechDbContext.cs
modelBuilder.ApplyConfigurationsFromAssembly(typeof(<X>ModuleMarker).Assembly);
```

### 2.4 Insert `__EFMigrationsHistory` row (idempotent)

If the new library's `0001_Initial` migration registers EF metadata for tables TT already has, insert a marker row at deploy time:

```sql
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
VALUES ('<TIMESTAMP>_Chthonic<X>_0001_Initial', '9.0.0');
```

If the migration includes genuine schema changes (table renames, new columns, FK additions), let the migration run normally.

### 2.5 Delete TT-side files (if extracting from TT)

For each file lifted to the library, `git rm` it from TT and update import sites. Use `grep -r "<old-namespace>"` to find every consumer.

### 2.6 Run the verification gate

```bash
./dev-start.sh                    # full local verification
nohup npx playwright test > /tmp/pw.txt 2>&1 &
# wait for completion, fix failures
```

### 2.7 Open a PR

Title: `Extract @chthonic/<new-lib> (PR <NN>)`. Body: copy from `chthonicsystems/architecture/torquetech-refactor/03-pr-templates/<NN>-<new-lib>.md` § 2.9 PR description template.

## Phase 3 — reference-docs update

### 3.1 Update [`AGENTS.md`](../AGENTS.md)

Add a row to the 25-library inventory table (now 26).

### 3.2 Author the per-library deep-refs

Create `libraries/<new-lib>/`:

- `index.md` (per shape contract — see [`CONTRIBUTING.md`](../CONTRIBUTING.md))
- `architecture.md`
- `consumption.md`
- `extension-points.md`
- 2–4 feature deep-refs

### 3.3 Run the three scripts

```bash
cd ~/chthonicsystems/reference-docs
scripts/check-shape.sh
scripts/check-links.sh
scripts/regen-llms.sh
```

### 3.4 PR + merge

```bash
git checkout -b docs/<new-lib>-v0.1.0
git add .
git commit -m "docs(<new-lib>): author initial reference docs"
git push -u origin docs/<new-lib>-v0.1.0
gh pr create --title "docs(<new-lib>): author initial reference docs" --body "..."
```

## Related

- [`platform/library-consumption.md`](library-consumption.md) — registry config.
- [`platform/version-policy.md`](version-policy.md) — SemVer + Conventional Commits.
- [`platform/extension-patterns.md`](extension-patterns.md) — pick your patterns first.
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md) — platform-extraction master plan (current 25-library inventory).
- [RFC 0002](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0002-shared-library-strategy.md) — repo + packaging governance.
- Per-library RFCs (`rfcs/0003-..0021`) — each library's design decision record.
