---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/support`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.Support" Version="0.1.0" />
<PackageReference Include="Chthonic.Support.GitHub" Version="0.1.0" />   <!-- optional -->
```

## 2. Configure GitHub (optional)

```bash
GITHUB_SUPPORT_TOKEN=ghp_...
GITHUB_SUPPORT_DEFAULT_REPO=chthonicsystems/torquetech
```

The token must have `issues: write` scope on the target repos.

## 3. Register DI

```csharp
using Chthonic.Support;
using Chthonic.Support.GitHub;

builder.Services.AddChthonicSupport();
builder.Services.AddGitHubIssueTracker(builder.Configuration);
app.MapSupportEndpoints();
```

## 4. Seed CTI routing

```sql
INSERT INTO cti_routing (category, type, item, resolver_group, external_provider, external_repo)
VALUES
  ('Bug', 'API', 'login fails', 'platform-team', 'github', 'chthonicsystems/identity'),
  ('Bug', 'UI', 'page doesnt load', 'frontend-team', 'github', 'chthonicsystems/torquetech'),
  ('Account', 'Billing', 'tier downgrade', 'finance-team', null, null);
```

## 5. Frontend

```tsx
import { SupportTicketsList, CreateSupportRequest } from '@chthonicsystems/support';
<CreateSupportRequest systemId={systemId} userId={userId} />
<SupportTicketsList userId={userId} />
```

## Related

- [`ticketing.md`](ticketing.md), [`cti-routing.md`](cti-routing.md), [`github-sync.md`](github-sync.md).
