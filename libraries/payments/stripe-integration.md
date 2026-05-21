---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, stripe, webhook]
summary: Stripe-specific implementation — StripePaymentProvider, webhook endpoint, env var setup.
---

# Stripe integration (`Chthonic.Payments.Stripe`)

Phase-1 implementation of `IPaymentProvider`. Wraps `Stripe.net` SDK; exposes the canonical webhook endpoint at `POST /api/stripe/webhook`.

## Setup

### Environment variables

```bash
STRIPE_SECRET_KEY=sk_test_...               # or sk_live_ in prod
STRIPE_WEBHOOK_SECRET=whsec_...             # set per webhook endpoint in Stripe Dashboard
STRIPE_STANDARD_PRICE_ID=price_...           # subscription Standard tier
STRIPE_PREMIUM_PRICE_ID=price_...            # subscription Premium tier
```

Missing any of the four → `AddStripePaymentProvider` throws at startup.

### Stripe Dashboard

1. **Test vs Live modes** — separate API keys per mode. Beta + dev use test mode (`sk_test_`); prod uses live mode (`sk_live_`).
2. **Products + prices** — one product per tier (Standard, Premium). Each product has a recurring monthly price.
3. **Webhook endpoint** — `https://<host>/api/stripe/webhook`. Subscribed events: `checkout.session.completed`, `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `customer.subscription.updated`, `customer.subscription.deleted`, `charge.dispute.created`.
4. **Webhook secret** — Stripe generates per endpoint; set to `STRIPE_WEBHOOK_SECRET`.

### TT current IDs (for reference)

- **Prod Standard**: product `prod_UNctD8ICcFrVL5`, price `price_1TOrduJRfubq1uxrp1cyxbct` ($25/mo USD).
- **Prod Premium**: product `prod_UNctL16qHIsWkR`, price `price_1TOre8JRfubq1uxrL1IycOXZ` ($100/mo USD).
- **Beta Standard**: `price_1TOqhpQraZ3K86x7jBIEGU5o` ($25/mo test).
- **Beta Premium**: `price_1SiWusQraZ3K86x750w5FRMo` ($100/mo test).

## Webhook endpoint

```csharp
// File: Endpoints/StripeWebhookEndpoint.cs
app.MapStripeWebhookEndpoint();   // POST /api/stripe/webhook
```

Flow:

1. Read raw body + `Stripe-Signature` header.
2. `EventUtility.ConstructEvent(body, header, secret)` — verifies HMAC.
3. Parse Stripe event.
4. `IWebhookIdempotencyStore.RecordOrSkipAsync(event.Id, "stripe")`. Skip if duplicate.
5. Map Stripe event type → `PaymentEvent` subclass.
6. `_dispatcher.DispatchAsync(evt)` → all subscribed handlers run.
7. Return 200 OK.

Stripe retries on 5xx + non-2xx; idempotency makes retries safe.

## Event mapping

| Stripe event | Maps to |
|---|---|
| `checkout.session.completed` | `CheckoutSessionCompletedEvent` |
| `payment_intent.succeeded` | `PaymentSucceededEvent` |
| `payment_intent.payment_failed` | `PaymentFailedEvent` |
| `charge.refunded` | `RefundSucceededEvent` |
| `customer.subscription.updated` | `SubscriptionRenewedEvent` |
| `customer.subscription.deleted` | `SubscriptionCancelledEvent` |
| `charge.dispute.created` | `DisputeOpenedEvent` |

## `StripePaymentProvider`

Implements `IPaymentProvider` using Stripe.net `PaymentIntentService`, `CheckoutSessionService`, `RefundService`, `SubscriptionService`. Each method:

- Builds Stripe.net request from `Chthonic.Payments` request DTO.
- Calls Stripe API.
- Maps Stripe response → `PaymentIntent` / `RefundResult` / `SubscriptionInfo`.
- Persists `payment_intent` row.

## Test mode + signature verification in tests

```csharp
// In xUnit
var fakeEvent = new Event { Id = "evt_test", Type = "payment_intent.succeeded", ... };
var signature = ComputeSignature(secret, JsonSerializer.Serialize(fakeEvent));
var resp = await client.PostAsync("/api/stripe/webhook",
    new StringContent(json) { Headers = { ["Stripe-Signature"] = signature } });
```

Stripe.net's `EventUtility.ConstructEvent` is strict; signature must match.

## Sandbox vs prod

| Environment | Mode | Account | Secret prefix |
|---|---|---|---|
| Local / Beta | Test | acct_1SgcrEQraZ3K86x7 | `sk_test_` |
| Production | Live | acct_1Sgcq8JRfubq1uxr | `sk_live_` |

**Never** put live keys in beta or local config. Stripe rejects test calls with live keys (and vice versa).

## Tests

| File | Coverage |
|---|---|
| `StripeWebhookEndpointTests` | Signature verification, event parsing, idempotency call, dispatch |
| `StripePaymentProviderTests` | Stripe.net mocked; intent + checkout + refund + subscription methods |

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`provider-abstraction.md`](provider-abstraction.md), [`webhook-idempotency.md`](webhook-idempotency.md).
- [RFC 0005](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0005-payments-portability.md).
