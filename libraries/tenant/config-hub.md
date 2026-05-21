---
library: tenant
version: 0.5.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [tenant, config-hub, admin-shell]
summary: Config Hub admin shell — 13 sections in 4 groups + ConfigHubShell consumer-supplied sections.
---

# Config Hub

The single admin-settings surface at `/config-hub`. The library ships a section-agnostic shell + sidebar + status aggregation; **section components are consumer-supplied**.

## 13 canonical sections (4 groups)

| Group | Sections |
|---|---|
| Business Setup | profile, localization, tax, paymentTerms, workingHours, terminology |
| Catalog | services, products |
| Display | fields, serviceScreens, views, documents |
| Integrations | integrations |

`profile`, `localization`, `workingHours` are **mandatory** — drive the Home "Finish setting up" banner via `useHubStatus()`.

## ConfigHubShell

```tsx
import { ConfigHubShell, ConfigHubSection } from '@chthonicsystems/tenant';

const sections: ConfigHubSection[] = [
  {
    id: 'profile',
    label: 'Profile',
    group: 'Business Setup',
    icon: 'business-outline',
    component: ProfileSection,
    isMandatory: true,
  },
  {
    id: 'localization',
    label: 'Localization',
    group: 'Business Setup',
    icon: 'globe-outline',
    component: LocalizationSection,
    isMandatory: true,
  },
  // ... 11 more
  {
    id: 'integrations',
    label: 'Integrations',
    group: 'Integrations',
    icon: 'extension-puzzle-outline',
    component: IntegrationsSection,
    isAi: false,
  },
];

<ConfigHubShell sections={sections} />
```

`ConfigHubShell`:

- Renders the 4-group sidebar (`hub-*` CSS classes).
- Active section's `component` renders to the right.
- URL: `/config-hub` for landing; `/config-hub?s=<id>` for a specific section.
- Mandatory sections show a "Finish setting up" hint in the sidebar.

## Section component shape

Each section is a regular React component. It owns its own data fetching + save flow.

```tsx
function ProfileSection() {
  const { data, save, saving } = useProfileSection();    // your hook
  return (
    <article>
      <h2>Profile</h2>
      <AppField label="Business name">
        <input value={data.name} onChange={...} />
      </AppField>
      <AppSaveButton onClick={save} loading={saving}>Save</AppSaveButton>
    </article>
  );
}
```

Section endpoints (canonical): `GET/PUT /api/systems/my-system/{section}`. Tenant ships these for the seven business-setup sections; the inline-CRUD sections delegate to other libraries.

## Per-section endpoints

### Business Setup (Tenant-owned endpoints)

```
GET/PUT /api/systems/my-system/profile
GET/PUT /api/systems/my-system/localization
GET/PUT /api/systems/my-system/tax-configuration
GET/PUT /api/systems/my-system/payment-terms
GET/PUT /api/systems/my-system/working-hours
GET/PUT /api/systems/my-system/terminology
```

Single transactional PUT per section. Auth: `action:edit-system-settings`.

### Catalog (delegated to `@chthonic/catalog`)

```
GET/POST/PUT/DELETE /api/services/*
GET/POST/PUT/DELETE /api/products/*
```

### Display (delegated to `@chthonic/views`)

```
GET/POST/PUT/DELETE /api/system-views/*
GET/POST/PUT/DELETE /api/custom-fields/*
```

### Documents (delegated to `@chthonic/documents`)

```
/api/{jobcard,invoice,estimate,service-history}-templates/*
```

### Integrations (Tenant-owned)

```
GET    /api/systems/my-system/integrations            # active integrations + flags
PUT    /api/systems/my-system/feature-override        # toggle a flag per-tenant
DELETE /api/systems/my-system/feature-override/{flag}  # clear override
```

## Aggregate status endpoint

```
GET /api/config-hub/status
```

Returns:

```json
{
  "completion": {
    "profile": "complete",
    "localization": "complete",
    "tax": "incomplete",
    "paymentTerms": "complete",
    "workingHours": "incomplete",
    "terminology": "complete",
    ...
  },
  "mandatoryComplete": false,
  "missingMandatory": ["workingHours"],
  "aiActivity": false
}
```

Drives `useHubStatus()` hook which feeds the Home "Finish setting up" banner.

## Mandatory section gating

```tsx
const { mandatoryComplete, missingMandatory } = useHubStatus();

{!mandatoryComplete && (
  <Banner>
    Complete setup: <Link to="/config-hub?s=workingHours">Working hours</Link>
  </Banner>
)}
```

## Adding a section

1. Author the section component (uses `app-*` primitives from `@chthonicsystems/ui`).
2. Author the section's data hook (probably `use<Section>Section` returning `{ data, save, saving }`).
3. Author the backend endpoint (typically `GET/PUT /api/systems/my-system/{section}`).
4. Add to the consumer's `sections` array passed to `ConfigHubShell`.

## Removing / hiding a section

Filter the consumer's `sections` array. The Config Hub renders only what's passed; removing a row from the array hides it. (Don't delete the underlying data — this is a UX-only mask.)

## AI sections

If `isAi: true` is set, the section's sidebar entry shows a `✨` glyph. The library doesn't drive AI itself — the AI infra lives in `@chthonic/ai`, and the section component imports `<AiPill>` etc. from there.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`extension-points.md`](extension-points.md) — section list shape.
- [`entitlements.md`](entitlements.md) — feature-override + tier-limit reads.
- [`libraries/locale/terminology.md`](../locale/terminology.md) — terminology section consumer.
- [`libraries/catalog/`](../catalog/), [`libraries/views/`](../views/), [`libraries/documents/`](../documents/) — inline-CRUD sections.
