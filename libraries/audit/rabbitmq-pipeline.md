---
library: audit
version: 0.1.4
related-rfcs: [0006]
last-verified: 2026-05-22
tags: [audit, rabbitmq, async-pipeline]
summary: RabbitMQ async write pipeline — exchange + queue + consumer + dead-letter.
---

# RabbitMQ pipeline

Audit writes happen out-of-band so request latency is never blocked on audit.

## Topology

```
exchange:       'audit-log' (direct)
queue:          'audit-log' (durable)
binding key:    'audit-log'
DLQ exchange:   'audit-log-dlq'
DLQ queue:      'audit-log-dlq' (durable)
```

`AuditLogger.LogAsync` publishes to the `audit-log` exchange. `AuditLogConsumer : BackgroundService` consumes from `audit-log` queue and batch-inserts to `audit_log` table.

## Message shape

Each message is a JSON-serialised `AuditEntry`:

```json
{
  "systemId": 1,
  "userId": 42,
  "category": "Work",
  "action": "job.completed",
  "entityType": "Job",
  "entityId": 17,
  "parentType": null,
  "parentId": null,
  "changes": { "status": ["InProgress", "Completed"] },
  "metadata": { "ip": "192.0.2.1" },
  "createdAt": "2026-05-22T03:45:00Z"
}
```

## Consumer batching

```csharp
// Pseudocode
while (running)
{
    var batch = await PullUpToAsync(50, timeoutMs: 200);
    if (batch.Count == 0) continue;
    await _db.AuditLogs.AddRangeAsync(batch.Select(MapToRow));
    await _db.SaveChangesAsync();
    foreach (var msg in batch) channel.BasicAck(msg.DeliveryTag);
}
```

Batch size 50 + 200ms timeout. On DB failure: nack-with-requeue, exponential backoff. After 3 retries, dead-letter to `audit-log-dlq` for manual inspection.

## Dead-letter handling

Failed audit writes land in `audit-log-dlq`. Operators can:

- Inspect via `rabbitmqctl list_queues audit-log-dlq messages`.
- Replay manually:

```bash
rabbitmqctl shovel audit-log-dlq audit-log     # if shovel plugin enabled
```

- Or dump + re-publish via a maintenance script.

## Idempotency

Audit writes are NOT idempotent at the message level — re-publishing the same audit message produces a second row. This is intentional: an audit is an event observation, not a derived state. If a message is re-delivered (channel reconnect mid-process), the consumer ACKs only after successful DB write so duplicates are rare.

## Operations

```bash
# Queue depth
rabbitmqctl list_queues audit-log messages

# DLQ depth
rabbitmqctl list_queues audit-log-dlq messages

# Consumer lag (heuristic)
mysql> SELECT MAX(created_at) FROM audit_log;   -- should be within seconds of NOW()
```

## Related

- [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [RFC 0006](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0006-audit-logging.md).
