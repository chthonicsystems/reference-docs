---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, extension-points]
summary: Two consumer ports — INoteEntityAccessProvider, INoteCreatedHandler.
---

# Extension points

| Hook | Use |
|---|---|
| `INoteEntityAccessProvider` | Per-entity access decisions — does this user/system have permission? |
| `INoteCreatedHandler` | Post-create dispatch — typically forwards to notifications |
| HTTP / auth / feature-gate / photo-capture (npm) | Set via `setHttpAdapter`, `setUseAuth`, `setFeatureGate`, `setPhotoCapture` |

## INoteEntityAccessProvider

```csharp
public interface INoteEntityAccessProvider
{
    Task<bool> CanReadAsync(string entityType, int entityId, int userId, int systemId);
    Task<bool> CanWriteAsync(string entityType, int entityId, int userId, int systemId);
}
```

Consumer implements per-entity access logic. TT example — only assigned mechanics + admins can read internal notes on a Job.

## INoteCreatedHandler

```csharp
public interface INoteCreatedHandler
{
    Task OnCreatedAsync(Note note);
}
```

Fires after a note is persisted. Multiple handlers allowed; library invokes them in registration order. TT registers a handler that forwards customer-visible notes to `@chthonic/notifications` for in-app push + email dispatch.

## Photo attachments

Notes can carry photo attachments via `@chthonic/files` polymorphic FK (`entity_type='Note'`, `entity_id=note_id`). The library doesn't own photo upload; consumers wire `<FileUploadButton entityType="Note" ... />` from `@chthonicsystems/files` inside note creation flows.

## Related

- [`extension-hooks.md`](extension-hooks.md), [`polymorphic-attachment.md`](polymorphic-attachment.md).
