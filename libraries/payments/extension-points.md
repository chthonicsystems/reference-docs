---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, extension-points]
summary: Extension points — IPaymentProvider for new providers, IPaymentEventHandler for events, IWebhookIdempotencyStore for storage.
---

# Extension points

Three primary extension points: add a new payment provider, subscribe to events, override idempotency storage.

## `IPaymentProvider` — add a new provider

Phase-2 + future providers slot in by implementing the interface and shipping as a sister package.

```csharp
public class TapPaymentProvider : IPaymentProvider
{
    public string Name => "tap";
    public Task<PaymentIntent> CreatePaymentIntentAsync(CreatePaymentIntentRequest req) { /* tap-sdk */ }
    public Task<RefundResult> RefundAsync(string id, Money? partial = null) { /* tap-sdk */ }
    // ... etc
}
```

Package layout:

```
chthonicsystems/payments-tap/
├── src/Chthonic.Payments.Tap/
│   ├── Chthonic.Payments.Tap.csproj      # references Chthonic.Payments + tap-sdk
│   ├── TapPaymentProvider.cs
│   ├── Endpoints/TapWebhookEndpoint.cs
│   ├── Configuration/TapOptions.cs
│   └── ServiceCollectionExtensions.cs    # AddTapPaymentProvider(config)
└── ...
```

Consumer registration:

```csharp
builder.Services.AddTapPaymentProvider(builder.Configuration);
```

The DI container holds multiple `IPaymentProvider` instances; consumer picks one by `.Name` at the call site.

## `IPaymentEventHandler<TEvent>` — subscribe to events

Each event type can have multiple handlers. All registered handlers run on dispatch.

```csharp
public class MyHandler : IPaymentEventHandler<CheckoutSessionCompletedEvent>
{
    public async Task HandleAsync(CheckoutSessionCompletedEvent evt) { ... }
}
```

```csharp
builder.Services.AddScoped<IPaymentEventHandler<CheckoutSessionCompletedEvent>, MyHandler>();
```

Register multiple handlers on the same event:

```csharp
builder.Services.AddScoped<IPaymentEventHandler<PaymentSucceededEvent>, InvoiceMarkPaidHandler>();
builder.Services.AddScoped<IPaymentEventHandler<PaymentSucceededEvent>, NotifyCustomerEmailHandler>();
builder.Services.AddScoped<IPaymentEventHandler<PaymentSucceededEvent>, AccountingSyncHandler>();
```

Order is registration order. Handlers are independent; one failing doesn't stop the others (each runs in its own try/catch).

## Event types

| Event | Trigger |
|---|---|
| `CheckoutSessionCompletedEvent` | Stripe checkout finalised — typically subscription signup |
| `PaymentSucceededEvent` | One-off payment captured |
| `PaymentFailedEvent` | One-off payment failed (declined, etc.) |
| `RefundSucceededEvent` | Refund processed |
| `SubscriptionRenewedEvent` | Subscription renewed (recurring) |
| `SubscriptionCancelledEvent` | Subscription cancelled |
| `DisputeOpenedEvent` | Chargeback opened |

Add a new event type by:

1. Add `class FooEvent : PaymentEvent` to `PaymentEvents/`.
2. Update each provider's webhook handler to map provider events → `FooEvent`.
3. Bump minor version.

## `IWebhookIdempotencyStore` — alternate storage

Default impl persists to `webhook_idempotency_entry` table. Override for high-volume cases:

```csharp
public class RedisWebhookIdempotencyStore : IWebhookIdempotencyStore
{
    private readonly IConnectionMultiplexer _redis;
    public async Task<bool> RecordOrSkipAsync(string key, string provider)
    {
        var inserted = await _redis.GetDatabase().StringSetAsync(
            $"webhook:{provider}:{key}", "1",
            expiry: TimeSpan.FromDays(30),
            when: When.NotExists);
        return inserted;   // false = duplicate, skip dispatch
    }
}
```

```csharp
builder.Services.AddScoped<IWebhookIdempotencyStore, RedisWebhookIdempotencyStore>();
```

## Money currency support

`Money` has no currency-specific logic beyond comparison. Adding a new currency requires no library change — just pass the ISO-4217 code. Currency-symbol display for human output goes through `@chthonic/locale.FormatHelper.FormatCurrency`.

For currencies without minor units (e.g. JPY, KRW), `AmountMinor` IS the major value (no division by 100 on display). Consumers must handle this if they assume always-2-decimal currencies.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`provider-abstraction.md`](provider-abstraction.md), [`webhook-idempotency.md`](webhook-idempotency.md), [`stripe-integration.md`](stripe-integration.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 2 (two-package shape).
