---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, cross-library, fk-only-typing]
summary: Cross-library FK-only typing — Job/Booking/etc. reference Asset by FK + cast at call site.
---

# Cross-library FK-only typing

Other libraries (`@chthonic/work`, `@chthonic/booking`, `@chthonic/billing`) reference `Asset` by FK + the polymorphic base navigation property only. They MUST NOT add subtype-specific nav properties.

## Pattern

```csharp
// In @chthonic/work:
public class Job
{
    public int JobId { get; set; }
    public int AssetId { get; set; }
    public Chthonic.Assets.Domain.Asset Asset { get; set; } = null!;   // ← polymorphic base
    // ...
}
```

`Job.Asset` is typed as `Asset`, not `Vehicle`. Each consumer product downcasts at the call site:

```csharp
// TT (api/Features/Jobs/JobEndpoints.cs):
var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(j => j.JobId == jobId);
var vehicle = (Vehicle)job.Asset;   // downcast — TT knows it's a Vehicle
return new { jobId, vehicleMake = vehicle.Make, vehicleModel = vehicle.Model };
```

```csharp
// MarineDeck:
var vessel = (Vessel)job.Asset;
return new { jobId, vesselLength = vessel.LengthM, vesselHullType = vessel.HullType };
```

## Why no nav-prop chain

If `@chthonic/work` had `public Vehicle Vehicle` nav, the work library would compile-time depend on TT (or MarineDeck, or PetCare). That makes the work library product-specific — unacceptable.

Restricting to `Asset` keeps work library product-agnostic. All product-specific knowledge lives in the consumer.

## Cross-library nav prop drops

PR 13 (Work extraction) and PR 14 (Booking extraction) explicitly DROP cross-library nav props:

```csharp
// Pre-extraction
public class Job { public Vehicle Vehicle { get; set; } }   // ← removed
public class Booking { public Vehicle Vehicle { get; set; } public Estimate Estimate { get; set; } }  // ← all dropped

// Post-extraction
public class Job { public Asset Asset { get; set; } }
public class Booking { public Asset Asset { get; set; } /* no Estimate, no Job */ }
```

Cross-library queries that previously joined via nav properties now do explicit FK lookups:

```csharp
// Old: var bookingJob = booking.Job;
// New:
var bookingJob = await _db.Jobs.FirstAsync(j => j.JobId == booking.JobId);
```

PR 14c added a `PopulateJobEstimateInvoiceInfo` helper that does these lookups in batch for `BookingResponse` projections.

## Impact on cast sites

PR 13 alone rewrote ~75 `j.Asset.<X>` sites in TT to `((Vehicle)j.Asset).<X>`. The mechanical pattern:

```bash
# grep for sites using subtype-specific properties
grep -rn 'j\.Asset\.' api/

# rewrite each to cast:
((Vehicle)j.Asset).Make
((Vehicle)j.Asset).Model
((Vehicle)j.Asset).Vin
```

Tests verify each cast doesn't throw at runtime (they don't — TT's data is always Vehicle).

## Related

- [`tph-polymorphism.md`](tph-polymorphism.md), [`subtype-registry.md`](subtype-registry.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 6 (cross-library FK-only typing).
- [RFC 0008](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0008-asset-entity-generalization.md).
