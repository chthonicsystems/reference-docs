---
library: tenant
version: 0.5.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [tenant, consumption]
summary: Code-level integration walkthrough for @chthonic/tenant.
---

# Consuming `@chthonic/tenant`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Tenant" Version="0.5.0" />
```

```json
"@chthonicsystems/tenant": "0.5.0"
```

## 2. Register DI + endpoints

```csharp
// File: api/Program.cs
using Chthonic.Tenant;

// Register identity adapters first (see @chthonic/identity).
// Then register tenant.
builder.Services.AddChthonicTenant(builder.Configuration);

// Optional: per-product signup completion handler.
builder.Services.AddScoped<ITenantSignupCompletedHandler, MyProductSignupHandler>();

var app = builder.Build();
app.MapTenantEndpoints();
app.MapAppVersionEndpoints();
app.MapSmartLinkEndpoints();
```

## 3. Register EF configurations

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(TenantModuleMarker).Assembly);
```

## 4. Seed entitlements

```csharp
// File: api/Data/DatabaseSeeder.cs
private async Task SeedEntitlementsAsync()
{
    // 3 tiers
    foreach (var name in new[] { "Free", "Standard", "Premium" })
        if (!await _db.Tiers.AnyAsync(t => t.Name == name))
            _db.Tiers.Add(new Tier { Name = name });
    await _db.SaveChangesAsync();

    // Tier limits — example
    var standard = await _db.Tiers.FirstAsync(t => t.Name == "Standard");
    var premium  = await _db.Tiers.FirstAsync(t => t.Name == "Premium");

    await SeedTierLimit("MaxUsers", standard.TierId, 20);
    await SeedTierLimit("MaxUsers", premium.TierId, -1);   // unlimited
    await SeedTierLimit("MaxJobsPerDay", standard.TierId, 50);
    await SeedTierLimit("MaxJobsPerDay", premium.TierId, -1);
    await SeedTierLimit("MaxAiPromptsPerMonth", standard.TierId, 5);
    await SeedTierLimit("MaxAiPromptsPerMonth", premium.TierId, 20);
    // ...

    // Tier features — example
    await SeedTierFeature("AiConfigImport", standard.TierId, true);
    await SeedTierFeature("AiConfigImport", premium.TierId, true);
    await SeedTierFeature("ListingTemplateAI", premium.TierId, true);
    // ...
}
```

## 5. Use `IFeatureGateService` + `ILimitService`

```csharp
// Anywhere in service code:
public class JobCreationService(IFeatureGateService features, ILimitService limits, IJobsRepo repo)
{
    public async Task<Job> CreateAsync(int systemId, JobInput input)
    {
        if (!await limits.CheckQuotaAsync("MaxJobsPerDay", systemId))
            throw new QuotaExceededException();
        var job = await repo.AddAsync(input);
        await limits.RecordUsageAsync("MaxJobsPerDay", systemId);
        return job;
    }
}
```

## 6. Frontend wiring

```tsx
// File: web/src/App.tsx
import { SystemContext, UpgradeContext, TerminologyContext } from '@chthonicsystems/tenant';
import { LocaleProvider } from '@chthonicsystems/locale';

function App() {
  const { user } = useAuth();
  return (
    <SystemContext.Provider value={user?.system}>
      <UpgradeContext.Provider value={{ tier: user?.system?.tier ?? 'Free' }}>
        <TerminologyContext.Provider value={user?.system?.terminology ?? defaultTerminology}>
          <LocaleProvider options={...}>
            {/* rest of app */}
          </LocaleProvider>
        </TerminologyContext.Provider>
      </UpgradeContext.Provider>
    </SystemContext.Provider>
  );
}
```

## 7. Render the Config Hub

```tsx
// File: web/src/pages/ConfigHubPage.tsx
import { ConfigHubShell } from '@chthonicsystems/tenant';
import { sections } from './configHubSections';

export function ConfigHubPage() {
  return <ConfigHubShell sections={sections} />;
}

// File: web/src/pages/configHubSections.ts
export const sections: ConfigHubSection[] = [
  { id: 'profile', label: 'Profile', group: 'Business Setup', component: ProfileSection },
  { id: 'localization', label: 'Localization', group: 'Business Setup', component: LocalizationSection },
  // ... 11 more
];
```

The library ships the shell + sidebar + status logic. **Section components are product-supplied** — see [`config-hub.md`](config-hub.md) for shape.

## 8. Use feature-gate hooks

```tsx
import { useFeatureGate, useQuota } from '@chthonicsystems/tenant';

function AiConfigButton() {
  const { enabled, loading } = useFeatureGate('AiConfigImport');
  const quota = useQuota('MaxAiPromptsPerMonth');
  if (loading) return <Spinner />;
  if (!enabled) return <UpgradePrompt />;
  return <button disabled={quota.remaining <= 0}>Generate ({quota.remaining} left)</button>;
}
```

## 9. Verification

- [ ] `GET /api/systems/my-system` returns the tenant's settings.
- [ ] `GET /api/config-hub/status` returns mandatory-section completion flags.
- [ ] `IFeatureGateService.IsEnabledAsync` resolves override → tier_feature → false.
- [ ] `ILimitService.CheckQuotaAsync` blocks at the limit.
- [ ] Config Hub renders 13 sections; clicking each navigates without re-fetching everything.
- [ ] Stripe webhook → tier change → feature_overrides flushed.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`entitlements.md`](entitlements.md), [`config-hub.md`](config-hub.md), [`appversion.md`](appversion.md), [`smartlink.md`](smartlink.md).
