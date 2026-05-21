---
library: identity
version: 0.1.4
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [identity, architecture, rbac, schema]
summary: Identity library internal structure — 12 entities, ports, services, endpoint groups.
---

# Architecture

## File layout

```
src/Chthonic.Identity/
├── Auth/
│   ├── AuthEndpoints.cs            # /api/auth/{login,oauth,oauth/exchange,apple/callback,reset-password,me,logout,sessions,invite,invites}
│   ├── KeyAuthEndpoints.cs         # /api/auth/key/{challenge,verify}
│   ├── VerificationEndpoints.cs    # email/mobile OTP send/verify
│   ├── JwtService.cs               # IJwtService + JwtService
│   ├── OAuthTokenValidator.cs      # IOAuthTokenValidator + OAuthTokenValidator (Google/Microsoft/Apple)
│   ├── SessionAuditService.cs      # ISessionAuditService + SessionAuditService
│   ├── AppCheckService.cs          # IAppCheckService + AppCheckService (Firebase)
│   ├── AuthHelper.cs               # CreateLoginResponse(...) pure builder
│   └── LoginResponse.cs            # DTO
├── Users/
│   └── AccessControlService.cs     # IAccessControlService + AccessControlService
├── Helpers/
│   ├── HttpContextExtensions.cs    # ClaimsPrincipal helpers
│   └── PermissionHelper.cs         # IPermissionHelper + PermissionHelper
├── Configuration/                  # IEntityTypeConfiguration<T> for each domain entity
├── Domain/                         # 12 entity classes
├── Ports/                          # 5 cross-library port interfaces
├── Common/ErrorResponse.cs
├── IdentityModuleMarker.cs         # Assembly-scan marker
└── ServiceCollectionExtensions.cs  # AddChthonicIdentity(config)
```

## 12 domain entities

| Entity | File | Role |
|---|---|---|
| `User` | `Domain/User.cs` | Username, password hash, email, mobile, FCM token, system_id |
| `UserRole` | `Domain/UserRole.cs` | (user_id, role_id) join |
| `UserVerification` | `Domain/UserVerification.cs` | Email/mobile OTP records |
| `UserSession` | `Domain/UserSession.cs` | Login/logout audit |
| `UserInvite` | `Domain/UserInvite.cs` | Invite tokens with role assignment + expiry |
| `UserPublicKey` | `Domain/UserPublicKey.cs` | CLI key pairs (PKCS8 PEM) |
| `UserFavoriteSystem` | `Domain/UserFavoriteSystem.cs` | Customer favorite-business links |
| `Role` | `Domain/Role.cs` | Role definition (id, name, description, system_id?) |
| `Permission` | `Domain/Permission.cs` | Permission definition (id, name, type=page\|action) |
| `RolePermission` | `Domain/RolePermission.cs` | (role_id, permission_id) join |
| `KeyChallenge` | `Domain/KeyChallenge.cs` | CLI auth challenge nonces |
| `SessionAuditLog` | `Domain/SessionAuditLog.cs` | Append-only login/logout/impersonation audit |

`SessionAction` enum (`Domain/SessionAction.cs`): `Login`, `Logout`, `ImpersonationStart`, `ImpersonationEnd`, `OAuthLogin`, `KeyAuthLogin`.

## Schema (bare table names)

```
users (user_id, system_id, username, password_hash, email, mobile, ...)
user_role (user_id, role_id)
user_verification (verification_id, user_id, type, code, expires_at, ...)
user_session (session_id, user_id, started_at, ended_at, ...)
user_invite (invite_id, system_id, email, role_id, token, expires_at, ...)
user_public_key (key_id, user_id, name, public_key_pem, fingerprint, ...)
user_favorite_system (user_id, system_id, created_at)
role (role_id, system_id, name, description, ...)
permission (permission_id, name, type, description)
role_permission (role_id, permission_id)
key_challenge (challenge_id, user_id, nonce, expires_at, ...)
session_audit_log (audit_id, user_id, action, system_id, ip, user_agent, created_at)
```

Bare descriptive names per [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § "Migration coexistence". Consumers register the configurations via `ApplyConfigurationsFromAssembly(typeof(IdentityModuleMarker).Assembly)`.

## Ports

```csharp
// File: src/Chthonic.Identity/Ports/IJwtIssuerOptions.cs
public interface IJwtIssuerOptions
{
    string Issuer { get; }
    string Audience { get; }
    string SigningKey { get; }   // base64; min 256 bits
    TimeSpan Expiry { get; }
}

// File: src/Chthonic.Identity/Ports/ISystemFeatureSnapshot.cs
public interface ISystemFeatureSnapshot
{
    Task<Dictionary<string, bool>> GetEnabledFeaturesAsync(int systemId);
}

// File: src/Chthonic.Identity/Ports/ITierResolver.cs
public interface ITierResolver
{
    Task<string> GetTierAsync(int systemId);   // "Free" | "Standard" | "Premium"
}

// File: src/Chthonic.Identity/Ports/ICustomerLinkingPort.cs
public interface ICustomerLinkingPort
{
    Task<int?> LinkUserToCustomerAsync(int userId, string mobile, int systemId);
}

// File: src/Chthonic.Identity/Ports/INotificationPort.cs
public interface INotificationPort
{
    Task SendInviteEmailAsync(string email, string inviteUrl);
    Task SendVerificationCodeAsync(string mobile, string code);
    Task SendPasswordResetEmailAsync(string email, string resetUrl);
}
```

`AddChthonicIdentity` validates all five are registered; throws an `InvalidOperationException` with a list of missing port names if any is missing.

## Endpoint groups

| Group | Routes |
|---|---|
| `MapAuthEndpoints` | `POST /api/auth/login`, `POST /api/auth/oauth`, `POST /api/auth/oauth/exchange`, `POST /api/auth/apple/callback`, `POST /api/auth/reset-password`, `GET /api/auth/me`, `POST /api/auth/logout`, `GET /api/auth/sessions`, `GET/POST /api/auth/invite`, `GET /api/auth/invites`, `DELETE /api/auth/invite/{id}` |
| `MapKeyAuthEndpoints` | `POST /api/auth/key/challenge`, `POST /api/auth/key/verify` |
| `MapVerificationEndpoints` | `POST /api/auth/verify/send`, `POST /api/auth/verify/check`, `POST /api/auth/verify/resend` |
| `MapUserEndpoints` | `GET /api/users`, `POST /api/users`, `GET /api/users/{id}`, `PUT /api/users/{id}`, `DELETE /api/users/{id}`, `GET /api/users/me`, `PUT /api/users/me`, `PUT /api/users/me/password`, `GET /api/users/me/permissions`, `GET /api/users/{id}/activity`, `GET /api/users/stats`, `GET /api/users/search`, `GET /api/users/search/mechanics`, `POST /api/users/me/keys`, `GET /api/users/me/keys`, `DELETE /api/users/me/keys/{id}` |

`ImpersonateUser` and `ForceDeleteUser` are **NOT** mapped by the library — they're product-side endpoints (sysadmin-only). TT exposes them in `api/Features/Impersonation/`.

## Tests

| File | Coverage |
|---|---|
| `JwtServiceTests.cs` | Issuance, claim shape, expiry, signature validation, tampered token rejection |
| `OAuthTokenValidatorTests.cs` | Google ID-token mocked; Microsoft + Apple via JWKS mocks |
| `SessionAuditServiceTests.cs` | Login / logout / impersonation rows; immutability invariants |
| `AccessControlServiceTests.cs` | sysadmin / admin / non-admin matrix |
| `PermissionHelperTests.cs` | RBAC permission + role checks; permission type filtering |
| `AppCheckServiceTests.cs` | Firebase signature validation; expired token rejection |
| `AuthHelperTests.cs` | Login response shape + tier/feature plumbing |
| ... | (~40+ test files total in `Chthonic.Identity.Tests`) |

## Related

- [`index.md`](index.md) — public surface.
- [`consumption.md`](consumption.md) — integration walkthrough.
- [`extension-points.md`](extension-points.md) — five ports.
- [`auth-flow.md`](auth-flow.md) — login + OAuth flows.
- [`rbac.md`](rbac.md) — roles + permissions.
- [`customer-auth.md`](customer-auth.md) — customer registration.
- [`api-keys.md`](api-keys.md) — CLI key auth.
- [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md).
