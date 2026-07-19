---
library: catalog
version: 0.2.1
related-rfcs: [0021, 0034]
last-verified: 2026-07-20
tags: [service-package, job-templates, repair-package, apply-contract]
summary: ServicePackage deep-ref (v0.2.0 / RFC 0034) — named bundle of ServiceItem XOR ProductVariant rows; IServicePackageService CRUD; endpoints mounted by consumers under their own feature gate via a separate mapper; apply-path stays consumer-side (TT's POST /api/jobs/{id}/apply-package routes through JobFieldService so F9 stock decrement wraps it); provenance stays consumer-side.
---

# ServicePackage

A named, reusable bundle of catalog components — "Major Service", "Brake Job" — a consumer application applies to a work unit in one step. Added to `@chthonic/catalog` in **v0.2.0** per [RFC 0034](../../../architecture/rfcs/0034-job-templates.md) (with [§ 12 Amendment 1](../../../architecture/rfcs/0034-job-templates.md#12-amendment-1--planning-decisions-and-divergences-2026-07-19)). The library owns the **bundle definition + CRUD**; *applying* a package is consumer logic.

## Entities

### `ServicePackage`

| Field | Type | Notes |
|---|---|---|
| `ServicePackageId` | int PK | |
| `SystemId` | int | Tenant scope. |
| `ServiceId` | int? | **Optional** owning Service (RFC 0034 § 12h) — null for standalone packages. |
| `Name` | string | |
| `Description` | string? | |
| `IsActive` | bool | Default true. |
| `DisplayOrder` | int | |
| `CreatedAt` / `UpdatedAt` | DateTime | |
| `Items` | `List<ServicePackageItem>` | Components. |

### `ServicePackageItem`

Exactly one of `ServiceItemId` **XOR** `ProductVariantId` is set.

| Field | Type | Notes |
|---|---|---|
| `ServicePackageItemId` | int PK | |
| `ServicePackageId` | int FK | |
| `ServiceItemId` | int? | Set → labour / priced service line. XOR with `ProductVariantId`. |
| `ProductVariantId` | int? | Set → tangible part. XOR with `ServiceItemId`. |
| `Quantity` | decimal(10,2) | Default 1; fractional allowed (1.5 L oil). |
| `DisplayOrder` | int | |

The XOR invariant is enforced three ways (RFC 0034 § 12j): (1) `IServicePackageService` validates on write, (2) the consumer-side schema adds a DB `CHECK` constraint (the lib migration is an empty placeholder — see coexistence below), (3) apply-time consumers treat a violating row as corruption and skip it with a warning. `ServicePackageItem` carries `[AuditParent(typeof(ServicePackage), ...)]` so item edits roll up to a single `servicepackage.updated` audit entry.

## Pricing — sum-of-components

A package has **no price of its own**. Totals are computed at read/apply time (RFC 0034 § 3):

```
total = Σ item.Quantity × (ServiceItem.Cost ?? 0 | ProductVariant.Price)
```

`IServicePackageService.ComputeTotalAsync` returns it; the detail endpoint DTO includes `totalAmount` + per-item `unitAmount`.

## `IServicePackageService`

```csharp
public sealed record ServicePackageItemInput(int? ServiceItemId, int? ProductVariantId, decimal Quantity);

public interface IServicePackageService
{
    Task<List<ServicePackage>> ListAsync(int systemId, bool activeOnly = false);
    Task<ServicePackage?>       GetWithItemsAsync(int servicePackageId, int systemId);
    Task<List<ServicePackage>>  SearchAsync(string query, int systemId, int limit = 50);
    Task<ServicePackage>        CreateAsync(int systemId, string name, string? description, int? serviceId,
                                            IReadOnlyList<ServicePackageItemInput> items, bool isActive = true);
    Task<bool>                  UpdateAsync(int servicePackageId, int systemId, string name, string? description,
                                            int? serviceId, bool? isActive);
    Task<bool>                  ReplaceItemsAsync(int servicePackageId, int systemId,
                                            IReadOnlyList<ServicePackageItemInput> items);   // whole-list atomic replace
    Task<bool>                  DeleteAsync(int servicePackageId, int systemId);
    Task<bool>                  ReorderAsync(int servicePackageId, int systemId, int displayOrder);
    Task<decimal>               ComputeTotalAsync(int servicePackageId, int systemId);
}
```

Registered by `AddChthonicCatalog()` in v0.2.0. Item writes are **whole-list replaces** (`ReplaceItemsAsync`) — packages are small and this matches how the Config Hub editor saves. XOR violation / non-positive quantity / a component not owned by `systemId` → `ArgumentException` → endpoint 400 `invalid-package-item`.

## Endpoints — separate mapper, consumer-gated

CRUD ships via a **deliberately separate** mapper so consumers can mount package endpoints without mounting the (TT-unmounted) `CatalogEndpoints` (RFC 0034 § 12a):

```csharp
app.MapChthonicServicePackageEndpoints();   // /api/service-packages/*
```

| Method | Route | Notes |
|---|---|---|
| GET | `/api/service-packages?activeOnly=` | List (summary DTO, `itemCount`). |
| GET | `/api/service-packages/search?query=&limit=` | Typeahead (limit ≤ 200). |
| GET | `/api/service-packages/{id}` | Detail DTO with items + `totalAmount`. |
| POST | `/api/service-packages` | Create → 201 `{ servicePackageId }` \| 400 `invalid-package-item`. |
| PUT | `/api/service-packages/{id}` | Update (+ optional item replace). |
| DELETE | `/api/service-packages/{id}` | |
| PUT | `/api/service-packages/{id}/reorder` | |

`SystemId` is resolved from the `system_id` claim server-side. The endpoints are `RequireAuthorization()` but **tier-agnostic** — TorqueTech mounts this mapper under its own `RequireFeature("JobsTemplates")` route group (string key, not enum — RFC 0034 § 12e); sister products may mount both mappers. No dedicated package permissions ship: Config Hub CRUD rides `action:edit-system-settings` (RFC 0034 § 12f).

## Apply contract — stays consumer-side

The library never applies a package to a work unit — that requires touching the consumer's job/line-item model, and cross-library FK-only typing forbids `@chthonic/catalog` depending on `@chthonic/work`. **Consumers route package application through their own field machinery.**

TorqueTech's apply path (RFC 0034 § 12b):

- **One endpoint**: `POST /api/jobs/{id}/apply-package` (`action:edit-job` + `JobsTemplates` gate). The CreateJob flow calls it right after create; the JobDetail "Apply package" button calls the same endpoint — one code path.
- The apply service (1) ensures a `JobService` row exists for every Service implied by the package's ServiceItem components (service items only render as virtual fields when a `JobService` link exists), then (2) writes field values through the **existing `JobFieldService` line-item machinery**, *inside* the `IJobStockDecrementService` snapshot/delta wrap.
- Because it reuses the manual line-item write path, apply **inherits F9 wholesale** (RFC 0034 § 12c): the [stock decrement](../inventory/consumption.md#delta-based-decrement-in-the-job-line-item-save-path), tolerance validation, and auto-comments all fire exactly as a manual edit would — including the negative-stock policy (409 `insufficient-stock` when the tenant blocks negative stock). Zero new stock code.
- **Quantity merge is additive** — applying a package whose variant already exists on the job adds quantities (existing 2 + package 2 → 4).
- **Snapshot semantics** — apply hydrates concrete line items; later ServicePackage edits never mutate existing jobs.

## Apply provenance — stays consumer-side

The "Applied package: Major Service" badge needs durable provenance surviving package renames and N-applies-per-job. TorqueTech keeps an append-only `job_package_application` table (RFC 0034 § 12d) — **not** in `@chthonic/catalog`, because it references `Job` (a `@chthonic/work` concern):

```
job_package_application
├── job_package_application_id  PK
├── job_id                      FK job (CASCADE)
├── service_package_id          FK service_package (SET NULL — rename/delete-safe)
├── package_name_snapshot       VARCHAR(255)   -- badge text at apply time
├── item_count                  INT
├── total_amount                DECIMAL(10,2)
├── applied_by_user_id          FK user
└── applied_at                  DATETIME
```

Liftable to the library later if a sister product adopts apply-provenance.

## Migration coexistence

`@chthonic/catalog` v0.2.0 ships an **empty-placeholder** migration `ChthonicCatalog_0002_ServicePackages` (its XML doc lists the schema). The consumer owns the real schema — TorqueTech's `RegisterChthonicCatalog020_ServicePackages`: `INSERT IGNORE` placeholder registration + idempotent `CREATE TABLE service_package` / `service_package_item` (with the XOR `CHECK`) + `job_package_application`. A separate `AddJobsTemplatesFeatureKey` seeds the `tier_feature` rows (the PR 09 two-migration shape). No seeded example packages (RFC 0034 § 12g) — the migration stays purely structural.

> **v0.2.1 note:** a patch after v0.2.0 fixed nullable query-param binding on `GET /api/service-packages` (non-nullable optional binding returned 400).

## npm surface

`@chthonicsystems/catalog` v0.2.1 exports the `ServicePackage` / `ServicePackageItem` types, a `servicePackageService` factory, and `<ServicePackagePicker>`. `CATALOG_PACKAGE_VERSION === '0.2.1'`.

## Cross-references

- [`index.md`](index.md) — catalog public surface.
- [`service-and-product.md`](service-and-product.md) — the ServiceItem / ProductVariant components a package bundles.
- [`@chthonic/inventory` consumption — F9 decrement the apply path inherits](../inventory/consumption.md#delta-based-decrement-in-the-job-line-item-save-path).
- [RFC 0034](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0034-job-templates.md).
