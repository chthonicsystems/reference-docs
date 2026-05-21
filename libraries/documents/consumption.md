---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/documents`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.Documents" Version="0.1.0" />
```

```json
"@chthonicsystems/documents": "0.1.0"
```

## 2. Set up Gotenberg sidecar

```yaml
# docker-compose.yml
gotenberg:
  image: gotenberg/gotenberg:8
  ports: ["3000:3000"]
```

```bash
PDF__GotenbergUrl=http://gotenberg:3000
```

## 3. Register DI

```csharp
using Chthonic.Documents;
builder.Services.AddChthonicDocuments(builder.Configuration);
app.MapDocumentTemplateEndpoints();
```

## 4. Render a document

```csharp
public class InvoicePdfService(IDocumentRenderer renderer)
{
    public async Task<byte[]> RenderAsync(int invoiceId)
    {
        var ctx = await _builder.BuildAsync(invoiceId);
        return await renderer.RenderPdfAsync("invoice", ctx);
    }
}
```

## 5. Frontend — Document Designer

```tsx
import { DocumentDesignerShell } from '@chthonicsystems/documents';
<DocumentDesignerShell type="invoice" systemId={systemId} />
```

## Related

- [`liquid-pipeline.md`](liquid-pipeline.md), [`gotenberg-pdf.md`](gotenberg-pdf.md), [`document-designer-shell.md`](document-designer-shell.md).
