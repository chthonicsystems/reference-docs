---
library: identity
package-nuget: Chthonic.Identity
package-npm: '@chthonicsystems/identity'
version: 0.1.4
related-rfcs: [0004]
related-libs: [locale, tenant, audit, parties]
last-verified: 2026-05-22
tags: [foundational, auth, rbac, oauth, jwt, sessions, api-keys]
summary: Authentication (JWT + OAuth) + users + customer auth + RBAC + sessions + API keys.
---

# `@chthonicsystems/identity` / `Chthonic.Identity`

The identity layer for every product on the Chthonic platform. Owns: JWT auth, three OAuth providers (Google + Microsoft + Apple), customer auth (mobile-based), RBAC (roles + permissions), session audit, asymmetric key auth (CLI), Firebase App Check.

## Purpose

Authenticate humans and machines, decide what they're allowed to do, and audit when they did it.

- **Human auth** — username/password + Google/Microsoft/Apple OAuth + invite-token completion + password reset.
- **Customer auth** — mobile-based registration with SMS OTP verification (separate from staff auth).
- **Machine auth** — asymmetric-key challenge/verify for the CLI.
- **RBAC** — 9 default roles (sysadmin, admin, director, mechanic, accountant, supervisor, reportviewer, customer, staff) + page/action-typed permissions.
- **Session audit** — every login / logout / impersonation writes an immutable row.

## Public surface

### .NET

**Package:** `Chthonic.Identity` (NuGet, v0.1.4)

| Type | File | Role |
|---|---|---|
| `IJwtService` / `JwtService` | `src/Chthonic.Identity/Auth/JwtService.cs` | JWT issuance + session-token extraction |
| `IOAuthTokenValidator` / `OAuthTokenValidator` | `src/Chthonic.Identity/Auth/OAuthTokenValidator.cs` | Google / Microsoft / Apple ID-token validation |
| `ISessionAuditService` / `SessionAuditService` | `src/Chthonic.Identity/Auth/{ISessionAuditService,SessionAuditService}.cs` | Login/logout/impersonation audit log |
| `IAccessControlService` / `AccessControlService` | `src/Chthonic.Identity/Users/AccessControlService.cs` | Admin/sysadmin authorisation rules |
| `IPermissionHelper` / `PermissionHelper` | `src/Chthonic.Identity/Helpers/PermissionHelper.cs` | RBAC permission + role checks |
| `IAppCheckService` / `AppCheckService` | `src/Chthonic.Identity/Auth/AppCheckService.cs` | Firebase App Check verification (mobile) |
| `AuthHelper.CreateLoginResponse(...)` | `src/Chthonic.Identity/Auth/AuthHelper.cs` | Pure response builder (tier/feature/system-info passed in) |
| `MapAuthEndpoints` | `src/Chthonic.Identity/Auth/AuthEndpoints.cs` | `/api/auth/{login,oauth,oauth/exchange,apple/callback,reset-password,me,logout,sessions,invite,invites}` |
| `MapKeyAuthEndpoints` | `src/Chthonic.Identity/Auth/KeyAuthEndpoints.cs` | `/api/auth/key/{challenge,verify}` for CLI |
| `MapVerificationEndpoints` | `src/Chthonic.Identity/Auth/VerificationEndpoints.cs` | Email/mobile OTP send/verify |
| `MapUserEndpoints` | (split file) | `/api/users/*` CRUD |
| `services.AddChthonicIdentity(config)` | `src/Chthonic.Identity/ServiceCollectionExtensions.cs` | DI entry point |

**Domain entities** (12): `User`, `UserRole`, `UserVerification`, `UserSession`, `UserInvite`, `UserPublicKey`, `UserFavoriteSystem`, `Role`, `Permission`, `RolePermission`, `KeyChallenge`, `SessionAuditLog`. All EF-mapped via `IEntityTypeConfiguration<T>` in `Configuration/`.

**Ports (cross-library bridges):** `IJwtIssuerOptions`, `ISystemFeatureSnapshot`, `ITierResolver`, `ICustomerLinkingPort`, `INotificationPort`. Consumer registers an adapter for each before `AddChthonicIdentity`. See [`extension-points.md`](extension-points.md).

### npm

**Package:** `@chthonicsystems/identity` (npm, v0.1.4)

| Export | File | Role |
|---|---|---|
| `<AuthProvider>` | `npm/src/AuthContext.tsx` | React provider wiring `useAuth` |
| `useAuth()` | `npm/src/AuthContext.tsx` | Returns `{ user, login, logout, oauthLogin, refresh, ... }` |
| Types | `npm/src/types.ts` | `User`, `LoginResponse`, `OAuthProvider`, etc. |

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/locale` | Format helpers used in error messages |
| `@chthonic/tenant` (port `ISystemFeatureSnapshot` + `ITierResolver`) | Feature flag + tier reads at login |
| `@chthonic/audit` (port `INotificationPort` indirectly via consumer) | Login audit writes |
| `@chthonic/parties` (port `ICustomerLinkingPort`) | Customer-user linkage on customer-auth registration |
| `Microsoft.IdentityModel.Tokens`, `System.IdentityModel.Tokens.Jwt` | JWT |
| `Google.Apis.Auth` | Google ID-token validation |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | Bearer middleware |
| `BCrypt.Net-Next` | Password hashing |

## Extension points

Five **ports** the consumer registers an adapter for before `AddChthonicIdentity`:

| Port | What it bridges | Where the adapter lives in TT |
|---|---|---|
| `IJwtIssuerOptions` | Per-product issuer / audience / signing key | TT-side `JwtIssuerOptionsAdapter` |
| `ISystemFeatureSnapshot` | Tenant feature-flag tables (`@chthonic/tenant`) | TT delegates to `IFeatureGateService` |
| `ITierResolver` | Tenant subscription tier (`@chthonic/tenant`) | TT delegates to `ISubscriptionService` |
| `ICustomerLinkingPort` | Customer-user linking (`@chthonic/parties`) | TT delegates to `CustomerLinkingService` |
| `INotificationPort` | Email + push send (consumer's `@chthonic/notifications` integration) | TT delegates to `TTNotificationOrchestrator` |

`AddChthonicIdentity` fails fast at startup if any port is missing, with a helpful "register IXxxPort before AddChthonicIdentity" message.

See [`extension-points.md`](extension-points.md) for adapter shapes + examples.

## Consuming this library

```csharp
// File: api/Program.cs

// 1. Register ports first.
builder.Services.AddSingleton<IJwtIssuerOptions, MyJwtIssuerOptions>();
builder.Services.AddScoped<ISystemFeatureSnapshot, MySystemFeatureSnapshotAdapter>();
builder.Services.AddScoped<ITierResolver, MyTierResolverAdapter>();
builder.Services.AddScoped<ICustomerLinkingPort, MyCustomerLinkingAdapter>();
builder.Services.AddScoped<INotificationPort, MyNotificationAdapter>();

// 2. Register Identity itself.
builder.Services.AddChthonicIdentity(builder.Configuration);

var app = builder.Build();

// 3. Map endpoints.
app.MapAuthEndpoints();
app.MapKeyAuthEndpoints();
app.MapVerificationEndpoints();
app.MapUserEndpoints();
```

**EF migration registration:**

```csharp
// File: api/Data/<Project>DbContext.cs
modelBuilder.ApplyConfigurationsFromAssembly(typeof(IdentityModuleMarker).Assembly);
```

Full walkthrough including OAuth client setup + invite flow + RBAC seed data in [`consumption.md`](consumption.md).

## Related

- [`architecture.md`](architecture.md) — internal structure + 12 entities + endpoint groups.
- [`consumption.md`](consumption.md) — full integration walkthrough.
- [`extension-points.md`](extension-points.md) — five ports + adapter examples.
- [`auth-flow.md`](auth-flow.md) — login + OAuth + invite + reset-password flows.
- [`rbac.md`](rbac.md) — 9 default roles + page/action permissions.
- [`customer-auth.md`](customer-auth.md) — mobile-based customer registration + SMS OTP.
- [`api-keys.md`](api-keys.md) — asymmetric-key CLI auth.
- Library repo: [chthonicsystems/identity](https://github.com/chthonicsystems/identity).
- Governing RFC: [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md).
