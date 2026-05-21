---
library: catalog
version: 0.1.0
related-rfcs: [0021]
last-verified: 2026-05-22
tags: [catalog, product-variant, pricing, sku]
summary: ProductVariant — line items under a Product with SKU + barcode + price.
---

# ProductVariant

A `ProductVariant` is a sellable instance of a `Product`. A "single-flavour" product still has one variant carrying the price.

## Schema

```sql
CREATE TABLE product_variant (
    product_variant_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    sku VARCHAR(100) NULL,
    barcode VARCHAR(100) NULL,
    price DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    INDEX ix_variant_product (product_id),
    INDEX ix_variant_sku (sku),
    INDEX ix_variant_barcode (barcode)
);
```

## Example data

`Product` "Engine Oil 4L" has variants:

| Variant | SKU | Barcode | Price |
|---|---|---|---|
| Castrol Edge 5W-30 | EO-CST-5W30 | 1234567890123 | 89.95 |
| Mobil 1 0W-40 | EO-MOB-0W40 | 1234567890124 | 99.95 |
| Penrite 10W-50 | EO-PEN-10W50 | 1234567890125 | 79.95 |

Each variant priced independently.

## Endpoints

```
GET    /api/products/{productId}/variants
POST   /api/products/{productId}/variants
PUT    /api/products/{productId}/variants/{id}
DELETE /api/products/{productId}/variants/{id}
GET    /api/products/{productId}/variants/search?q=...   # name + sku + barcode
```

## SKU + barcode

Both nullable (some products are uncoded). Both indexed for fast typeahead lookup. Uniqueness NOT enforced at the schema level — a tenant might have legitimate duplicates (e.g. drop-ship products without SKUs, or two product brands sharing a UPC).

## Used by

- **Estimate / Invoice line items** (billing) — `EstimateItem.ProductVariantId` FK.
- **Job parts installed** (work) — historical tracking; FK to ProductVariant.
- **Stock / inventory** — out of scope for v0.x catalog; future RFC.

## Inactive variants

`is_active = false` keeps the row visible to old estimates/invoices but excludes it from typeahead pickers. Deletion is rare — once a variant has been on an invoice, it shouldn't disappear.

## Inverse navigation drop (PR 11.5)

`Product.JobFields` and `ProductVariant.JobFields` inverse navigations were dropped to break a cross-library cycle. `JobField → Product` / `JobField → ProductVariant` references are FK-only.

## Related

- [`service-and-product.md`](service-and-product.md).
- [`libraries/billing/`](../billing/) — invoice line item consumer.
- [`libraries/work/`](../work/) — JobPartsInstalled consumer.
