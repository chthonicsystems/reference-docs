---
library: scheduling
version: 0.1.0
last-verified: 2026-06-06
tags: [dispatch-board, dnd-kit, react, ux, frontend]
summary: Dispatch-board UX contract — composable React subcomponents over @dnd-kit/core. Render-prop pattern for per-product preview content. Schedule-X audit (premium licensing) drove the dnd-kit choice.
---

# Dispatch board (UX contract)

## Substrate: `@dnd-kit/core`

The npm package's React subcomponents wrap [@dnd-kit/core](https://dndkit.com/) for drag-drop. dnd-kit is MIT-licensed (~30 KB total) and provides `useDraggable` / `useDroppable` primitives without imposing layout opinions.

**Why dnd-kit over Schedule-X / FullCalendar:**

Per [RFC 0029 § 12 Amendment 1 12f](../../../architecture/rfcs/0029-dispatch-board.md#12f-drag-drop-substrate--dnd-kit-native-schedule-x-audit-blocked) — the Schedule-X audit on 2026-06-06 found `@sx-premium/drag-and-drop` and `@sx-premium/resource-scheduler` are paid premium plugins (€479/yr or €999 lifetime, both for 2-3 devs). FullCalendar Resource Timeline has the same model. dnd-kit is MIT, ~30 KB, and saves ongoing per-product licensing across TT + MarineDeck + FlowLift + PetCare. The cost: ~1 week of additional UX engineering to hand-build the resource × time-grid layout.

## Composable subcomponents

Per [RFC 0029 § 12 Amendment 1 12g](../../../architecture/rfcs/0029-dispatch-board.md#12g-ui-scope--composable-subcomponents-per-planning-group-b-q4--b), the lib exports four subcomponents rather than one opinionated `<DispatchBoard>` widget. Each consumer composes them with their own render-props.

### `<DispatchBoardLayout>` — top-level orchestrator

Wraps a dnd-kit `<DndContext>` around lanes + grid header. Reads slots/resources via lib hooks (or props if provided).

```tsx
<DispatchBoardLayout
  systemId={systemId}
  from={fromIso}
  to={toIso}
  resources={resourcesProp}    // optional; else useResources() fetches
  slots={slotsProp}            // optional; else useScheduleSlots() fetches
  renderLaneHeader={(r) => ...}
  renderSlotPreview={(s) => ...}
  onSlotDragEnd={(payload) => ...}
  readOnly={false}             // mobile read-only mode
/>
```

### `<ResourceLane>` — single-resource row

dnd-kit `useDroppable` drop target. Header + body. Header is render-prop'd for per-product admin affordances.

```tsx
<ResourceLane
  resource={resource}
  slots={slotsForThisResource}
  renderHeader={(r) => <span>{r.name} <small>{r.resourceType}</small></span>}
>
  {slots.map(s => <SlotCard key={s.scheduleSlotId} slot={s} ... />)}
</ResourceLane>
```

### `<SlotCard>` — slot tile

dnd-kit `useDraggable` source. Generic over preview type:

```tsx
<SlotCard<TPreview>
  slot={slot}
  jobPreview={jobPreviewLookup[slot.jobId]}
  renderPreview={(s, p) => <span>Job #{s.jobId} · {p.vehicleReg}</span>}
  draggable={true}    // false on mobile
/>
```

Default render: `Job #N` or `Booking #N` if no `renderPreview` supplied.

### `<TimeGridHeader>` — date/hour ruler

Computes column headers from `[from, to)` at the given `hourStep`. Pure presentation; no drag interaction.

```tsx
<TimeGridHeader from={fromIso} to={toIso} hourStep={1} />
```

## TT-specific composition

```tsx
<DispatchBoardLayout
  systemId={user.system.systemId}
  from={from}
  to={to}
  renderSlotPreview={(slot) => (
    <span>
      {slot.jobId ? `Job #${slot.jobId}` : `Booking #${slot.bookingId}`}
    </span>
  )}
  renderLaneHeader={(resource) => (
    <span className="dispatch-board-lane-name">
      {resource.name}
      <small className="dispatch-board-lane-type">{resource.resourceType}</small>
    </span>
  )}
  onSlotDragEnd={async (payload) => {
    await reassign({
      scheduleSlotId: payload.scheduleSlotId,
      resourceId: payload.newResourceId,
      startAt: payload.newStartAt,
      endAt: payload.newEndAt,
    });
  }}
  className="tt-dispatch-board"
/>
```

TT's `tt-dispatch-board` CSS class adds product-specific chrome (yellow `--brand-primary` slot tiles, Ionic typography) on top of the lib's `.scheduling-*` primitive classes.

## Mobile handling

Mobile renders a separate `MySchedule.tsx` page that does NOT use `<DispatchBoardLayout>` — it's a read-only `<IonList>` of slots assigned to the current mechanic for today. Drag-drop is desktop-primary per [RFC 0029 § 12 Amendment 1 12k](../../../architecture/rfcs/0029-dispatch-board.md#12k-mobile-parity--push-only-per-planning-group-c-misc).

The lib's `<DispatchBoardLayout readOnly={true}>` prop disables drag-drop for any consumer that wants to render the full board view in read-only mode (e.g. customer-facing "your appointment" view, future iteration).

## Drag interaction payload

```tsx
interface SlotDragEnd {
  scheduleSlotId: number;
  oldResourceId: number;
  newResourceId: number;
  oldStartAt: string;
  newStartAt: string;
  oldEndAt: string;
  newEndAt: string;
}
```

**Note**: dnd-kit cannot infer the time-axis position from a horizontal-grid drop. The library's `onSlotDragEnd` payload sets `newStartAt = oldStartAt` and `newEndAt = oldEndAt` — consumers compute the new times if their grid layout supports time-axis dragging. This is a v0.2.x improvement target: parameterise the time-axis snap-to-grid logic.

## Cross-references

- [Architecture](architecture.md)
- [Consumption — Frontend](consumption.md#frontend-typescript--react)
- [Extension points](extension-points.md)
- [RFC 0029 § 12 Amendment 1 12f / 12g](../../../architecture/rfcs/0029-dispatch-board.md#12-amendment-1--implementation-decisions-and-divergences-2026-06-06)
- [`@dnd-kit/core` documentation](https://dndkit.com/)
