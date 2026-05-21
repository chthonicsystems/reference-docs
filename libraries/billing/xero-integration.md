---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, xero]
summary: Xero accounting provider — OAuth2 flow, organisation selection, push-customer + push-invoice.
---

# Xero integration

`Chthonic.Billing.Xero` implements `IAccountingProvider` for Xero. OAuth2 + organisation selection + customer/invoice push.

## OAuth setup

```bash
XERO_CLIENT_ID=...
XERO_CLIENT_SECRET=...
XERO_REDIRECT_URI=https://<host>/api/accounting/xero/callback
```

Register an app at https://developer.xero.com/myapps/. Scopes: `accounting.transactions`, `accounting.contacts`, `accounting.settings`.

## Connect flow

```
1. Admin clicks "Connect Xero" in Integrations section.
2. Frontend → GET /api/accounting/xero/authorize → redirect URL.
3. Admin auths in Xero UI; selects an organisation (Xero "tenant").
4. Xero redirects to /api/accounting/xero/callback?code=...&state=....
5. Server: exchange code → access + refresh tokens; encrypt; persist in
   accounting_connection. Set organization_id from the selected Xero tenant.
6. Periodic sync starts.
```

## Push invoice

`XeroAccountingProvider.PushInvoiceAsync(conn, invoice)`:

1. Decrypt tokens; refresh if access token expired.
2. Look up customer's Xero ContactID — push customer first if missing.
3. `POST /api.xro/2.0/Invoices` with line items.
4. On success, store `invoice.metadata['xero_invoice_id']` for future correlation.
5. Write `accounting_sync_log` row.

Failures (network, rate-limit, validation) write `sync_log` with `status='failed'` + retry on next periodic sync.

## Token refresh

Xero access tokens expire in 30 minutes; refresh tokens in 60 days. The provider auto-refreshes on every call:

```csharp
if (DateTime.UtcNow >= conn.AccessTokenExpiresAt - TimeSpan.FromMinutes(2))
{
    var refreshed = await RefreshAccessTokenAsync(conn);
    UpdateConnection(conn, refreshed);   // re-encrypt + persist
}
```

## Related

- [`quickbooks-integration.md`](quickbooks-integration.md), [`token-encryption.md`](token-encryption.md), [`extension-points.md`](extension-points.md).
