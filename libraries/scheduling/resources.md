---
library: scheduling
version: 0.1.0
last-verified: 2026-06-06
tags: [resource, taxonomy, config-hub]
summary: Resource entity deep-ref — vertical-agnostic schedulable resource with string ResourceType discriminator. Seeded Bay|Lift|Ramp; tenants self-extend via Config Hub.
---

# Resource

Vertical-agnostic schedulable asset that work happens at. Examples: TT bay/lift/ramp, MarineDeck slip/mooring, FlowLift forklift bay, PetCare exam room.

## Schema

| Column | Type | Notes |
|---|---|---|
| `resource_id` | INT PK | AUTO_INCREMENT |
| `system_id` | INT | Tenant FK (FK-only typing — references `Chthonic.Tenant.Domain.System.SystemId` at runtime). |
| `name` | VARCHAR(100) | Display name. Unique per system via `(system_id, name)` index. |
| `resource_type` | VARCHAR(40) | String discriminator (NOT enum). Seeded set: `Bay | Lift | Ramp`. Tenants self-extend; sister-products extend via `IResourceTypeProvider`. |
| `is_active` | TINYINT(1) | Soft-delete flag. Inactive resources hidden from dispatch-board UI but historical slots stay queryable. |
| `display_order` | INT | Sort order in dispatch-board lane rendering. Zero-default. |
| `created_at` / `updated_at` | DATETIME(6) | Standard audit timestamps. |

## Why a string discriminator, not an enum

Per [RFC 0029 § 12 Amendment 1 12b](../../../architecture/rfcs/0029-dispatch-board.md#12b-resourcetype-taxonomy-seed--minimal-bay--lift--ramp-closes--9-question-1):

- Sister-products can extend additively (`"Slip"`, `"Mooring"`, `"ExamRoom"`) without a lib bump.
- Tenants can extend via Config Hub UI (e.g. workshop adds `"Wash Bay"`, `"Diagnostic Bay"`).
- The `IResourceTypeProvider` extension hook gives validation a programmatic seam.

The seeded set in `Domain.ResourceType` is intentionally minimal (3 values) — workshop-flavoured subtypes (`WashBay`, `DiagnosticBay`, `TyreBay`) are TT-side seed data, not lib taxonomy. TorqueTech's `DatabaseSeeder` adds `Bay 1`, `Bay 2`, `Lift 1` rows to each newly created tenant; these are tenant-owned data, not type taxonomy.

## Lifecycle

- **Created**: via `POST /api/scheduling/resources` (Config Hub Resources Section UI). Validated against the `IResourceTypeProvider` allowed set.
- **Edited**: `PUT /api/scheduling/resources/{id}` — name, type, is_active, display_order all editable.
- **Deleted**: `DELETE /api/scheduling/resources/{id}` is a **soft-delete** — sets `is_active = false`. Historical `schedule_slot` rows referencing the resource stay intact (they're queryable for the F17 bay-utilization report). The `fk_schedule_slot_resource` foreign key is `ON DELETE RESTRICT` so true hard-delete fails if any slots exist; admin must release/cancel slots first.

## Permissions (TT)

- `page:dispatch-board` — read access to the Resources Section UI.
- `action:edit-resources` — create/edit/delete Resources.

Per RFC 0029 § 12 Amendment 1 12i, both gated under the `JobsDispatchBoard` Premium-tier feature key.

## Cross-references

- [Architecture](architecture.md)
- [ScheduleSlot deep-ref](schedule-slots.md)
- [Extension points — IResourceTypeProvider](extension-points.md#iresourcetypeprovider--taxonomy)
