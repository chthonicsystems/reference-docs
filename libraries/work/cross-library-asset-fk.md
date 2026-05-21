---
library: work
version: 0.1.0
related-rfcs: [0001, 0008]
last-verified: 2026-05-22
tags: [work, cross-library, fk-only-typing]
summary: Job.Asset typed as polymorphic Asset base — consumer downcasts at the call site.
---

# Cross-library Asset FK

`Job.Asset` is typed as `Chthonic.Assets.Domain.Asset` (the polymorphic base). The work library doesn't know about `Vehicle` / `Vessel` / `Forklift` / `Pet`. Each consumer product downcasts.

## Pattern

```csharp
// In @chthonic/work:
public class Job
{
    public int AssetId { get; set; }
    public Asset Asset { get; set; } = null!;   // ← polymorphic base
}
```

```csharp
// TT call site:
var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(j => j.JobId == jobId);
var vehicle = (Vehicle)job.Asset;            // safe — TT only has Vehicles
return new { vehicle.Make, vehicle.Model, vehicle.Vin };
```

## Why no Vehicle nav

If `Job.Vehicle` existed in the work library, work would compile-time depend on TT's `Vehicle` class (or MarineDeck's, or PetCare's). That would make `@chthonic/work` product-specific.

By typing as `Asset`, work stays product-agnostic. All product-specific knowledge lives in the consumer's call sites.

## Cast volume

PR 13 of the extraction sequence rewrote ~75 sites in TT from `j.Vehicle.<X>` to `((Vehicle)j.Asset).<X>`. Mechanical:

```bash
grep -rn 'j\.Vehicle\.' api/   # find sites
# rewrite each to ((Vehicle)j.Asset).<X>
```

Test invariant: every call site compiles + runs without `InvalidCastException` (because TT only stores Vehicles).

## Sister-product symmetry

```csharp
// MarineDeck call site:
var vessel = (Vessel)job.Asset;

// PetCare call site:
var pet = (Pet)job.Asset;
```

Each product downcasts to its own subtype.

## Other dropped navs

PR 13/14 also dropped:

- `Job.Estimate`, `Job.Booking`, `Job.Invoice` (FK-only)
- `Booking.Estimate`, `Booking.Job` (FK-only)

These are FK columns on Job/Booking but no nav properties. Consumers do explicit FK lookups when needed (see [`libraries/booking/availability-service.md`](../booking/availability-service.md) for the BookingResponse re-hydration pattern).

## Related

- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 6.
- [`libraries/assets/cross-library-fk-only.md`](../assets/cross-library-fk-only.md).
