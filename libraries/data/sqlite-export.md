---
library: data
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [data, sqlite, machine-readable]
summary: SQLite export — schema, ISO-only date columns, Microsoft.Data.Sqlite writer.
---

# SQLite export

The export is a single SQLite file per request. Machine-readable; ISO-8601 dates; raw decimal numbers.

## Why SQLite

- Single file, portable.
- Universal tooling (`sqlite3` CLI, DB Browser, every language has a binding).
- Joins + queries possible without unzipping CSVs.
- ~10x compression vs raw CSV when the data has repeated text (customer names, etc.).

## Format conventions

- **Dates**: ISO-8601 strings (`2026-05-22T03:45:00Z`). NOT localised — the export is for machines, not humans.
- **Numbers**: Raw decimal (`12.34`, not `$12.34`). Currency code in a sibling column.
- **NULLs**: SQLite NULL.
- **Booleans**: `0` / `1` (SQLite native bool).

## Embedded README

A `_meta` table carries the export's README:

```
_meta
  key   text PK
  value text

  ('readme', '<!DOCTYPE html>...')
  ('exported_at', '2026-05-22T03:45:00Z')
  ('exported_from', 'TorqueTech v14.2.1')
  ('schema_version', '1')
```

The README explains the table list + how to import to another product.

## Schema versioning

`_meta('schema_version', '1')` will bump when columns are added/removed/renamed. Consumers reading exports check the version + handle migrations.

## Tests

`DataExportBuilderTests` snapshot-tests the schema for regression detection.

## Related

- [`per-tenant-bundling.md`](per-tenant-bundling.md), [`extension-points.md`](extension-points.md).
