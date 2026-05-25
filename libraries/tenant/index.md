---
library: tenant
package-nuget: Chthonic.Tenant
package-npm: '@chthonicsystems/tenant'
version: 0.8.0
related-rfcs: [0004]
related-libs: [identity, payments, audit, locale]
last-verified: 2026-05-22
tags: [foundational, multi-tenancy, entitlements, config-hub, app-version, smart-link]
summary: Multi-tenant root + Config Hub admin shell + generic entitlements + AppVersion + SmartLink.
---

# `@chthonicsystems/tenant` / `Chthonic.Tenant`

The multi-tenant root for every Chthonic product. Owns the `System` entity, the seven tenant-settings sections (profile / localization / tax / payment-terms / working-hours / terminology / configuration), data-driven entitlements (feature flags + tier limits + per-tenant overrides + quota tracking), the Config Hub admin shell, AppVersion (mobile force-update), and SmartLink (universal links).

## Purpose

A "tenant" in Chthonic = one `System` row. Every other library scopes data by `system_id`. This library owns:

- `System` entity + seven 1:1 settings entities (profile, localization, tax, payment-terms, working-hours, terminology, configuration).
- The Config Hub admin shell (`/config-hub` UI surface) — 13 sections in 4 groups.
- **Generic entitlements** — `tier`, `tier_limit`, `tier_feature`, `feature_override`, `quota_usage`. Data-driven flags + limits, per-tenant overrides, monthly/daily quota tracking.
- `SystemPackage` — slimmed to subscription identity (Tier + Stripe IDs) per RFC 0004 § 4a.
- `AppVersion` — mobile force-update info.
- `SmartLink` — universal-link redirects (iOS Universal Links + Android App Links).
- Tenant-signup orchestration via `ITenantSignupCompletedHandler` ports.

## Public surface

### .NET

**Package:** `Chthonic.Tenant` (NuGet, v0.5.0)

| Type | File | Role |
|---|---|---|
| `IFeatureGateService` / `FeatureGateService` | `src/Chthonic.Tenant/Entitlements/FeatureGateService.cs` | `IsEnabledAsync(flag, systemId?)` + `GetSnapshotAsync(systemId)` |
| `ILimitService` / `LimitService` | `src/Chthonic.Tenant/Entitlements/LimitService.cs` | `GetLimitAsync(name, systemId)` + `CheckQuotaAsync` + `RecordUsageAsync` |
| `ISystemService` / `SystemService` | `src/Chthonic.Tenant/Systems/SystemService.cs` | `System` CRUD (sysadmin only for create/delete) |
| `ITenantSignupOrchestrator` / `TenantSignupOrchestrator` | `src/Chthonic.Tenant/Auth/...` | Signup flow integration |
| `ISubscriptionService` | (split file) | Subscription tier resolution |
| `MapTenantEndpoints` | (split file) | `/api/systems/*`, `/api/config-hub/status`, settings endpoints |
| `MapAppVersionEndpoints` | `src/Chthonic.Tenant/AppVersionApi/AppVersionEndpoints.cs` | `/api/app-version/*` |
| `MapSmartLinkEndpoints` | (file) | `/api/smart-link/*` |
| `services.AddChthonicTenant(config)` | `src/Chthonic.Tenant/ServiceCollectionExtensions.cs` | DI entry point |

**Domain entities:** `System`, `SystemPackage`, `SystemConfiguration` (1:1), `SystemPaymentTerms` (1:1), `SystemTaxConfiguration` (1:1), `SystemTerminology` (1:1), `Tier`, `TierLimit`, `TierFeature`, `FeatureOverride`, `QuotaUsage`, `AppVersion`, `SmartLink`.

**Ports (cross-library bridges):** `ITenantSignupCompletedHandler` (consumer-side handler invoked after signup completes), more in `Abstractions/Ports.cs`.

### npm

**Package:** `@chthonicsystems/tenant` (npm, v0.5.0)

| Export | File | Role |
|---|---|---|
| `<ConfigHubShell>` | `npm/src/ConfigHubShell.tsx` | The 4-group sidebar + 13-section content area |
| `<ConfigHubLanding>` | `npm/src/ConfigHubLanding.tsx` | Default landing card |
| `<ConfigHubSidebar>` | `npm/src/ConfigHubSidebar.tsx` | Standalone sidebar component |
| `<UpgradeContext>` | `npm/src/UpgradeContext.tsx` | Feature-gated upgrade prompt provider |
| `<TerminologyContext>` | `npm/src/TerminologyContext.tsx` | Terminology context provider |
| `<SystemContext>` | `npm/src/SystemContext.tsx` | Active-tenant context provider |
| `useFeatureGate(flag)` | `npm/src/useFeatureGate.ts` | Hook returning `{ enabled, loading }` |
| `useHubStatus()` | `npm/src/useHubStatus.ts` | Returns Config Hub completion + mandatory-section flags |
| `useQuota(name)` | `npm/src/useQuota.ts` | Returns `{ remaining, limit, usage }` for a quota |

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/locale` | Country defaults + Liquid filters |
| `@chthonic/identity` (port adapter) | User context for sysadmin checks |
| `@chthonic/payments` | Subscription Stripe webhooks (consumed at app composition root) |
| `@chthonic/audit` | Audit writes on settings changes |

NB: tenant does **not** depend on `@chthonic/files` — System.LogoUrl is a string FK to a Files-managed object. See [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § "Critical non-edges".

## Extension points

| Hook | Use |
|---|---|
| `ITenantSignupCompletedHandler` (consumer port) | Run consumer-side actions after `POST /api/signup` succeeds (e.g. seed default services, send welcome email). |
| `services.AddChthonicTenant(config)` | DI entry point. Reads `STRIPE_*` env vars for SubscriptionService. |
| `<ConfigHubShell sections={...}>` | The hub's section list is **consumer-supplied** — pass an array of `ConfigHubSection` objects with components + metadata. See [`extension-points.md`](extension-points.md). |
| Feature flag = data row | Adding a new flag = insert a `tier_feature` row. NO library release needed. See [`entitlements.md`](entitlements.md). |
| Tier limit = data row | Adding a new numeric limit = insert a `tier_limit` row. NO library release needed. |

## Consuming this library

```csharp
// File: api/Program.cs
using Chthonic.Tenant;

builder.Services.AddChthonicTenant(builder.Configuration);

// Optional: register a signup-completion handler for product-specific seed.
builder.Services.AddScoped<ITenantSignupCompletedHandler, MyProductSignupHandler>();

var app = builder.Build();
app.MapTenantEndpoints();
app.MapAppVersionEndpoints();
app.MapSmartLinkEndpoints();
```

```tsx
// File: web/src/App.tsx
import { SystemContext, UpgradeContext, TerminologyContext } from '@chthonicsystems/tenant';

<AuthProvider>
  <SystemContext.Provider value={system}>
    <UpgradeContext.Provider value={...}>
      <TerminologyContext.Provider value={terminology}>
        {/* rest of app */}
      </TerminologyContext.Provider>
    </UpgradeContext.Provider>
  </SystemContext.Provider>
</AuthProvider>
```

```tsx
// File: web/src/pages/ConfigHubPage.tsx
import { ConfigHubShell } from '@chthonicsystems/tenant';
import { sections } from './configHubSections';   // consumer-supplied

<ConfigHubShell sections={sections} />
```

Full walkthrough in [`consumption.md`](consumption.md).

## v0.7.0 — `System.DefaultQcViewId` (PR 18 / RFC 0022 § 12)

Adds the tenant-level QC view pointer for the QC sign-off redesign.

| Schema delta | Notes |
|---|---|
| `System.DefaultQcViewId` (`int?`, snake-case `default_qc_view_id`) | Mirrors existing `DefaultViewId` / `QuickViewId` / `JobCardViewId` pattern: nullable int FK column, no typed nav (consumers navigate by ID via their own DbContext). The actual FK constraint with `ON DELETE RESTRICT` is added consumer-side (TorqueTech's PR 18 migration). |

The placeholder migration `ChthonicTenant_0004_DefaultQcView` is empty Up/Down per the migration-coexistence pattern (see [`@chthonic/views` v0.6.0](../views/index.md#v060--qc-view-kind-pr-01-rfc-0022)).

The pointer is set at signup unconditionally for ALL tiers (`DefaultQcViewId = DefaultViewId` initially). The `JobsQc` feature flag continues to gate visibility independently — Free tenants get the pointer but no flag, so QC affordances stay hidden until sysadmin opt-in via `FeatureOverride`.

See [RFC 0022 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md#12-amendment-1--f1b-qc-view-defaults--opt-out-2026-05-24) for the design rationale.

## Related

- [`architecture.md`](architecture.md) — entities, ports, services.
- [`consumption.md`](consumption.md) — full integration.
- [`extension-points.md`](extension-points.md) — sections, signup handler, entitlements adders.
- [`entitlements.md`](entitlements.md) — feature flags + tier limits + per-tenant overrides + quotas.
- [`seeds.md`](seeds.md) — v0.8.0+ seeding policy (RFC 0039: app-policy, not lib-policy).
- [`config-hub.md`](config-hub.md) — 13 sections + ConfigHubShell.
- [`appversion.md`](appversion.md) — mobile force-update.
- [`smartlink.md`](smartlink.md) — universal link redirects.
- Library repo: [chthonicsystems/tenant](https://github.com/chthonicsystems/tenant).
- Governing RFC: [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md).
