---
library: templating
version: 0.1.0
related-rfcs: [0020]
last-verified: 2026-05-22
tags: [templating, iframe, isolation, security]
summary: <IsolatedTemplatePreview> — iframe-isolated rendering for browser-side previews.
---

# Iframe isolation

`<IsolatedTemplatePreview>` renders templated HTML inside a sandboxed `<iframe>` — CSS isolation from the parent app + XSS containment + scrollable preview without polluting the host layout.

## Why iframes

Templates render arbitrary HTML/CSS. If rendered directly into the parent React tree:

- CSS from the template can leak into the parent (unscoped class names, body styles).
- `<script>` tags execute with parent's origin.
- Liquid-rendered content may be user / AI generated; injecting it directly is XSS.

Iframes isolate all three concerns at the cost of one extra DOM frame per preview.

## Component

```tsx
interface IsolatedTemplatePreviewProps {
  html: string;
  sandbox?: string;     // default: "allow-same-origin" — strictest practical
  onLoad?: () => void;
}

export function IsolatedTemplatePreview({ html, sandbox = "allow-same-origin", onLoad }: Props) {
  const ref = useRef<HTMLIFrameElement>(null);
  useEffect(() => {
    if (!ref.current) return;
    const doc = ref.current.contentDocument!;
    doc.open();
    doc.write(html);
    doc.close();
    onLoad?.();
  }, [html]);
  return <iframe ref={ref} sandbox={sandbox} />;
}
```

## Sandbox values

| Sandbox | Use |
|---|---|
| `"allow-same-origin"` (default) | Read parent localStorage / cookies. Use for trusted templates. |
| `""` (empty string = full sandbox) | Most isolated — no scripts, no same-origin, no forms. Use for AI-generated previews. |
| `"allow-same-origin allow-scripts"` | Allow inline `<script>`. Rare; only for trusted templated app content. |

## Use cases

| Consumer | Sandbox |
|---|---|
| Document Designer preview (admin-trusted) | `"allow-same-origin"` |
| Public listing preview (admin-trusted but user-facing) | `"allow-same-origin"` |
| AI-generated template preview (Claude output) | `""` (full sandbox) |

## Sizing

Iframe height defaults to `100%` of its container. Consumer wraps in a flex/grid container with explicit height. Auto-resize-to-content is **not** built in (postMessage from inside iframe required); add per-consumer if needed.

## Related

- [`ai-output-sanitization.md`](ai-output-sanitization.md) — additional layer for AI output.
- [`architecture.md`](architecture.md).
