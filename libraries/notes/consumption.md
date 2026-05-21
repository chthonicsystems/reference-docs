---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/notes`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Notes" Version="0.1.0" />
```

```json
"@chthonicsystems/notes": "0.1.0"
```

## 2. Implement extension hooks

```csharp
public class TTNoteAccessProvider : INoteEntityAccessProvider
{
    public Task<bool> CanReadAsync(string entityType, int entityId, int userId, int systemId) { /* ... */ }
    public Task<bool> CanWriteAsync(string entityType, int entityId, int userId, int systemId) { /* ... */ }
}

public class TTNoteHandler : INoteCreatedHandler
{
    private readonly ITTNotificationOrchestrator _notify;
    public TTNoteHandler(ITTNotificationOrchestrator notify) => _notify = notify;
    public async Task OnCreatedAsync(Note note)
    {
        if (!note.IsInternal && note.EntityType == "Job")
            await _notify.NotifyJobCommentAsync(note.EntityId, note.Body);
    }
}

builder.Services.AddScoped<INoteEntityAccessProvider, TTNoteAccessProvider>();
builder.Services.AddScoped<INoteCreatedHandler, TTNoteHandler>();
```

## 3. Register Notes

```csharp
builder.Services.AddChthonicNotes();
// TT keeps /api/notes/* — does NOT mount library endpoints.
// Sister products mount: app.MapChthonicNotesEndpoints();
```

## 4. Frontend bootstrap

```tsx
import { setHttpAdapter, setUseAuth, setFeatureGate, setPhotoCapture, NotesPanel } from '@chthonicsystems/notes';
import { httpService } from '../services/httpService';
import { useAuth } from '../contexts/AuthContext';

setHttpAdapter(httpService);
setUseAuth(useAuth);
setFeatureGate(useFeatureGate);
setPhotoCapture(takePhoto);

<NotesPanel entityType="Job" entityId={jobId} systemId={systemId} />
```

## Related

- [`polymorphic-attachment.md`](polymorphic-attachment.md), [`extension-hooks.md`](extension-hooks.md).
