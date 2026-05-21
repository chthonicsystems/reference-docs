---
library: _platform_
version: 2026-05-22
related-rfcs: [0001, 0007, 0008, 0011]
last-verified: 2026-05-22
tags: [platform, patterns, polymorphic-fk, two-package, entitlements, option-c, migration-coexistence, fk-only]
summary: The 6 reusable patterns across all 25 libraries — polymorphic FK, two-package shape, entitlements, Option C UI shells, migration coexistence, cross-library FK-only typing.
---

# Extension patterns

Six patterns recur across the 25 libraries. Knowing them prevents re-deriving on every consumer integration and prevents accidental anti-patterns. Each pattern includes the libraries that implement it + a code sample.

## 1. Polymorphic FK pattern `(entity_type, entity_id)`

**Implemented by:** `notes`, `files`, `views`, parts of `audit`.

One row in a child table can attach to any entity in any library. The library doesn't know what entity types exist; consumers pass `entity_type` as a string at insert time.

**Schema:**

```sql
CREATE TABLE note (
    note_id INT PRIMARY KEY AUTO_INCREMENT,
    system_id INT NOT NULL,
    entity_type VARCHAR(50) NOT NULL,   -- 'Job', 'Customer', 'Invoice', 'Vessel', etc.
    entity_id INT NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME NOT NULL,
    -- ...
    INDEX idx_note_entity (entity_type, entity_id)
);
```

**Consumer call site (TT):**

```csharp
// File: api/Features/Jobs/JobEndpoints.cs
await _notesService.CreateAsync(new CreateNoteRequest
{
    SystemId = systemId,
    EntityType = "Job",       // ← consumer-supplied string
    EntityId  = jobId,
    Body      = note.Body,
});
```

**MarineDeck integration:**

```csharp
// File: api/Features/Vessels/VesselEndpoints.cs
await _notesService.CreateAsync(new CreateNoteRequest
{
    SystemId = systemId,
    EntityType = "Vessel",   // ← MarineDeck-specific string; lib never sees this
    EntityId  = vesselId,
    Body      = note.Body,
});
```

The `entity_type` strings are convention. Each consumer documents its strings; libraries don't enforce them.

**Trade-off:** No referential integrity. If `Job 42` is deleted, dangling notes remain unless the consumer issues an explicit cleanup. Libraries that use polymorphic FK provide a `DeleteByEntityAsync(entityType, entityId)` helper.

## 2. Two-package shape for pluggable providers

**Implemented by:** `payments` (Stripe / Tap / Square / Razorpay / Adyen), `support` (GitHub / Linear / Jira / Zendesk), `billing` (Xero / QuickBooks / MYOB / Zoho Books).

Interface library and per-provider implementation packages ship as separate NuGet packages. Products consume only the providers they need; SDK dependencies stay out of products that don't need them.

**Package layout:**

```
Chthonic.Payments              # interface only; defines IPaymentProvider, IPaymentEventDispatcher, Money
Chthonic.Payments.Stripe       # depends on Chthonic.Payments + Stripe.net
Chthonic.Payments.Tap          # (Phase-2) Chthonic.Payments + tap-sdk
Chthonic.Payments.Square       # (Phase-2)
Chthonic.Payments.Razorpay     # (Phase-2)
```

**Product registration:**

```csharp
// File: api/Program.cs
builder.Services.AddChthonicPayments(builder.Configuration);     // interface package
builder.Services.AddStripePaymentProvider(builder.Configuration); // impl package
```

**Why two packages, not one:** the interface package has zero SDK dependencies, so a product that only needs Tap doesn't pull in Stripe.net (~5MB of transitive deps).

## 3. Generic entitlements in tenant (data-driven, not hardcoded)

**Implemented by:** `tenant`.

Feature flags + tier limits + per-tenant overrides + quota tracking are tenant-scoped, data-driven. No code changes needed to add a new flag or limit — insert a `tier_feature` or `tier_limit` row and consumers read it.

**Schema:**

```
tier              -- Free / Standard / Premium
tier_limit        -- per-tier numeric quotas (MaxUsers, MaxJobsPerDay, MaxAiPromptsPerMonth, ...)
tier_feature      -- which features are default-enabled per tier
feature_override  -- per-tenant override row (bool_value for flag, int_value for limit)
quota_usage       -- running counters for daily/monthly limits
```

**API:**

```csharp
// File: tenant/src/Chthonic.Tenant/Entitlements/IFeatureGateService.cs
bool isEnabled = await _featureGate.IsEnabledAsync("AiConfigImport", systemId);

// File: tenant/src/Chthonic.Tenant/Entitlements/ILimitService.cs
int max = await _limits.GetLimitAsync("MaxJobsPerDay", systemId);   // -1 = unlimited
bool ok  = await _limits.CheckQuotaAsync("MaxAiPromptsPerMonth", systemId);   // BEFORE
await _limits.RecordUsageAsync("MaxAiPromptsPerMonth", systemId);              // AFTER
```

**Resolution order:** `feature_override` (per-tenant) → `tier_feature` / `tier_limit` (tier default) → fallback (`false` for flags, `int.MaxValue` for limits).

**Adding a new flag** = insert a `tier_feature` row in a seed migration. No library release needed.

## 4. Option C — UI shells live in feature libraries

**Implemented by:** `tenant` (ConfigHubShell), `documents` (DocumentDesignerShell), `ai` (AiPill, AiSectionBanner, AiChat, AiVersionCarousel, AiArtifactEditor, AiAssistantPanel), `listings` (ListingDesignerShell, PublicListingPage), `notes` (NotesPanel), `files` (FileGallery, FileUploadButton), `views` (ScreenSectionsRenderer + dynamic field components), `notifications` (CommunicationsPanel).

`@chthonic/ui` is **foundational only** — MD3 tokens, `app-*` primitives, customer portal layout, brand tokens. Feature-specific shells go INTO their respective feature library, alongside the data hooks that feed them.

**Why:** co-locating data + UI keeps each feature self-contained. A consumer that imports `@chthonicsystems/notes` gets the entity, the service, the React hook, AND the panel — not three separate npm packages.

**Library structure:**

```
@chthonicsystems/notes/
├── npm/src/
│   ├── useNotes.ts              # data hook
│   ├── adapters.ts              # peer-injection (HTTP, auth, photo capture)
│   └── components/
│       ├── NotesPanel.tsx       # the shell (rendered by consumer pages)
│       ├── ChatBubble.tsx
│       └── NoteThread.tsx
└── src/Chthonic.Notes/          # .NET side
```

**Consumer call site (TT):**

```tsx
// File: web/src/pages/JobDetail.tsx
import { NotesPanel } from '@chthonicsystems/notes';

<NotesPanel entityType="Job" entityId={job.id} systemId={systemId} />
```

**Foundational primitives still come from `@chthonicsystems/ui`:**

```tsx
import { MD3AppBar, AppField, AppToast } from '@chthonicsystems/ui';
import { NotesPanel } from '@chthonicsystems/notes';   // composes ui primitives internally
```

## 5. Migration coexistence — bare descriptive table names + assembly scan

**Implemented by:** every library with EF entities (most of them).

**No `chthonic_<library>_*` prefix on tables.** Each library uses bare descriptive names: `users`, `system`, `customer`, `note`, `file`, `audit_log`, etc. Collisions are resolved at architecture review (rare in practice — each library owns a distinct domain).

EF migrations from each library register via assembly scan in the consumer's `DbContext.OnModelCreating`:

```csharp
// File: api/Data/TorqueTechDbContext.cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    base.OnModelCreating(modelBuilder);

    modelBuilder.ApplyConfigurationsFromAssembly(typeof(LocaleModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(IdentityModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(TenantModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(PartiesModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(PaymentsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AuditModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(FilesModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AssetsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(CatalogModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(TemplatingModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(NotificationsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(ViewsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(NotesModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(WorkModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(BookingModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(BillingModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AIModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(DocumentsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(ListingsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(FeedbackModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(SupportModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(DataModuleMarker).Assembly);
}
```

Each library's `0001_Initial` migration is **idempotent against the existing schema** — when extracting an entity TT already owns, the migration registers EF metadata only and inserts a `__EFMigrationsHistory` row at deploy time:

```sql
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
VALUES ('20260101000000_ChthonicX_0001_Initial', '9.0.0');
```

Genuine semantic renames (e.g. `system_job_field` → `system_entity_field` in views, `vehicles` → `assets` in PR 08) get explicit `ALTER TABLE … RENAME TO …` statements in the library migration.

## 6. Cross-library FK-only typing

**Implemented by:** `work` (Job.Asset → Chthonic.Assets.Domain.Asset), `booking` (Booking.Asset → Asset), `billing` (Estimate / Invoice → Job by FK).

Where library A has an entity that references library B's entity, the FK lives on library A's entity but **the navigation property is dropped** (or typed as the polymorphic base). This avoids cross-library nav-prop chains that would force every consumer to load every dependency's schema.

**Example — Job references Asset:**

```csharp
// File: work/src/Chthonic.Work/Domain/Job.cs
public class Job
{
    public int JobId { get; set; }
    public int AssetId { get; set; }                                 // FK
    public Chthonic.Assets.Domain.Asset Asset { get; set; } = null!;  // polymorphic-base nav
    // ...
}
```

**TT-side cast at usage:**

```csharp
// File: api/Features/Jobs/JobEndpoints.cs
var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(...);
var vehicle = (Vehicle)job.Asset;  // ← TT-side downcast to its subtype
```

MarineDeck performs the equivalent cast to `(Vessel)b.Asset`. The work library never references `Vehicle` / `Vessel` / `Forklift` / `Pet`.

**Why:** keeps the work library's schema migrations free of consumer-specific entity types. The base `Asset` (TPH) is the only cross-library type in flight.

## Related

- [`platform/library-consumption.md`](library-consumption.md) — NuGet/npm import.
- [`platform/version-policy.md`](version-policy.md) — SemVer + breaking-change.
- [`libraries/files/polymorphic-fk.md`](../libraries/files/polymorphic-fk.md) — pattern 1 deep-ref.
- [`libraries/payments/provider-abstraction.md`](../libraries/payments/provider-abstraction.md) — pattern 2 deep-ref.
- [`libraries/tenant/entitlements.md`](../libraries/tenant/entitlements.md) — pattern 3 deep-ref.
- [`libraries/assets/cross-library-fk-only.md`](../libraries/assets/cross-library-fk-only.md) — pattern 6 deep-ref.
- [RFC 0001 — Platform Extraction](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md) § 6 (Architectural Patterns).
