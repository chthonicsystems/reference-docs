---
library: templating
version: 0.1.0
related-rfcs: [0020]
last-verified: 2026-05-22
tags: [templating, liquid, fluid]
summary: Fluid wrapper — Liquid syntax, member-access conventions, error handling.
---

# Liquid engine

Built on `Fluid` (Liquid for .NET; Sebastien Ros). Adds platform conventions on top.

## Syntax

Standard Liquid:

```liquid
{{ object.property }}
{% if cond %} ... {% endif %}
{% for item in items %} {{ item.name }} {% endfor %}
{% capture x %} ... {% endcapture %}
```

## Member access conventions

Fluid by default reads C# properties via PascalCase (`{{ invoice.DueDate }}`). The library configures **snake_case fallback** so templates can use idiomatic Liquid (`{{ invoice.due_date }}`) too:

```liquid
{# Both work identically: #}
{{ invoice.DueDate }}
{{ invoice.due_date }}
```

This matters because Liquid is widely written by non-C# authors expecting snake_case (and AI-generated templates default to it).

## Locale filters preloaded

```liquid
{{ invoice.due_date | format_date }}                  # 22/05/2026
{{ invoice.due_date | format_datetime }}               # 22/05/2026 3:45 pm
{{ invoice.total | format_currency }}                  # $1,234.56
{{ labour.hours | format_number: 1 }}                  # 8.5
```

See [`libraries/locale/liquid-filters.md`](../locale/liquid-filters.md).

## Standard tags

Fluid supports standard Liquid + a few extensions: `assign`, `capture`, `case/when`, `cycle`, `for/in/with index`, `if/elsif/else`, `unless`, `include`, `render`, `tablerow`, `comment`, `raw`.

`include` / `render` for partials — the library exposes a `IFileProvider` consumer port so the consumer can supply partial sources.

## Error handling

Fluid is **strict by default** — referencing a non-existent variable throws. Consumers typically configure non-strict mode for templates that may have optional fields:

```csharp
options.MemberAccessStrategy = new UnsafeMemberAccessStrategy();   // default in factory
```

Errors during render bubble as `LiquidException`. `ITemplateRenderer.RenderAsync` catches + returns `RenderResult` with `Success`, `Output`, `Error`.

## Async

Filters can be async (return `ValueTask<FluidValue>`). The four locale filters are all sync (no I/O); custom filters that need DB access can return `ValueTask` and await.

## Caching

Fluid caches parsed templates internally. `LiquidTemplateRenderer` adds a string-source cache keyed by hash (so re-rendering the same template doesn't reparse). Cache is per-`TemplateOptions` instance.

## Related

- [`libraries/locale/liquid-filters.md`](../locale/liquid-filters.md) — the four format filters.
- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [Fluid docs](https://github.com/sebastienros/fluid) (external).
