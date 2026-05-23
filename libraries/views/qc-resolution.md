---
summary: 4-stop server-side QC view resolution chain + 3-step eligibility tree + ScreenSectionsRenderer kind-aware dispatch.
---

# QC view resolution & rendering

> Added in `@chthonicsystems/views` v0.8.0 + `@chthonic/views` 0.8.0 (PR 18, RFC 0022 § 12 Amendment 1). Replaces the F1-shipped client-side QC view picker.

## Why this exists

F1 (PR 01) shipped a separate `Default QC Checklist` SystemView per tenant, with the QC card client-side filtering views by `Kind === 'qc'`. Production exposed three issues:

1. **No tenant-level QC pointer** — admins couldn't say "this is THE default QC view"; with multiple QC views, the client fell back to array-order.
2. **Two latent client bugs** — `GET /api/system-views` projection didn't expose `Kind`, and the client treated the `{ views, roleViews }` response as an array. Masked by the `JobsQc` feature gate firing first.
3. **Client-side picking is the wrong shape** — server has no notion of "the right QC view for this user/job", which prevents per-role QC overrides cleanly.

F1b repoints the model so view selection is server-resolved + the per-field opt-out is structural.

## The four design decisions (locked in RFC 0022 § 12)

1. **`System.DefaultQcViewId`** — set unconditionally at signup to `DefaultViewId` for ALL tiers. The `JobsQc` feature flag continues to gate visibility independently. Free tenants get the pointer but no flag, so QC affordances stay hidden until sysadmin opt-in.
2. **`SystemRoleView.QcViewId`** — per-role override, mirrors the existing `DefaultViewId` / `QuickViewId` / `JobCardViewId` triplet.
3. **`EntityField.ExcludeFromQc`** — per-field opt-out. No save-time validation (UI hides the toggle on child rows; dead data on children is harmless because the eligibility tree only reads it on top-level fields).
4. **`ON DELETE RESTRICT`** on the new pointers (`System.DefaultQcViewId`, `SystemRoleView.QcViewId`). Existing pointers (`DefaultViewId` / `QuickViewId` / `JobCardViewId`) keep `SET NULL` — A=2 in the design decision shorthand: only NEW pointers block deletion.

## Resolution chain (server-side)

```
SystemRoleView.QcViewId            [user's primary role]
?? System.DefaultQcViewId
?? SystemRoleView.DefaultViewId    [user's primary role]
?? System.DefaultViewId
?? null  → 400 "no-qc-view-configured"
```

The fall-through to operational defaults (steps 3-4) makes the QC affordance robust for tenants with role-customised operational views and no QC-specific configuration — they get the operational view rendered in QC mode.

The chain is implemented as `IJobFieldsViewService.ResolveQcViewIdAsync(systemId, userRoles)` consumer-side (TorqueTech). The `QcSignoffOrchestrator.StartAsync` signature drops the client-supplied `viewId`; the server resolves and the client never picks.

## Eligibility (3-step, one-level, no recursion)

Applied per top-level field (`ParentFieldId IS NULL`) when rendering a job form in QC kind:

```
1. field.ExcludeFromQc = true?
   → DROP subtree (skip field + any children)

2. Has direct children?
   → Use children, filtered to Type ∈ QcEligibleTypes.
     (One-level only. No recursion. No per-child opt-out check.)

3. No children → evaluate field itself:
   Type ∈ QcEligibleTypes AND Type ≠ "empty" → KEEP
   Otherwise                                  → DROP
```

`QcEligibleTypes` = `{ boolean, boolean-attachment, number, number-attachment, empty }`.

### Effect by location

| Set `ExcludeFromQc` on | Effect |
|---|---|
| Top-level **leaf** (no children) | Drops the field |
| Top-level **parent** (has children) | Drops the parent AND all its children (subtree-level cascade) |
| **Child** field | Irrelevant — never read |

This corrects a latent oversight in the original F1 implementation, where step 2 added all children regardless of type.

## Renderer dispatch — `ScreenSectionsRenderer kind` prop

`ScreenSectionsRenderer` (npm) gains a `kind?: 'operational' | 'qc'` prop (default `"operational"`). Dispatch matrix:

| `Type` | × `operational` | × `qc` |
|---|---|---|
| `boolean` | checkbox / toggle | pass/fail toggle |
| `boolean-attachment` | toggle + photo button | pass/fail toggle + photo slot |
| `number` | numeric input | numeric input + tolerance display (`Min – Max Unit`) |
| `number-attachment` | numeric input + photo button | numeric input + tolerance + photo slot |
| (other) | existing widgets | dropped (defensive — server eligibility tree should already strip) |

The QC dispatch lifts above the readonly check because QC editability follows the QC sign-off lifecycle (caller decides), not the operational job status.

## Server-side endpoints

| Endpoint | Behaviour |
|---|---|
| `GET /api/settings/job-fields/view/default?jobId=X&kind=qc` | Resolves QC view via 4-stop chain. Returns 400 with `errorCode: "no-qc-view-configured"` when chain returns null. |
| `POST /api/jobs/{id}/qc/signoff/start` | Body now `{}`. Server resolves view + creates `QcSignoff` row. |
| `PUT /api/system-views/system/{systemId}/default-qc-view { viewId? }` | Set/clear the tenant-level QC pointer. |
| `DELETE /api/system-views/{id}` | Returns 409 with `errorCode: "view-referenced-as-default"` if view is referenced as `DefaultQcViewId` or any `SystemRoleView.QcViewId`. |
| `GET /api/system-views/` | Projection extended with `IsDefaultQc` per view + `qcViewId` per role-view row. |

## Migration shape (consumer-side, TT)

Idempotent — uses `INFORMATION_SCHEMA` pre-checks because MySQL 9 doesn't support `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` natively (MariaDB does). 12 steps:

1. Idempotent `__EFMigrationsHistory` rows for both lib placeholders
2. `ALTER TABLE system_role_view ADD qc_view_id INT NULL` + FK `RESTRICT`
3. `ALTER TABLE system ADD default_qc_view_id INT NULL` + FK `RESTRICT`
4. `ALTER TABLE entity_field ADD exclude_from_qc TINYINT(1) DEFAULT 0`
5. Add `IX_*` indexes for the FK columns
6. Add `FK_system_system_view_default_qc_view_id` (not auto-generated by EF since `System` is in `@chthonic/tenant` which doesn't model the cross-library FK)
7. Hard-delete `system_view WHERE kind='qc' AND service_id IS NULL` — drops the F1-seeded "Default QC Checklist" rows. Decision **B=1**: small overlap of admin-edited QC views lose data; documented as data-loss caveat in PR description.
8. Backfill `UPDATE system SET default_qc_view_id = default_view_id WHERE default_qc_view_id IS NULL` — applies to ALL tenants (decision 1).
9. De-dupe `system_view` per `(system_id, service_id, kind)` keeping `MIN(system_view_id)` — closes a pre-existing duplicate-row hole from the `ExtractViews` migration which dropped `idx_system_view_service_unique` and never replaced it.
10. `CREATE UNIQUE INDEX ux_system_view_service_kind ON system_view (system_id, service_id, kind)`.

## Refs

- RFC 0022 § 12 Amendment 1 — full design rationale + alternatives
- [`@chthonic/tenant` v0.7.0](../tenant/index.md#v070--systemdefaultqcviewid-pr-18--rfc-0022--12) — `System.DefaultQcViewId` schema delta
- [`entity-field-bounds.md`](entity-field-bounds.md) § v0.8.0 — `ExcludeFromQc` semantics
- [TorqueTech PR 18 implementation template](https://github.com/chthonicsystems/architecture/blob/main/jobs-enhancements/03-pr-templates/18-F1b-qc-view-defaults.md)
- [`@chthonic/work` v0.2.0](../work/qc-signoff.md) — QC entities consumed downstream
