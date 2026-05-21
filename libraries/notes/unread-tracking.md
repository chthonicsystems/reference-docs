---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, unread]
summary: Unread tracking — deferred to v0.2.0+. Schema design captured for forward-compat.
---

# Unread tracking

Per-user read state on notes. **Deferred to v0.2.0+**.

## Planned schema

```sql
CREATE TABLE note_read (
    note_id INT NOT NULL,
    user_id INT NOT NULL,
    read_at DATETIME NOT NULL,
    PRIMARY KEY (note_id, user_id)
);
```

## Planned API

```
GET /api/notes/unread-count?entityType=Job&entityId=42
   → { count: 3 }   # notes user hasn't read

POST /api/notes/{noteId}/mark-read
   → 204 No Content
```

## Frontend impact

`<NotesPanel>` will surface an "unread" indicator (badge count); reading a note (scrolling it into view + dwelling 1+s) auto-marks it read.

## v0.1.0 workaround

Consumers needing unread tracking before v0.2.0 implement on top:

```sql
-- Per-tenant table
CREATE TABLE my_note_read (note_id INT, user_id INT, read_at DATETIME, PRIMARY KEY (note_id, user_id));
```

Then call `_db.MyNoteRead.Add(...)` on every note view and surface `count(*)` queries to the UI.

## Related

- [`threading.md`](threading.md) — also v0.2.0+.
