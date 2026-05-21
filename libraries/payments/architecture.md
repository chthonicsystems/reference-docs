---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, architecture, schema, two-package]
summary: Two-package shape (interface + per-provider impl), payment events, idempotency.
---

# Architecture

## File layout

### `Chthonic.Payments` (interface package)

```
src/Chthonic.Payments/
├── IPaymentProvider.cs                   # Provider abstraction
├── Domain/
│   ├── Money.cs                          # Currency + amount value type
│   ├── PaymentIntent.cs
│   └── WebhookIdempotencyEntry.cs
├── PaymentEvents/
│   ├── PaymentEvent.cs                   # base
│   ├── IPaymentEventDispatcher.cs
│   ├── CheckoutSessionCompletedEvent.cs
│   ├── PaymentSucceededEvent.cs
│   ├── PaymentFailedEvent.cs
│   ├── RefundSucceededEvent.cs
│   ├── SubscriptionRenewedEvent.cs
│   ├── SubscriptionCancelledEvent.cs
│   └── DisputeOpenedEvent.cs
├── Services/
│   ├── IWebhookIdempotencyStore.cs
│   └── PaymentEventDispatcher.cs
├── Configuration/                        # EF entity configs
├── Migrations/                           # EF migrations
└── ServiceCollectionExtensions.cs
```

### `Chthonic.Payments.Stripe` (impl package)

```
src/Chthonic.Payments.Stripe/
├── StripePaymentProvider.cs              # IPaymentProvider impl
├── Endpoints/StripeWebhookEndpoint.cs    # POST /api/stripe/webhook
├── Configuration/StripeOptions.cs
└── ServiceCollectionExtensions.cs
```

## Schema

```
payment_intent
  payment_intent_id    int PK
  system_id            int FK
  provider             enum 'stripe' | 'tap' | 'square' | ...
  provider_intent_id   varchar     (e.g. Stripe pi_...)
  amount_minor         bigint      (cents / smallest currency unit)
  currency             char(3)     (ISO-4217)
  status               enum 'pending' | 'succeeded' | 'failed' | 'refunded' | 'partially_refunded'
  metadata             json
  created_at           datetime
  updated_at           datetime

webhook_idempotency_entry
  idempotency_key      varchar PK   (provider event id, e.g. evt_...)
  provider             enum
  processed_at         datetime
```

## Two-package shape

```mermaid
graph LR
    Consumer[Consumer app]
    P[Chthonic.Payments<br/>interface package]
    S[Chthonic.Payments.Stripe<br/>impl package]
    T[Chthonic.Payments.Tap<br/>(Phase-2)]

    Consumer -->|always references| P
    Consumer -.references only the<br/>providers it needs.-> S
    Consumer -.-> T
    S -->|references| P
    T -->|references| P
```

A consumer that only needs Tap doesn't pull in `Stripe.net` (~5MB transitive deps).

## `IPaymentProvider`

```csharp
public interface IPaymentProvider
{
    string Name { get; }    // 'stripe', 'tap', 'square', ...

    Task<PaymentIntent> CreatePaymentIntentAsync(CreatePaymentIntentRequest request);
    Task<PaymentIntent> CreateCheckoutSessionAsync(CreateCheckoutSessionRequest request);
    Task<RefundResult> RefundAsync(string providerIntentId, Money? partialAmount = null);
    Task<SubscriptionInfo> GetSubscriptionAsync(string providerSubscriptionId);
    Task CancelSubscriptionAsync(string providerSubscriptionId, bool atPeriodEnd = true);
}
```

## Event dispatch

```csharp
public interface IPaymentEventDispatcher
{
    void Subscribe<TEvent>(Func<TEvent, Task> handler) where TEvent : PaymentEvent;
    Task DispatchAsync(PaymentEvent evt);
}

public interface IPaymentEventHandler<TEvent> where TEvent : PaymentEvent
{
    Task HandleAsync(TEvent evt);
}
```

Provider impl (Stripe webhook handler) parses incoming event → maps to `PaymentEvent` subclass → calls `dispatcher.DispatchAsync(evt)` → all subscribed handlers run.

## Webhook idempotency

Every provider event carries a unique ID (`evt_...` for Stripe). The default `WebhookIdempotencyStore` writes to `webhook_idempotency_entry` BEFORE dispatching:

```
1. Receive POST /api/stripe/webhook
2. Verify Stripe signature
3. Parse event (id = evt_xyz)
4. INSERT INTO webhook_idempotency_entry (idempotency_key='evt_xyz', provider='stripe')
   - if duplicate key → 200 OK without dispatching (already processed)
   - else → continue
5. Map to PaymentEvent + dispatch
```

## Money type

```csharp
public readonly record struct Money(string Currency, long AmountMinor)
{
    public static Money FromMajor(string currency, decimal major)
        => new(currency, (long)Math.Round(major * 100m, MidpointRounding.AwayFromZero));

    public decimal ToMajor() => AmountMinor / 100m;
    public Money Add(Money other) { /* throws if Currency differs */ }
    public Money Subtract(Money other) { /* throws if Currency differs */ }
}
```

`AmountMinor` is the smallest currency unit (cents for USD; yen for JPY where there's no minor unit). Currency arithmetic enforces same-currency at compile time.

## Tests

| File | Coverage |
|---|---|
| `MoneyTests` | Arithmetic, equality, FromMajor/ToMajor, currency mismatch errors |
| `WebhookIdempotencyStoreTests` | Insert + duplicate handling |
| `PaymentEventDispatcherTests` | Subscribe + dispatch + multiple handlers |
| `StripePaymentProviderTests` (impl pkg) | Stripe.net mocked; intent + refund + subscription |
| `StripeWebhookEndpointTests` (impl pkg) | Signature verification, event parsing, idempotency |

## Related

- [`index.md`](index.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`provider-abstraction.md`](provider-abstraction.md), [`webhook-idempotency.md`](webhook-idempotency.md), [`money-type.md`](money-type.md), [`stripe-integration.md`](stripe-integration.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 2 (two-package shape).
- [RFC 0005](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0005-payments-portability.md).
