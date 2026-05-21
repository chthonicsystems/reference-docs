---
library: payments
package-nuget: Chthonic.Payments
package-npm: '@chthonicsystems/payments'
version: 0.1.0
related-rfcs: [0005]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [core-domain, payments, two-package, stripe]
summary: Provider abstraction (Stripe + Phase-2 Tap/Square/Razorpay/Adyen) + webhook idempotency + Money type.
---

# `@chthonicsystems/payments` / `Chthonic.Payments`

Two-package shape: `Chthonic.Payments` is the provider-abstraction interface library; `Chthonic.Payments.Stripe` is the Phase-1 Stripe implementation. Phase-2 ships as additional sister packages (`Chthonic.Payments.Tap`, etc.) without breaking changes.

## Purpose

Decouple business logic from payment-provider SDKs. Tenant subscriptions (paid by tenant admin) and customer payments (e.g. booking deposits, parts pre-orders) flow through the same `IPaymentProvider` abstraction.

## Public surface

### .NET

**Package: `Chthonic.Payments` (interface package)**

| Type | File | Role |
|---|---|---|
| `IPaymentProvider` | `src/Chthonic.Payments/IPaymentProvider.cs` | Provider-abstraction core: `CreatePaymentIntentAsync`, `RefundAsync`, `CreateCheckoutSessionAsync`, `GetSubscriptionAsync` |
| `IPaymentEventDispatcher` | `src/Chthonic.Payments/PaymentEvents/IPaymentEventDispatcher.cs` | Event dispatch — consumer registers handlers per event type |
| `PaymentEvent` (abstract) + concrete events | `src/Chthonic.Payments/PaymentEvents/*.cs` | `CheckoutSessionCompletedEvent`, `PaymentSucceededEvent`, `PaymentFailedEvent`, `RefundSucceededEvent`, `SubscriptionRenewedEvent`, `SubscriptionCancelledEvent`, `DisputeOpenedEvent` |
| `Money` value type | `src/Chthonic.Payments/Domain/Money.cs` | Currency + amount; arithmetic + equality |
| `PaymentIntent` entity | `src/Chthonic.Payments/Domain/PaymentIntent.cs` | Persisted intent state |
| `IWebhookIdempotencyStore` | `src/Chthonic.Payments/Services/IWebhookIdempotencyStore.cs` | Dedup webhook events |

**Domain entities:** `PaymentIntent`, `WebhookIdempotencyEntry`. EF migrations registered via `PaymentsMigrationDbContext`.

**Package: `Chthonic.Payments.Stripe` (impl package)**

| Type | File | Role |
|---|---|---|
| `StripePaymentProvider : IPaymentProvider` | `src/Chthonic.Payments.Stripe/StripePaymentProvider.cs` | Stripe.net wrapper |
| `MapStripeWebhookEndpoint` | `src/Chthonic.Payments.Stripe/Endpoints/StripeWebhookEndpoint.cs` | `POST /api/stripe/webhook` |
| `StripeOptions` | `src/Chthonic.Payments.Stripe/Configuration/StripeOptions.cs` | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_STANDARD_PRICE_ID`, `STRIPE_PREMIUM_PRICE_ID` |

### npm

`@chthonicsystems/payments` — types only at v0.1.0. Future hooks for client-side Stripe Elements / Apple Pay / Google Pay flows.

## Dependencies

| Dep | Purpose |
|---|---|
| `Chthonic.Payments` | (interface package, no other Chthonic deps) |
| `Chthonic.Payments.Stripe` | depends on `Chthonic.Payments` + `Stripe.net` |

Phase-2 provider packages (Tap, Square) follow the same shape — depend on `Chthonic.Payments` + their respective SDK.

## Extension points

| Hook | Use |
|---|---|
| `IPaymentProvider` | Implement to add a new provider (Tap, Square, Razorpay, Adyen, MYOB Pay, ...) |
| `IPaymentEventDispatcher` | Subscribe to events: `dispatcher.Subscribe<CheckoutSessionCompletedEvent>(handler)` |
| `IWebhookIdempotencyStore` | Default implementation persists to DB; consumer can override (e.g. Redis) |

## Consuming this library

```csharp
// File: api/Program.cs
builder.Services.AddChthonicPayments(builder.Configuration);     // interface
builder.Services.AddStripePaymentProvider(builder.Configuration); // impl

// Subscribe to events
builder.Services.AddScoped<IPaymentEventHandler<CheckoutSessionCompletedEvent>, MyTenantSignupHandler>();
builder.Services.AddScoped<IPaymentEventHandler<PaymentSucceededEvent>, MyInvoiceMarkPaidHandler>();
```

```csharp
app.MapStripeWebhookEndpoint();   // POST /api/stripe/webhook (signature-verified)
```

Full walkthrough in [`consumption.md`](consumption.md).

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`provider-abstraction.md`](provider-abstraction.md), [`webhook-idempotency.md`](webhook-idempotency.md), [`money-type.md`](money-type.md), [`stripe-integration.md`](stripe-integration.md).
- Library repos: [chthonicsystems/payments](https://github.com/chthonicsystems/payments) + [chthonicsystems/payments-stripe](https://github.com/chthonicsystems/payments-stripe).
- [RFC 0005](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0005-payments-portability.md).
