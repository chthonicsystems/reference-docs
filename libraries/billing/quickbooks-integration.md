---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, quickbooks]
summary: QuickBooks accounting provider — OAuth2, realmId, push-customer + push-invoice.
---

# QuickBooks integration

`Chthonic.Billing.QuickBooks` implements `IAccountingProvider` for QuickBooks Online. OAuth2 + `realmId` + Customer/Invoice push.

## OAuth setup

```bash
QUICKBOOKS_CLIENT_ID=...
QUICKBOOKS_CLIENT_SECRET=...
QUICKBOOKS_REDIRECT_URI=https://<host>/api/accounting/quickbooks/callback
```

Register at https://developer.intuit.com/. Scopes: `com.intuit.quickbooks.accounting`.

## Connect flow

Mirrors Xero — `realmId` (QuickBooks company ID) is captured in the callback, stored in `accounting_connection.organization_id`.

## Push invoice

`QuickBooksAccountingProvider.PushInvoiceAsync(conn, invoice)`:

1. Decrypt + refresh tokens.
2. Match customer to QB Customer (push if missing).
3. `POST /v3/company/{realmId}/invoice` with line items.
4. Store `invoice.metadata['qb_invoice_id']`.
5. Log to `accounting_sync_log`.

## Token TTL

QB access tokens expire in 1 hour; refresh tokens in 100 days. Auto-refresh same pattern as Xero.

## Related

- [`xero-integration.md`](xero-integration.md), [`token-encryption.md`](token-encryption.md).
