---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, provider-abstraction]
summary: IPaymentProvider interface + how to implement a new provider.
---

# Provider abstraction

`IPaymentProvider` is the core abstraction. Phase-1 ships Stripe; Phase-2 adds Tap (Saudi/UAE), Square (US/AU), Razorpay (India), Adyen (global enterprise). Each ships as a sister NuGet package.

## Interface

```csharp
public interface IPaymentProvider
{
    string Name { get; }   // 'stripe', 'tap', 'square', ...

    Task<PaymentIntent> CreatePaymentIntentAsync(CreatePaymentIntentRequest req);
    Task<PaymentIntent> CreateCheckoutSessionAsync(CreateCheckoutSessionRequest req);
    Task<RefundResult>  RefundAsync(string providerIntentId, Money? partialAmount = null);

    Task<SubscriptionInfo> GetSubscriptionAsync(string providerSubscriptionId);
    Task CancelSubscriptionAsync(string providerSubscriptionId, bool atPeriodEnd = true);
}
```

## Request shapes

```csharp
public record CreatePaymentIntentRequest
{
    public required int SystemId { get; init; }
    public required Money Amount { get; init; }
    public required string Description { get; init; }
    public Dictionary<string, string> Metadata { get; init; } = new();
    public string? CustomerEmail { get; init; }
    public string? ReturnUrl { get; init; }
}

public record CreateCheckoutSessionRequest
{
    public required int SystemId { get; init; }
    public required string PriceId { get; init; }       // provider-specific price/sku
    public required string SuccessUrl { get; init; }
    public required string CancelUrl { get; init; }
    public Dictionary<string, string> Metadata { get; init; } = new();
}
```

## Multi-provider DI resolution

```csharp
// Multiple providers registered:
builder.Services.AddStripePaymentProvider(config);
builder.Services.AddTapPaymentProvider(config);

// Consumer picks at call site:
public class CheckoutService
{
    private readonly IEnumerable<IPaymentProvider> _providers;
    public CheckoutService(IEnumerable<IPaymentProvider> providers) => _providers = providers;

    public IPaymentProvider Pick(string providerName)
        => _providers.First(p => p.Name == providerName);
}
```

A tenant's preferred provider is typically stored on the `system` row or `system_configuration`. The consumer reads the tenant's preference and routes to the matching `IPaymentProvider`.

## Behavioural contract

- `CreatePaymentIntentAsync` MUST persist a `payment_intent` row before returning. The returned `PaymentIntent.PaymentIntentId` is the local DB row PK; `ProviderIntentId` is the upstream ID.
- `RefundAsync` updates `payment_intent.status` to `refunded` (full) or `partially_refunded`. Doesn't delete the row.
- `CancelSubscriptionAsync` with `atPeriodEnd=true` (default) keeps the subscription active until the current period ends; `false` cancels immediately.
- Webhook events dispatched via `IPaymentEventDispatcher` after the upstream event lands. Local DB writes happen in event handlers, not provider methods.

## Currency support

Each provider supports a different currency set:

| Provider | Currencies |
|---|---|
| Stripe | 135+ (USD, AUD, EUR, GBP, JPY, INR, etc.) |
| Tap | AED, SAR, BHD, KWD, OMR, QAR, EGP, USD |
| Square | USD, CAD, AUD, GBP, JPY, EUR |
| Razorpay | INR primarily |

Consumer enforces tenant currency vs provider capability — the library doesn't reject unsupported currencies at compile time.

## Related

- [`extension-points.md`](extension-points.md) — adding a new provider.
- [`stripe-integration.md`](stripe-integration.md) — Phase-1 implementation.
- [`webhook-idempotency.md`](webhook-idempotency.md) — duplicate handling.
