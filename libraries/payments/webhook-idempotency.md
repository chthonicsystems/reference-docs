---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, webhook, idempotency]
summary: Webhook idempotency — duplicate-event detection via DB unique-key insert.
---

# Webhook idempotency

Payment providers retry webhook delivery on receiver errors. Without idempotency, a single Stripe event might be processed multiple times (e.g. `PaymentSucceeded` → invoice marked paid twice → audit log spam, accounting drift).

## Strategy

Every provider event has a unique ID (`evt_...` for Stripe). Store-or-skip on the `webhook_idempotency_entry` table.

```mermaid
graph TD
    R[POST /api/stripe/webhook]
    V[Verify signature]
    P[Parse event<br/>id = evt_xyz]
    I["INSERT INTO webhook_idempotency_entry<br/>(idempotency_key='evt_xyz', provider='stripe')"]
    D{insert succeeded?}
    Skip[200 OK<br/>(already processed)]
    Map[Map → PaymentEvent]
    Disp[Dispatch event]
    OK[200 OK]

    R --> V --> P --> I --> D
    D -->|no, duplicate key| Skip
    D -->|yes| Map --> Disp --> OK
```

## Schema

```sql
CREATE TABLE webhook_idempotency_entry (
    idempotency_key VARCHAR(200) NOT NULL,
    provider        VARCHAR(50)  NOT NULL,
    processed_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (idempotency_key, provider)
);
```

The composite PK is the only thing enforcing idempotency. INSERT IGNORE / ON DUPLICATE KEY UPDATE patterns work cleanly.

## Default `IWebhookIdempotencyStore`

```csharp
public class DbWebhookIdempotencyStore : IWebhookIdempotencyStore
{
    public async Task<bool> RecordOrSkipAsync(string key, string provider)
    {
        try
        {
            _db.WebhookIdempotencyEntries.Add(new WebhookIdempotencyEntry { IdempotencyKey = key, Provider = provider });
            await _db.SaveChangesAsync();
            return true;   // newly recorded; proceed to dispatch
        }
        catch (DbUpdateException) when (IsDuplicateKey)
        {
            return false;  // duplicate; skip dispatch
        }
    }
}
```

Returns `true` if the event is new (proceed); `false` if duplicate (200 OK, no dispatch).

## Retention

The `webhook_idempotency_entry` table grows unbounded. Provider event IDs are typically retained on the provider side for ~30 days; events older than that won't be retried. Set up a periodic cleanup:

```sql
DELETE FROM webhook_idempotency_entry WHERE processed_at < NOW() - INTERVAL 90 DAY;
```

(90-day retention is generous; 30 is safe.)

## Multi-provider keys

The composite PK `(idempotency_key, provider)` allows the same key value across providers. Stripe `evt_xyz` and a hypothetical Tap `evt_xyz` are independent rows. In practice provider event IDs are globally unique within their provider.

## Override storage

Consumer can swap to Redis / DynamoDB / etc. for high-volume deployments. See [`extension-points.md`](extension-points.md) § "IWebhookIdempotencyStore — alternate storage".

## Tests

`WebhookIdempotencyStoreTests`:

- New key → returns true + row written.
- Duplicate key → returns false + no second row.
- Concurrent inserts (race) → exactly one returns true (the other catches DbUpdateException).

## Related

- [`extension-points.md`](extension-points.md) — overriding storage.
- [`stripe-integration.md`](stripe-integration.md) — webhook signature verification before idempotency.
