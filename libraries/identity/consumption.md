---
library: identity
version: 0.1.4
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [identity, consumption]
summary: Code-level integration walkthrough for @chthonic/identity.
---

# Consuming `@chthonic/identity`

## 1. Add package references

```xml
<!-- api/<Project>.Api.csproj -->
<PackageReference Include="Chthonic.Identity" Version="0.1.4" />
```

```json
// web/package.json
"@chthonicsystems/identity": "0.1.4"
```

## 2. Implement the five ports

```csharp
// File: api/Adapters/JwtIssuerOptionsAdapter.cs
public class JwtIssuerOptionsAdapter : IJwtIssuerOptions
{
    public string Issuer => "torquetech.chthonicsystems.com";
    public string Audience => "torquetech-app";
    public string SigningKey => Environment.GetEnvironmentVariable("JWT_SECRET")!;
    public TimeSpan Expiry => TimeSpan.FromDays(30);
}

// File: api/Adapters/SystemFeatureSnapshotAdapter.cs
public class SystemFeatureSnapshotAdapter : ISystemFeatureSnapshot
{
    private readonly IFeatureGateService _features;   // from @chthonic/tenant
    public SystemFeatureSnapshotAdapter(IFeatureGateService features) => _features = features;
    public Task<Dictionary<string, bool>> GetEnabledFeaturesAsync(int systemId)
        => _features.GetSnapshotAsync(systemId);
}

// File: api/Adapters/TierResolverAdapter.cs
public class TierResolverAdapter : ITierResolver
{
    private readonly ISubscriptionService _subs;     // from @chthonic/tenant
    public TierResolverAdapter(ISubscriptionService subs) => _subs = subs;
    public async Task<string> GetTierAsync(int systemId)
    {
        var pkg = await _subs.GetPackageAsync(systemId);
        return pkg?.Tier ?? "Free";
    }
}

// File: api/Adapters/CustomerLinkingAdapter.cs
public class CustomerLinkingAdapter : ICustomerLinkingPort
{
    private readonly ICustomerLinkingService _linking;  // from @chthonic/parties
    public CustomerLinkingAdapter(ICustomerLinkingService linking) => _linking = linking;
    public Task<int?> LinkUserToCustomerAsync(int userId, string mobile, int systemId)
        => _linking.LinkAsync(userId, mobile, systemId);
}

// File: api/Adapters/NotificationAdapter.cs
public class NotificationAdapter : INotificationPort
{
    private readonly ITTNotificationOrchestrator _notify;
    public NotificationAdapter(ITTNotificationOrchestrator notify) => _notify = notify;

    public Task SendInviteEmailAsync(string email, string inviteUrl)
        => _notify.SendUserInviteEmailAsync(email, inviteUrl);

    public Task SendVerificationCodeAsync(string mobile, string code)
        => _notify.SendVerificationSmsAsync(mobile, code);

    public Task SendPasswordResetEmailAsync(string email, string resetUrl)
        => _notify.SendPasswordResetEmailAsync(email, resetUrl);
}
```

## 3. Register DI

```csharp
// File: api/Program.cs
using Chthonic.Identity;

builder.Services.AddSingleton<IJwtIssuerOptions, JwtIssuerOptionsAdapter>();
builder.Services.AddScoped<ISystemFeatureSnapshot, SystemFeatureSnapshotAdapter>();
builder.Services.AddScoped<ITierResolver, TierResolverAdapter>();
builder.Services.AddScoped<ICustomerLinkingPort, CustomerLinkingAdapter>();
builder.Services.AddScoped<INotificationPort, NotificationAdapter>();

// AddChthonicIdentity validates ports + registers 6 services + JWT bearer middleware.
builder.Services.AddChthonicIdentity(builder.Configuration);
```

## 4. Map endpoints

```csharp
// File: api/Program.cs
var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapAuthEndpoints();
app.MapKeyAuthEndpoints();
app.MapVerificationEndpoints();
app.MapUserEndpoints();
```

## 5. Register EF configurations

```csharp
// File: api/Data/<Project>DbContext.cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    base.OnModelCreating(modelBuilder);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(IdentityModuleMarker).Assembly);
    // ... other libraries
}
```

## 6. OAuth client setup

| Provider | Setup |
|---|---|
| Google | Cloud Console → OAuth 2.0 Client ID (Web) → Client ID → set `GOOGLE_CLIENT_ID` env |
| Microsoft | Azure Portal → App registrations → SPA redirect URI → set `MICROSOFT_CLIENT_ID` env |
| Apple | Apple Developer → Services ID → set `APPLE_CLIENT_ID` env |

The library reads these at startup; missing env values disable that provider.

## 7. RBAC seed

The library ships **only** the `Permission` and `Role` entities + EF configs. Seeding the 9 default roles + their permission grants is the consumer's responsibility (typically a `DatabaseSeeder` class run at app startup):

```csharp
// File: api/Data/DatabaseSeeder.cs
public async Task SeedAsync()
{
    await SeedPermissionsAsync();   // ~30 page+action permissions
    await SeedRolesAsync();          // 9 default roles
    await SeedRolePermissionsAsync(); // role × permission grants
    await SeedSystemAdminAsync();    // sysadmin@... user
}
```

See [`rbac.md`](rbac.md) for the canonical seed list.

## 8. Frontend — wrap app in `<AuthProvider>`

```tsx
// File: web/src/App.tsx
import { AuthProvider } from '@chthonicsystems/identity';

<AuthProvider apiBaseUrl="/api">
  <LocaleProvider options={...}>
    {/* rest of app */}
  </LocaleProvider>
</AuthProvider>
```

## 9. Frontend — use `useAuth()`

```tsx
// File: web/src/pages/LoginPage.tsx
import { useAuth } from '@chthonicsystems/identity';

const { login, oauthLogin } = useAuth();

await login(username, password);
await oauthLogin('google', idToken);
```

## 10. Verification

After integration:

- [ ] `POST /api/auth/login` issues a JWT.
- [ ] `GET /api/auth/me` returns the user profile.
- [ ] OAuth flow creates the user on first call, links on subsequent.
- [ ] CLI key auth works end-to-end (`/api/auth/key/challenge` + `/key/verify`).
- [ ] Customer auth registration sends an SMS via `INotificationPort`.
- [ ] `session_audit_log` rows appear on every login/logout.
- [ ] Permission decorators block access correctly (`[RequiresPermission("page:users")]`).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`auth-flow.md`](auth-flow.md), [`rbac.md`](rbac.md), [`customer-auth.md`](customer-auth.md), [`api-keys.md`](api-keys.md).
- [`platform/library-consumption.md`](../../platform/library-consumption.md) — NuGet/npm auth.
