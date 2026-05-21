---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, architecture, schema]
summary: Notes internals — Note entity, polymorphic FK, threading + unread (deferred to v0.2.0+).
---

# Architecture

```
src/Chthonic.Notes/
├── Domain/Note.cs
├── Configuration/NoteConfiguration.cs
├── Endpoints/                       # /api/notes/* (sister-product ready)
├── Services/
│   ├── INoteService.cs / NoteService.cs
│   └── (auxiliary)
├── Extensions/
│   ├── INoteEntityAccessProvider.cs   # consumer port
│   └── INoteCreatedHandler.cs          # consumer port
├── Migrations/
├── NotesModuleMarker.cs
└── ServiceCollectionExtensions.cs

npm/src/
├── components/NotesPanel.tsx
├── components/ChatBubble.tsx
├── components/NoteThread.tsx
├── useNotes.ts
├── adapters.ts                      # peer-injection setHttpAdapter, setUseAuth, etc.
└── index.ts
```

## Note entity

```csharp
public class Note
{
    public int NoteId { get; set; }
    public int SystemId { get; set; }
    public string EntityType { get; set; } = "";
    public int EntityId { get; set; }
    public string Body { get; set; } = "";
    public bool IsInternal { get; set; }
    public int? ParentNoteId { get; set; }   // v0.2.0+ threading
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}
```

## Threading + unread (deferred)

`parent_note_id` schema column ships at v0.1.0 but threading UI + endpoint support is deferred to v0.2.0+. Same for unread tracking — schema room, no service yet.

## Tests

`NoteServiceTests`, `NotesEndpointsTests` cover CRUD + access provider hooks.

## Related

- [`polymorphic-attachment.md`](polymorphic-attachment.md), [`extension-hooks.md`](extension-hooks.md).
- [RFC 0011](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0011-notes-entity-annotations.md).
