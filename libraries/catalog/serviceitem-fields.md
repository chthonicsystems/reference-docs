---
library: catalog
version: 0.1.0
related-rfcs: [0021]
last-verified: 2026-05-22
tags: [catalog, service-item]
summary: ServiceItem — line items under a Service. Cost lives here, not on Service.
---

# ServiceItem

A `ServiceItem` is a single line item under a `Service`. Itemized pricing — services have no cost; the cost of a service is the sum of its items.

## Schema

```sql
CREATE TABLE service_item (
    service_item_id INT PRIMARY KEY AUTO_INCREMENT,
    service_id INT NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    cost DECIMAL(10,2) NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    INDEX ix_service_item_service (service_id)
);
```

## Example data

`Service` "Major Service" has items:

| Service item | Cost |
|---|---|
| Engine oil change | 45.00 |
| Oil filter replacement | 25.00 |
| Brake check | 30.00 |
| Tyre pressure check | 10.00 |
| **Total** | **110.00** |

Service "Major Service" total cost = sum of items = $110.00. Calculated server-side; not stored on Service row.

## Endpoints

```
GET    /api/services/{serviceId}/items
POST   /api/services/{serviceId}/items
PUT    /api/services/{serviceId}/items/{id}
DELETE /api/services/{serviceId}/items/{id}
```

## Custom field linkage

`@chthonic/views` allows custom fields to "link" to a `ServiceItem.Cost` via `entity_field.linked_field_name = 'service_item.cost'`. When a job has that linked field set, the job's calculated total reads from the linked service item. See [`libraries/views/custom-fields.md`](../views/custom-fields.md) for the linkage pattern.

NB per PR 11.5: `ServiceItem.JobFields` inverse navigation was dropped (cycle break). Job→ServiceItem references are FK-only.

## Display order

Same convention as Service.DisplayOrder. Drag-and-drop UIs reorder by rewriting all values in a single transactional PUT.

## Related

- [`service-and-product.md`](service-and-product.md).
- [`libraries/views/custom-fields.md`](../views/custom-fields.md) — field linkage.
