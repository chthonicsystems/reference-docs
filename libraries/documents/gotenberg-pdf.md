---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, pdf, gotenberg]
summary: GotenbergPdfRenderer — HTML → PDF via Gotenberg sidecar.
---

# Gotenberg PDF rendering

[Gotenberg](https://gotenberg.dev/) is an Apache-2.0 sidecar that wraps Chromium for HTML → PDF conversion. The library POSTs rendered HTML; Gotenberg returns a PDF stream.

## Sidecar deployment

```yaml
# docker-compose.yml
gotenberg:
  image: gotenberg/gotenberg:8
  ports: ["3000:3000"]
  environment:
    - DEFAULT_WAIT_DELAY=1s
```

Set `PDF__GotenbergUrl=http://gotenberg:3000` in the consumer.

## Render call

```csharp
public class GotenbergPdfRenderer : IPdfRenderer
{
    public async Task<byte[]> RenderAsync(string html)
    {
        var formData = new MultipartFormDataContent();
        formData.Add(new StringContent(html), "files", "index.html");
        formData.Add(new StringContent("A4"), "paperWidth");   // 8.27in
        formData.Add(new StringContent("A4"), "paperHeight");  // 11.69in
        formData.Add(new StringContent("0.79"), "marginTop");  // 20mm

        var response = await _http.PostAsync("/forms/chromium/convert/html", formData);
        return await response.Content.ReadAsByteArrayAsync();
    }
}
```

## Default page settings

A4 portrait, 20mm margins. Per-document override via Gotenberg form fields.

## Performance

~1-2s per single-page PDF. Concurrent rendering scales with Gotenberg replicas. For high-volume (e.g. monthly invoice generation), run multiple Gotenberg containers behind a load balancer.

## Related

- [`liquid-pipeline.md`](liquid-pipeline.md), [`four-themes.md`](four-themes.md).
