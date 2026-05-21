---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, communications, in-app]
summary: <CommunicationsInbox> — in-app notification inbox component.
---

# `<CommunicationsInbox>`

Renders the current user's in-app communications. Matches the same shape as a chat / inbox UI — list of items, mark-read on view, real-time-ish polling.

## Usage

```tsx
import { setCommunicationsHttp, CommunicationsInbox } from '@chthonicsystems/notifications';
setCommunicationsHttp(httpService);

<CommunicationsInbox userId={userId} systemId={systemId} />
```

## Endpoint

```
GET    /api/communications?userId=...&systemId=...   # paginated
POST   /api/communications/{id}/mark-read
```

## Schema

```
communication
  communication_id   int PK
  system_id          int
  user_id            int
  channel            'in_app'
  body               text
  is_read            bool
  created_at         datetime
```

`InAppCommunicationService.SendAsync` writes a row when `NotificationChannel.InApp` is published. The component polls every 30 seconds for new entries (configurable via prop).

## Cross-channel context

A single notification `PublishAsync` with `channel: InApp` writes to `communication`. If the same notification dispatches to multiple channels (e.g. push + in-app for "your booking is approved"), the publisher emits one log per channel; in-app row is one of them.

## Related

- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`architecture.md`](architecture.md).
