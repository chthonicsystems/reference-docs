---
library: payments
version: 0.1.0
related-rfcs: [0005]
last-verified: 2026-05-22
tags: [payments, money, value-type]
summary: Money value type — currency + minor-unit amount with arithmetic + equality.
---

# Money value type

`Money` is a `readonly record struct` carrying ISO-4217 currency + amount in the smallest currency unit.

## Definition

```csharp
public readonly record struct Money(string Currency, long AmountMinor)
{
    public static Money FromMajor(string currency, decimal major)
        => new(currency, ToMinor(currency, major));

    public decimal ToMajor() => FromMinor(Currency, AmountMinor);

    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot add {Currency} to {other.Currency}");
        return this with { AmountMinor = AmountMinor + other.AmountMinor };
    }

    public Money Subtract(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot subtract {Currency} from {other.Currency}");
        return this with { AmountMinor = AmountMinor - other.AmountMinor };
    }

    public Money Multiply(int scalar)
        => this with { AmountMinor = AmountMinor * scalar };

    public override string ToString() => $"{ToMajor():F2} {Currency}";
}
```

## Minor units

Most currencies use 2 decimals (USD, EUR, AUD, GBP, ...): `$12.34` = `Money("USD", 1234)`.

**Zero-decimal currencies** (JPY, KRW, VND, etc.): `¥1234` = `Money("JPY", 1234)`. The `FromMajor` / `ToMajor` helpers respect ISO-4217 minor-unit-count.

```csharp
private static long ToMinor(string currency, decimal major) => currency.ToUpperInvariant() switch
{
    "JPY" or "KRW" or "VND" or "CLP" => (long)Math.Round(major, MidpointRounding.AwayFromZero),
    _ => (long)Math.Round(major * 100m, MidpointRounding.AwayFromZero),
};
```

## Why minor units

Floating-point arithmetic is unsafe for money. Storing as `long AmountMinor` makes:
- Equality byte-exact.
- Arithmetic associative + commutative.
- DB storage trivial (`bigint` column, no precision concerns).

## Examples

```csharp
var a = Money.FromMajor("USD", 12.34m);     // (USD, 1234)
var b = Money.FromMajor("USD", 1.00m);      // (USD, 100)
var c = a.Add(b);                           // (USD, 1334)
var d = a.Multiply(3);                      // (USD, 3702)

// Cross-currency throws
var e = Money.FromMajor("EUR", 5);
a.Add(e);                                   // throws InvalidOperationException

// Display
c.ToString();                                // "13.34 USD"
// For locale-aware rendering, hand off to @chthonic/locale:
FormatHelper.FormatCurrency(c.ToMajor(), c.Currency, numberFormat);   // "$13.34"
```

## Negative amounts

Allowed. Refunds + adjustments often carry negative `AmountMinor`. Display via `@chthonic/locale.FormatCurrency` uses minus prefix (`-$12.34`), not parentheses.

## Equality

Records auto-generate value-equality. `new Money("USD", 1234) == new Money("USD", 1234)` is true. Currency comparison is **case-sensitive** at the struct level (`new Money("USD", 100) != new Money("usd", 100)`); consumers should normalise to upper-case before constructing.

## Tests

`MoneyTests`:

- `FromMajor` round-trip for 2-decimal and 0-decimal currencies.
- `Add` / `Subtract` arithmetic.
- Cross-currency `Add` throws.
- `Multiply` scalar.
- Negative amounts.
- Equality.

## Related

- [`provider-abstraction.md`](provider-abstraction.md) — `IPaymentProvider` accepts `Money` everywhere.
- [`libraries/locale/`](../locale/) — `FormatCurrency` for human-readable display.
