---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, consumption]
summary: Code-level integration walkthrough for @chthonic/payments + Stripe.
---

# Consuming `@chthonic/payments`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Payments" Version="0.1.0" />
<PackageReference Include="Chthonic.Payments.Stripe" Version="0.1.0" />
```

(Phase-2 providers added as additional `<PackageReference>`s.)

## 2. Configure Stripe options

```bash
# .env / GitHub secrets
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_STANDARD_PRICE_ID=price_...
STRIPE_PREMIUM_PRICE_ID=price_...
```

## 3. Register DI

```csharp
// File: api/Program.cs
using Chthonic.Payments;
using Chthonic.Payments.Stripe;

builder.Services.AddChthonicPayments(builder.Configuration);
builder.Services.AddStripePaymentProvider(builder.Configuration);
```

Validates `StripeOptions` at startup; throws if any of `STRIPE_*` missing.

## 4. Subscribe to events

```csharp
builder.Services.AddScoped<IPaymentEventHandler<CheckoutSessionCompletedEvent>, TenantSignupCheckoutHandler>();
builder.Services.AddScoped<IPaymentEventHandler<PaymentSucceededEvent>, InvoiceMarkPaidHandler>();
builder.Services.AddScoped<IPaymentEventHandler<RefundSucceededEvent>, RefundLedgerHandler>();
```

Handlers:

```csharp
public class InvoiceMarkPaidHandler : IPaymentEventHandler<PaymentSucceededEvent>
{
    public async Task HandleAsync(PaymentSucceededEvent evt)
    {
        var invoice = await _db.Invoices.FirstAsync(i => i.PaymentIntentId == evt.PaymentIntentId);
        invoice.Status = InvoiceStatus.Paid;
        invoice.PaidAt = evt.Timestamp;
        await _db.SaveChangesAsync();
    }
}
```

## 5. Map webhook endpoint

```csharp
// File: api/Program.cs
app.MapStripeWebhookEndpoint();
```

`POST /api/stripe/webhook` is now live. Stripe sends events here; signature verified using `STRIPE_WEBHOOK_SECRET`.

## 6. Register EF configurations + migrations

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(PaymentsModuleMarker).Assembly);
```

Or, if shipping the migration as a coexisting library, insert `__EFMigrationsHistory` row:

```sql
INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion)
VALUES ('20260515181001_ChthonicPayments_0001_Initial', '9.0.0');
```

## 7. Create a payment intent (consumer service)

```csharp
public class BookingDepositService(IPaymentProvider payments)
{
    public async Task<PaymentIntent> CreateDepositAsync(int bookingId, Money amount)
    {
        return await payments.CreatePaymentIntentAsync(new CreatePaymentIntentRequest
        {
            SystemId = systemId,
            Amount = amount,
            Description = $"Deposit for booking #{bookingId}",
            Metadata = new() { ["bookingId"] = bookingId.ToString() },
        });
    }
}
```

## 8. Subscription tier change (tenant)

The Stripe webhook fires `CheckoutSessionCompletedEvent`. Consumer registers a handler that:

1. Reads the customer's `stripe_customer_id`.
2. Looks up the matching `system_package` row.
3. Updates `tier`.
4. (Optionally) flushes conflicting `feature_override` rows.

`@chthonic/tenant`'s `TenantSubscriptionEventHandler` ships a default impl — register it via `services.AddScoped<IPaymentEventHandler<CheckoutSessionCompletedEvent>, TenantSubscriptionEventHandler>()`.

## 9. Phase-2 provider parallel install

```xml
<PackageReference Include="Chthonic.Payments.Tap" Version="0.1.0" />
```

```csharp
builder.Services.AddTapPaymentProvider(builder.Configuration);
```

Now both Stripe and Tap are available. The consumer picks at the call site:

```csharp
var providers = serviceProvider.GetServices<IPaymentProvider>();
var stripe = providers.First(p => p.Name == "stripe");
var tap = providers.First(p => p.Name == "tap");
```

## 10. Verification

- [ ] `POST /api/stripe/webhook` processes events; signature verified.
- [ ] `webhook_idempotency_entry` rows written; duplicates rejected.
- [ ] `PaymentSucceededEvent` handler fires; invoice marked paid.
- [ ] `payment_intent` rows persisted with provider state.
- [ ] Subscription upgrade (Standard → Premium) updates `system_package.tier`.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`provider-abstraction.md`](provider-abstraction.md), [`webhook-idempotency.md`](webhook-idempotency.md), [`stripe-integration.md`](stripe-integration.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 2 (two-package shape).
