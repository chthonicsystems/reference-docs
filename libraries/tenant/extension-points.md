---
library: tenant
version: 0.5.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [tenant, extension-points]
summary: Tenant extension points — sections, signup handler, entitlement adders.
---

# Extension points

Tenant exposes three extension surfaces:

| Hook | Layer | Use |
|---|---|---|
| `ITenantSignupCompletedHandler` | .NET DI port | Run consumer code after `POST /api/signup` succeeds |
| `<ConfigHubShell sections={...}>` | npm | Consumer-supplied 13-section list |
| Entitlement data rows | DB seed | New flags/limits = data, not library release |

## `ITenantSignupCompletedHandler`

```csharp
public interface ITenantSignupCompletedHandler
{
    Task OnSignupCompletedAsync(TenantSignupContext context);
}

public record TenantSignupContext(int SystemId, int AdminUserId, string Tier);
```

Called inside `TenantSignupOrchestrator.SignupAsync` after the `System` + admin `User` are created. Multiple handlers can be registered (`AddScoped<ITenantSignupCompletedHandler, …>` repeatedly) — invoked in registration order.

**TT registers a handler that:**
- Seeds default services (motorbike-specific service catalog).
- Sends a welcome email.
- Provisions the brand-default Document Designer config.

**MarineDeck registers a handler that:**
- Seeds default services (slip-cleaning, hull inspection, …).
- Provisions vessel-specific document templates.
- Sends a welcome email.

## `<ConfigHubShell sections={...}>`

Section list shape:

```ts
type ConfigHubSection = {
  id: string;                             // unique slug
  label: string;                          // sidebar label
  group: 'Business Setup' | 'Catalog' | 'Display' | 'Integrations';
  icon?: string;                          // ionicon name
  component: React.ComponentType;         // section body
  isMandatory?: boolean;                  // gates Home banner
  isAi?: boolean;                         // shows ✨ pill
};
```

Consumers supply the array. Library renders the sidebar + header + content area. Section components handle their own data fetching + save.

The 13 canonical sections (TT default):

```
Business Setup:  profile, localization, tax, paymentTerms, workingHours, terminology
Catalog:         services, products
Display:         fields, serviceScreens, views, documents
Integrations:    integrations
```

Sister-products may add product-specific sections (e.g. MarineDeck might add a "Berths" section). Just pass them in the array.

## Entitlement data rows (no library release)

### Adding a new feature flag

```sql
-- Default state per tier
INSERT INTO tier_feature (tier_id, feature_name, bool_value)
SELECT tier_id, 'NewAwesomeFlag',
       CASE name WHEN 'Premium' THEN true ELSE false END
FROM tier;
```

Now consumers + the Config Hub Integrations section see "NewAwesomeFlag" automatically. Per-tenant override via `feature_override` row writes from the Integrations section UI.

Tip: Add the seed to your consumer's `DatabaseSeeder.SeedFeatureFlagsAsync()` so dev DBs get it on `./dev-start.sh`.

### Adding a new tier limit

```sql
INSERT INTO tier_limit (tier_id, limit_name, int_value)
SELECT tier_id, 'MaxNewThingsPerDay',
       CASE name
         WHEN 'Free' THEN 5
         WHEN 'Standard' THEN 50
         WHEN 'Premium' THEN -1
       END
FROM tier;
```

Then call `ILimitService.CheckQuotaAsync("MaxNewThingsPerDay", systemId)` at the consumer site.

### Per-tenant override

Admins toggle from the Integrations section, which POSTs to `/api/systems/my-system/feature-override` (Tenant-side endpoint). Writes a `feature_override` row.

## Section endpoint pattern

Each tenant-settings section uses canonical CRUD endpoints owned by tenant:

```
GET  /api/systems/my-system/{section}
PUT  /api/systems/my-system/{section}
```

Sections covered: `profile`, `localization`, `tax`, `payment-terms`, `working-hours`, `terminology`, `configuration`. Inline-CRUD sections (services, products, fields, views, screen-sections) defer to their owning libraries (`@chthonic/catalog`, `@chthonic/views`).

## Seeding via `DatabaseSeeder`

Tenant ships **no built-in seed**. Consumers' `DatabaseSeeder` populates:
- 3 `tier` rows (Free / Standard / Premium).
- N `tier_limit` rows (one per `(tier, limit_name)`).
- M `tier_feature` rows (one per `(tier, feature_name)`).

See `consumption.md` § 4.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`entitlements.md`](entitlements.md), [`config-hub.md`](config-hub.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 3 (generic entitlements).
