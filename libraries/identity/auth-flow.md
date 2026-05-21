---
library: identity
version: 0.1.4
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [identity, auth, jwt, oauth]
summary: Login + OAuth + invite + reset-password flows for staff users.
---

# Auth flow

Staff (admin / mechanic / accountant / etc.) authentication flows. Customer auth lives in [`customer-auth.md`](customer-auth.md).

## Username / password login

```
POST /api/auth/login
{
  "username": "devadmin",
  "password": "..."
}
```

→

```
200 OK
{
  "token": "eyJhbGc...",
  "user": {
    "id": 1,
    "username": "devadmin",
    "email": "...",
    "roles": ["admin"],
    "permissions": ["page:users", "action:create-user", ...],
    "systemId": 1,
    "system": { "id": 1, "name": "...", "tier": "Standard", "features": {...}, ... }
  }
}
```

Implementation: `AuthEndpoints.cs` → `JwtService.IssueAsync(...)` + `AuthHelper.CreateLoginResponse(...)` (which calls `ITierResolver.GetTierAsync` + `ISystemFeatureSnapshot.GetEnabledFeaturesAsync` via the registered ports).

`session_audit_log` row written via `ISessionAuditService.RecordAsync(SessionAction.Login, ...)`.

## OAuth login (Google / Microsoft / Apple)

```
POST /api/auth/oauth
{
  "provider": "google" | "microsoft" | "apple",
  "idToken": "...",
  "inviteToken": "...",     // optional — completes invite signup
  "firstName": "...",       // optional — Apple sends only on first auth
  "lastName": "..."         // optional — Apple sends only on first auth
}
```

`OAuthTokenValidator` validates the ID token against the provider's JWKS, extracts the email + provider-sub. If a matching user exists → log them in. If `inviteToken` is provided → complete the invite + create the user. Otherwise → 401.

Apple-only quirk: Apple sends `firstName` / `lastName` **only on the first authorization**; the frontend persists what it received and forwards on every subsequent call so the backend can populate the user record.

## OAuth code-exchange (web)

```
POST /api/auth/oauth/exchange
```

Server-side authorization-code flow for OAuth providers that don't use ID-tokens directly. Currently Apple-only. Frontend submits the authorization code; server exchanges with Apple for ID token + verifies + logs in.

Apple's redirect-based flow lands at `POST /api/auth/apple/callback` with form-encoded fields. The handler converts to JSON + delegates to the same login machinery.

## Invite acceptance

Step 1 — admin creates the invite:

```
POST /api/auth/invite
Authorization: Bearer <admin token>
{ "email": "newuser@...", "roleId": 4 }
```

Generates a UUID token, writes a `user_invite` row, sends an email via `INotificationPort.SendInviteEmailAsync(email, inviteUrl)`. Email contains a link to `https://<host>/register?token=<uuid>`.

Step 2 — invitee opens the link:

```
GET /api/auth/invite?token=<uuid>
```

Returns invite metadata (email, role, system) — used by the frontend to render the registration form.

Step 3 — invitee submits the form:

```
POST /api/auth/login        # username/password completion
or
POST /api/auth/oauth        # OAuth completion (with inviteToken)
```

The `inviteToken` is consumed (deleted) on successful registration. Subsequent uses → 410 Gone.

Step 4 — admin can revoke:

```
DELETE /api/auth/invite/{inviteId}
Authorization: Bearer <admin token>
```

## Password reset

```
POST /api/auth/reset-password
{ "email": "user@..." }
```

→ writes a reset token to `user_verification` (type='password_reset') + sends `INotificationPort.SendPasswordResetEmailAsync(email, resetUrl)`.

```
POST /api/auth/reset-password
{ "token": "<uuid>", "password": "newpw" }
```

→ verifies token + writes new password hash + invalidates token.

## Logout

```
POST /api/auth/logout
Authorization: Bearer <token>
```

`UserSession` row's `ended_at` set; `session_audit_log` row written via `SessionAction.Logout`. JWT itself is stateless — clients are expected to discard it client-side.

## Sessions

```
GET /api/auth/sessions
Authorization: Bearer <token>
```

Returns the current user's `user_session` history. Used by the Profile page's "active sessions" view.

## Frontend hook

```ts
const { user, login, oauthLogin, refresh, logout } = useAuth();
```

`useAuth().login(username, password)` calls `POST /api/auth/login`, persists the token to localStorage, sets the `Authorization: Bearer <token>` header on `httpService` for subsequent calls, and stores `user` in context.

## JWT contents

```json
{
  "sub": "1",                    // user_id
  "system_id": "1",
  "username": "devadmin",
  "roles": "admin,supervisor",
  "iat": 1716340000,
  "exp": 1718932000,
  "iss": "torquetech.chthonicsystems.com",
  "aud": "torquetech-app"
}
```

Issued by `JwtService.IssueAsync(...)` using `IJwtIssuerOptions.SigningKey` (HMAC-SHA256). Bearer middleware validates issuer, audience, signature, expiry on every request.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`rbac.md`](rbac.md) — what permissions ride in the JWT.
- [`customer-auth.md`](customer-auth.md) — separate flow for customer users.
- [`api-keys.md`](api-keys.md) — CLI key auth.
