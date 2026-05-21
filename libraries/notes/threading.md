---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, threading]
summary: Threading via parent_note_id — schema room ships at v0.1.0; UI + service deferred to v0.2.0+.
---

# Threading

`note.parent_note_id` is in the schema at v0.1.0 but **not exposed** in the v0.1.0 service / UI. Threading lands in v0.2.0+.

## Planned shape

When threading lands:

- `<NotesPanel>` will render thread roots as top-level cards; replies indented underneath.
- `POST /api/notes` accepts `parent_note_id` to start a reply.
- `useNotes()` returns `{ root: Note, replies: Note[] }` shape.
- A note can have at most one parent (no nested threads — flat reply lists, like Slack).

## Why deferred

v0.1.0 ships flat notes only. Threading requires UI work (collapse/expand, indent rendering) that wasn't on the critical path for the platform extraction. Schema room is reserved so v0.2.0 doesn't require a migration.

## Related

- [`unread-tracking.md`](unread-tracking.md) — also v0.2.0+.
- [RFC 0011](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0011-notes-entity-annotations.md) § Threading.
