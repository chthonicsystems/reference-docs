---
library: notes
package-nuget: Chthonic.Notes
package-npm: '@chthonicsystems/notes'
version: 0.1.0
related-rfcs: [0011]
related-libs: [tenant, files, notifications, audit]
last-verified: 2026-05-22
tags: [cross-cutting, notes, polymorphic-fk, threading]
summary: Entity annotations with polymorphic FK + threading + unread tracking.
---

# `@chthonicsystems/notes` / `Chthonic.Notes`

Entity annotations — comments, internal notes, customer-visible communications — that attach to any entity in any library. Polymorphic FK pattern, optional threading, unread tracking.

## Purpose

Every entity in a Chthonic product (Job, Customer, Vehicle, Booking, Invoice, Vessel, Pet, ...) needs the ability to:

- Attach notes (text + photos).
- Distinguish customer-visible from internal-only.
- Thread replies (v0.2.0+).
- Track read/unread state per user (v0.2.0+).

`@chthonic/notes` provides this once.

## Public surface

### .NET

| Type | Role |
|---|---|
| `INoteService` / `NoteService` | CRUD over notes |
| `INoteEntityAccessProvider` | Per-entity access decisions (consumer port) |
| `INoteCreatedHandler` | Post-create hook (consumer port; e.g. notification dispatch) |
| `MapChthonicNotesEndpoints(opts)` | `/api/notes/*` (sister-product ready; TT keeps its own) |
| `services.AddChthonicNotes()` | DI entry point |

**Domain entity:** `Note`. Polymorphic FK on `(entity_type, entity_id)`.

### npm

| Export | Role |
|---|---|
| `<NotesPanel>` | Full notes panel for an entity |
| `<ChatBubble>` | Single-note rendering |
| `useNotes({ entityType, entityId })` | Hook for paginated notes |
| `setHttpAdapter`, `setUseAuth`, `setFeatureGate`, `setPhotoCapture` | npm peer-injection adapters |

## Schema

```
note
  note_id          int PK
  system_id        int
  entity_type      varchar(50)    'Job', 'Vessel', 'Customer', ...
  entity_id        int
  body             text
  is_internal      bool             # vs customer-visible
  parent_note_id   int?             # for threading (v0.2.0+)
  created_by       int FK → users
  created_at       datetime
  deleted_at       datetime?

  index ix_note_entity (entity_type, entity_id)
  index ix_note_system (system_id)
```

NotePhoto stays consumer-side at v0.1.0 (cross-library FK to `note.note_id`). NoteRead (unread tracking) deferred to v0.2.0+.

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/files` | Photo attachments via `(entity_type='Note', entity_id=note_id)` |
| `@chthonic/notifications` | Notify on customer-visible note |
| `@chthonic/audit` | Audit on create/update/delete |

## Extension points

| Hook | Use |
|---|---|
| `INoteEntityAccessProvider` | Per-entity access — does this user have permission to see notes on this entity? |
| `INoteCreatedHandler` | Post-create dispatch — typically forwards to `@chthonic/notifications` |

## Consuming this library

```csharp
builder.Services.AddScoped<INoteEntityAccessProvider, MyNoteAccessProvider>();
builder.Services.AddScoped<INoteCreatedHandler, MyNoteHandler>();
builder.Services.AddChthonicNotes();
// TT keeps its own /api/notes/* endpoints. Sister products mount the library's:
// app.MapChthonicNotesEndpoints();
```

```tsx
import { setHttpAdapter, NotesPanel } from '@chthonicsystems/notes';
setHttpAdapter(httpService);

<NotesPanel entityType="Job" entityId={jobId} systemId={systemId} />
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`polymorphic-attachment.md`](polymorphic-attachment.md), [`threading.md`](threading.md), [`unread-tracking.md`](unread-tracking.md), [`extension-hooks.md`](extension-hooks.md).
- Library repo: [chthonicsystems/notes](https://github.com/chthonicsystems/notes).
- [RFC 0011](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0011-notes-entity-annotations.md).
