---
library: identity
version: 0.1.4
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [identity, rbac, roles, permissions]
summary: 9 default roles + page/action permission types + DatabaseSeeder pattern.
---

# RBAC

Identity ships the `Role`, `Permission`, `RolePermission` schema. Seeding the actual roles + permissions is the **consumer's responsibility** via a `DatabaseSeeder` class run at app startup.

## Default 9 roles

| Role | Description |
|---|---|
| `sysadmin` | System Administrator — full access; impersonation; every page; every action |
| `admin` | Administrator — management access (all except user management on some flows) |
| `director` | Executive — read access + reports |
| `mechanic` | Service ops — jobs, vehicles, customers |
| `accountant` | Financial — reports, jobs, customers |
| `supervisor` | Team management — pages and operations |
| `reportviewer` | Reports only |
| `customer` | Customer — view own jobs only |
| `staff` | Front-of-house — bookings + scheduling |

These are the **defaults**. Consumers can add product-specific roles via `Role.SystemId` (a non-null `system_id` scopes a role to one tenant) and re-seed with their own RBAC.

## Two permission types

| Type | Purpose | Format |
|---|---|---|
| `page` | Access a route / surface | entity name lowercase (e.g. `dashboard`, `users`, `customers`, `vehicles`, `jobs`, `reports`) |
| `action` | Execute a verb on an entity | `verb-noun` lowercase (e.g. `create-user`, `edit-user`, `delete-user`, `view-report`) |

Permissions are referenced everywhere as `<type>:<name>` strings: `page:users`, `action:edit-job`, `action:view-report`.

## Default page permissions

```
page:dashboard
page:users
page:customers
page:vehicles
page:jobs
page:reports
page:bookings
page:invoices
page:estimates
page:views
page:systems          # sysadmin only
```

## Default action permissions

```
action:create-user, action:edit-user, action:delete-user
action:create-customer, action:edit-customer, action:delete-customer
action:create-vehicle, action:edit-vehicle, action:delete-vehicle
action:create-job, action:edit-job, action:delete-job, action:complete-job
action:view-report
action:edit-system-settings
action:create-system, action:edit-system, action:delete-system   # sysadmin
action:manage-inventory     # services + products + variants
```

## Role × permission grants (canonical)

| Role | Page perms | Action perms |
|---|---|---|
| `sysadmin` | all | all |
| `admin` | all except `page:systems` | all except `action:create/edit/delete-system` |
| `director` | dashboard, customers, vehicles, jobs, reports | view-report |
| `mechanic` | dashboard, customers, vehicles, jobs | edit-job, complete-job |
| `accountant` | dashboard, customers, vehicles, jobs, reports | view-report |
| `supervisor` | dashboard, users, customers, vehicles, jobs, reports, bookings | (most action perms except delete-*) |
| `reportviewer` | reports | view-report |
| `customer` | (none — direct entity scoping by user_id) | (none) |
| `staff` | bookings, customers, vehicles, jobs, reports | edit-customer, edit-vehicle |

## DatabaseSeeder pattern

```csharp
// File: api/Data/DatabaseSeeder.cs (CONSUMER OWNS THIS)

public class DatabaseSeeder
{
    private readonly TorqueTechDbContext _db;
    public DatabaseSeeder(TorqueTechDbContext db) => _db = db;

    public async Task SeedAsync()
    {
        await SeedPermissionsAsync();
        await SeedRolesAsync();
        await SeedRolePermissionsAsync();
    }

    private async Task SeedPermissionsAsync()
    {
        var perms = new[]
        {
            new Permission { Name = "dashboard", Type = "page", Description = "Access dashboard" },
            new Permission { Name = "users", Type = "page", Description = "Access users" },
            // ... 30+ more
        };
        foreach (var p in perms)
        {
            if (!await _db.Permissions.AnyAsync(x => x.Name == p.Name && x.Type == p.Type))
                _db.Permissions.Add(p);
        }
        await _db.SaveChangesAsync();
    }

    // SeedRolesAsync, SeedRolePermissionsAsync similar shape
}
```

**Rule:** all role + permission seeding lives in `DatabaseSeeder`. Never via direct SQL or ad-hoc setup. New permission = add to seeder + run a migration that re-runs seed (`dotnet ef migrations add Add<Name>Permission`).

## Permission checks

### Endpoint level

```csharp
// File: api/Features/Users/UserEndpoints.cs (consumer side)
app.MapGet("/api/users", [RequiresPermission("page:users")] async (...) =>
{
    // ...
});

app.MapPost("/api/users", [RequiresPermission("action:create-user")] async (...) =>
{
    // ...
});
```

`RequiresPermission` is provided by the consumer (an `IAuthorizationRequirement` + handler). Identity ships `IPermissionHelper.HasPermissionAsync(user, "page:users")` for direct programmatic checks.

### Service level

```csharp
public class JobService(IPermissionHelper perms, ICurrentUser current)
{
    public async Task<Job> EditAsync(Job edits)
    {
        if (!await perms.HasPermissionAsync(current.UserId, "action:edit-job"))
            throw new ForbiddenException("Missing action:edit-job");
        // ...
    }
}
```

### Frontend

```tsx
const { user } = useAuth();
const canEdit = user?.permissions.includes('action:edit-job');
```

The `permissions` array in the login response (populated by `AuthHelper.CreateLoginResponse`) is the union of all permission names across the user's roles, prefixed by type.

## Status-specific permissions

Some action permissions only apply to certain entity statuses. E.g. `action:complete-job` only relevant for `Job.Status = InProgress`. Status-specific gating happens in the service layer:

```csharp
if (job.Status != JobStatus.InProgress)
    throw new InvalidOperationException("Can only complete jobs that are in progress");
if (!await perms.HasPermissionAsync(current.UserId, "action:complete-job"))
    throw new ForbiddenException("Missing action:complete-job");
```

The library does not enforce status × permission combinations; that's domain logic in `@chthonic/work` (or the consumer).

## System-scoped roles

`Role.SystemId` is nullable. NULL = global default role (sysadmin / admin / etc.). Non-null = product-or-tenant-specific role.

Adding a tenant-specific role:

```csharp
_db.Roles.Add(new Role
{
    Name = "Senior Mechanic",
    SystemId = systemId,        // ← scoped
    Description = "Like mechanic but can edit historical jobs",
});
await _db.SaveChangesAsync();
// Then assign permissions via RolePermission entries
```

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`auth-flow.md`](auth-flow.md) — JWT carries user roles + permissions.
- [`customer-auth.md`](customer-auth.md) — customer role auto-assigned on registration.
- [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md) § RBAC.
