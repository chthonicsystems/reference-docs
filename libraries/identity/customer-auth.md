---
library: identity
version: 0.1.4
related-rfcs: [0004]
related-libs: [parties, notifications]
last-verified: 2026-05-22
tags: [identity, customer-auth, sms, otp]
summary: Mobile-based customer auth — SMS OTP verification, parties-customer linking.
---

# Customer auth

Customers (vehicle owners, vessel owners, pet owners, etc.) register with **mobile number + SMS OTP**, separately from staff. The result is a `User` with the `customer` role linked to a `parties.Customer` row by mobile.

## Flow

```
1. POST /api/customer-auth/register
   { firstName, lastName, mobile, password }
   → writes User (mobile-only, customer role) + UserVerification (mobile OTP, 6-digit, 10min expiry)
   → INotificationPort.SendVerificationCodeAsync(mobile, code) [Twilio]

2. POST /api/customer-auth/verify-mobile
   { mobile, code }
   → marks UserVerification as verified
   → ICustomerLinkingPort.LinkUserToCustomerAsync(userId, mobile, systemId)
     ↳ if @chthonic/parties finds a Customer row with matching mobile, link
     ↳ if not, the User has no Customer record yet (linked later when staff
        creates a matching Customer)

3. POST /api/customer-auth/login
   { mobile, password }
   → JWT issued
```

OAuth registration (Google/Microsoft/Apple → customer):

```
POST /api/customer-auth/oauth-register
{ provider, idToken, mobile }
```

Mobile is still required (so the linking step works).

## SMS provider

Identity speaks to SMS providers via `INotificationPort.SendVerificationCodeAsync(mobile, code)`. The default consumer adapter delegates to `@chthonic/notifications` → Twilio.

For E2E tests, the consumer may opt-in `BYPASS_SMS=true` server-side; the adapter then logs the OTP to console instead of calling Twilio. Playwright fixtures use this to register a test customer without real SMS:

```ts
// playwright/fixtures/customer-auth.ts
await api.post('/customer-auth/register', { firstName, lastName, mobile, password });
const code = await api.get('/dev/last-otp')   // dev-only endpoint
  .then(r => r.json())
  .then(o => o.code);
await api.post('/customer-auth/verify-mobile', { mobile, code });
```

`BYPASS_SMS` is a **server-side opt-in** for dev/test environments. Production NEVER sets this.

## ICustomerLinkingPort

```csharp
public interface ICustomerLinkingPort
{
    Task<int?> LinkUserToCustomerAsync(int userId, string mobile, int systemId);
}
```

Returns the linked `customer_id` if a match was found, or null. Identity stores the link via `User.CustomerId` (added to TT's User entity post-extraction; see [`@chthonic/parties` extension-points](../parties/extension-points.md)).

## Customer permissions

The `customer` role is **direct entity scoping**: customer users see only their own jobs / invoices / etc. via `JobService.GetMyJobsAsync(userId)` filtering by `Job.CustomerId = User.CustomerId`. The `customer` role has no `page:*` or `action:*` permissions in the canonical seed.

## Customer favorite systems

Customers can favourite multiple service centres (one Customer can fave many `System` rows):

```
POST /api/customer-auth/favorites
{ "systemId": 5 }

GET /api/customer-auth/favorites
→ list of UserFavoriteSystem rows
```

The `user_favorite_system` table is `(user_id, system_id, created_at)`. Surface used by the customer portal to switch between service-centre contexts.

## Resend OTP

```
POST /api/customer-auth/resend-otp
{ mobile }
```

Generates a fresh code; invalidates any existing un-verified `user_verification` rows for that mobile + systemId. Rate-limited at 3/hour per mobile (consumer-side rate limit; library doesn't enforce).

## Frontend hook

The same `useAuth()` hook works for customer auth:

```tsx
const { customerLogin, customerRegister, verifyMobile } = useAuth();

await customerRegister({ firstName, lastName, mobile, password });
await verifyMobile(mobile, code);
const session = await customerLogin(mobile, password);
```

## Verification table

`user_verification`:

| Column | Type | Use |
|---|---|---|
| `verification_id` | int PK | |
| `user_id` | int FK | |
| `type` | enum | `email`, `mobile`, `password_reset` |
| `code` | varchar(8) | 6-digit OTP, hashed |
| `verified_at` | datetime nullable | |
| `expires_at` | datetime | `created_at + 10min` |
| `created_at` | datetime | |

OTPs are stored hashed (BCrypt, low cost ≈ 4) so the table can't be exfiltrated for active codes.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`auth-flow.md`](auth-flow.md) — staff auth (different flow).
- [`libraries/parties/customers.md`](../parties/customers.md) — Customer entity that gets linked.
- [`libraries/notifications/`](../notifications/) — SMS dispatch.
- [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md) § Customer auth.
