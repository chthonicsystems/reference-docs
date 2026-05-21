---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, extension-hooks]
summary: INoteEntityAccessProvider + INoteCreatedHandler patterns and TT examples.
---

# Extension hooks

## INoteEntityAccessProvider

Decides who can read/write notes on which entity. The library checks per-call.

```csharp
public class TTNoteAccessProvider : INoteEntityAccessProvider
{
    private readonly TorqueTechDbContext _db;
    public TTNoteAccessProvider(TorqueTechDbContext db) => _db = db;

    public async Task<bool> CanReadAsync(string entityType, int entityId, int userId, int systemId)
    {
        if (await UserIsAdminAsync(userId)) return true;
        return entityType switch
        {
            "Job" => await UserIsAssignedMechanicAsync(userId, entityId)
                  || await UserIsCustomerOnJobAsync(userId, entityId),
            "Customer" => await UserCanSeeCustomerAsync(userId, entityId),
            _ => false
        };
    }

    public async Task<bool> CanWriteAsync(...) { /* similar */ }
}
```

## INoteCreatedHandler

Fires after persistence. Consumers commonly:

- Forward customer-visible notes to `@chthonic/notifications` for SMS/email/push.
- Update parent entity's `last_activity_at` (e.g. Job).
- Index in search.

```csharp
public class TTNoteHandler : INoteCreatedHandler
{
    public async Task OnCreatedAsync(Note note)
    {
        if (!note.IsInternal && note.EntityType == "Job")
            await _notify.NotifyJobCommentAsync(note.EntityId, note.Body);
    }
}

builder.Services.AddScoped<INoteCreatedHandler, TTNoteHandler>();
```

Multiple handlers OK (registration order). Handlers run inside the same request scope; failures DON'T roll back the note save (the note is already persisted before handlers fire).

## Customer-name privacy filtering

TT's note endpoints redact customer names when an internal-only-marked note's `body` is fetched by a customer. The library doesn't enforce this; the consumer does in its endpoint layer.

## Related

- [`extension-points.md`](extension-points.md), [`consumption.md`](consumption.md).
