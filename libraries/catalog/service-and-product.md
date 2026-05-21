---
library: catalog
version: 0.1.0
related-rfcs: [0021]
last-verified: 2026-05-22
tags: [catalog, service, product]
summary: Service and Product entities — top-level catalog units.
---

# Service and Product

Two top-level catalog entities. Vertical-agnostic — same shape across products.

## Service

A service the tenant offers — e.g. "Major Service", "Hull Inspection", "Vaccination Visit".

```csharp
public class Service
{
    public int ServiceId { get; set; }
    public int SystemId { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public List<ServiceItem> Items { get; set; } = [];
}
```

**Service has no cost.** Total cost = `SUM(items.Cost)`. This forces itemized pricing — one of TT's earliest design constraints.

## Product

A product the tenant sells — e.g. "Engine Oil", "Hull Polish", "Pet Food".

```csharp
public class Product
{
    public int ProductId { get; set; }
    public int SystemId { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public List<ProductVariant> Variants { get; set; } = [];
}
```

A product has 1+ variants. A "single-flavour" product still has one variant (with the price); the product itself doesn't carry a price.

## Search

```
GET /api/services/search?q=...     # name LIKE
GET /api/products/search?q=...     # name + sku + barcode LIKE
```

## Display order

`DisplayOrder` is a free-form integer (typically 0, 100, 200, ...) for sortable lists. Drag-and-drop UIs rewrite all values on reorder.

## Cross-references

| Related entity | How |
|---|---|
| Job (work spine) | `Job.ServiceId` FK |
| Estimate / Invoice line items (billing) | `EstimateItem.ProductVariantId` FK |
| Booking (booking) | `Booking.ServiceId` FK |
| Custom fields (views) | `entity_field.linked_field_name = 'ServiceId'` |

## Related

- [`serviceitem-fields.md`](serviceitem-fields.md), [`productvariant-pricing.md`](productvariant-pricing.md).
- [`libraries/booking/`](../booking/), [`libraries/billing/`](../billing/), [`libraries/work/`](../work/).
