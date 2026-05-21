---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, custom-fields]
summary: Custom field definitions — types, visibility rules, dropdown options, linked fields.
---

# Custom fields

`SystemEntityField` defines a field's:

- **Identity**: name, data type, required-or-not.
- **Hierarchy**: category + sub-category for grouping in screens.
- **Visibility**: which roles + which entity statuses see it.
- **Behaviour**: free-text vs option-list vs multi-select.
- **Linkage**: optional `linked_field_name` to another entity's column.

## Data types

| Type | Renderer | Storage |
|---|---|---|
| `Text` | `<TextField>` | `entity_field_value.value` (string) |
| `Numeric` | `<NumericField>` | string-stored decimal |
| `Date` | `<DateField>` | ISO-8601 string |
| `Checkbox` | `<CheckboxField>` | `'true'` / `'false'` string |
| `Options` | `<OptionsField>` | option ID string |
| `Combo` | `<ComboField>` | option ID OR free-text fallback |
| `MultiValueOptions` | `<MultiValueOptionsField>` | comma-separated option IDs |

## Visibility — roles

`system_entity_field_role(entity_field_id, role_id)` rows. A field with NO rows is visible to ALL roles. A field with at least one row is visible only to the listed roles.

## Visibility — statuses

`system_entity_field_status(entity_field_id, status)` rows. A field with no rows shows on all statuses. With rows, visibility is gated.

## Linked fields

`linked_field_name = 'service_item.cost'` means: when this field's value changes, write the new value to the linked target column. Used for tying job pricing to a service item's cost. PR 11.5 dropped inverse navigations on the catalog side; the linkage is FK-only.

## Endpoints

```
GET    /api/custom-fields/{viewId}              # all fields for view
POST   /api/custom-fields                       # create field
PUT    /api/custom-fields/{id}                  # update field
DELETE /api/custom-fields/{id}
PUT    /api/custom-fields/{id}/options          # bulk update field options
PUT    /api/custom-fields/{id}/roles            # bulk update visible roles
PUT    /api/custom-fields/{id}/statuses         # bulk update visible statuses
```

## Related

- [`screen-sections-renderer.md`](screen-sections-renderer.md), [`extension-points.md`](extension-points.md).
