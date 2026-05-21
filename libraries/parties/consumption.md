---
library: parties
version: 0.2.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [parties, consumption]
summary: Code-level integration walkthrough for @chthonic/parties.
---

# Consuming `@chthonic/parties`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Parties" Version="0.2.0" />
```

```json
"@chthonicsystems/parties": "0.2.0"
```

## 2. Register DI

```csharp
// File: api/Program.cs
using Chthonic.Parties;

builder.Services.AddChthonicParties();

// Register the adapter for @chthonic/identity's ICustomerLinkingPort.
builder.Services.AddScoped<ICustomerLinkingPort, PartiesCustomerLinkingAdapter>();

var app = builder.Build();
app.MapCustomerEndpoints();
```

## 3. Register EF configurations

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(PartiesModuleMarker).Assembly);
```

## 4. Frontend — search + create-inline

```tsx
// File: web/src/pages/CreateJobPage.tsx
import { CustomerSearchSelect } from '@chthonicsystems/parties';

const [customerId, setCustomerId] = useState<number | null>(null);

<CustomerSearchSelect
  systemId={systemId}
  value={customerId}
  onSelect={(c) => setCustomerId(c.id)}
  allowCreate
  onCreate={(input) => api.post('/customers', input)}
/>
```

`<CustomerSearchSelect>` debounces typeahead, calls `GET /api/customers/search?q=...`, renders results with name + mobile, and offers an "Add new customer" inline create flow.

## 5. Use `useCustomers` hook for listing pages

```tsx
import { useCustomers } from '@chthonicsystems/parties';

function CustomersPage() {
  const { data, total, page, setPage, search, setSearch, loading } = useCustomers({
    systemId,
    pageSize: 20,
  });
  return (
    <article>
      <SearchInput value={search} onChange={setSearch} />
      {loading ? <Spinner /> : data.map(c => <CustomerRow key={c.id} customer={c} />)}
      <Pagination page={page} total={total} onChange={setPage} />
    </article>
  );
}
```

## 6. Customer ↔ asset linking

The polymorphic FK `customer_asset.asset_id` references `@chthonic/assets`'s `Asset` base. Each consumer product casts to its subtype:

```csharp
// TT
var assets = await _db.CustomerAssets
    .Include(ca => ca.Asset)
    .Where(ca => ca.CustomerId == customerId)
    .ToListAsync();
var vehicles = assets.Select(ca => (Vehicle)ca.Asset).ToList();
```

```csharp
// MarineDeck
var vessels = assets.Select(ca => (Vessel)ca.Asset).ToList();
```

## 7. Customer-user linking

The `ICustomerLinkingPort` registered in step 2 connects the dots. When a customer registers via `POST /api/customer-auth/register` (identity-owned endpoint):

1. Identity calls `ICustomerLinkingPort.LinkUserToCustomerAsync(userId, mobile, systemId)`.
2. The parties adapter looks up `customer_asset` where `mobile = ...` (within `system_id`).
3. If a match → set `customer.user_id = userId`. If no match → returns null.

If no match at registration time, a customer record exists without a linked user. When staff later creates the matching customer record, the adapter auto-links by the same mobile.

## 8. Audit

`CustomerService.CreateAsync` / `.UpdateAsync` / `.SoftDeleteAsync` write `audit_log` rows via the consumer's `IAuditLogger` (from `@chthonic/audit`). The service expects `IAuditLogger` to be registered.

## 9. Verification

- [ ] `GET /api/customers?q=...` returns paginated matches.
- [ ] `POST /api/customers` creates + audit row written.
- [ ] `<CustomerSearchSelect>` debounces correctly.
- [ ] Customer registration via identity links to existing customer if mobile matches.
- [ ] `customer_asset` join works across asset subtypes.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`customers.md`](customers.md), [`addresses.md`](addresses.md), [`mobile-verification.md`](mobile-verification.md).
- [`libraries/identity/customer-auth.md`](../identity/customer-auth.md).
