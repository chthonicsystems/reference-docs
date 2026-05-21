---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, extension-points]
summary: Extension points — IS3Helper / IImageProcessor overrides + entity_type strings.
---

# Extension points

| Hook | Use |
|---|---|
| `IS3Helper` override | Non-AWS S3 (Backblaze B2, MinIO, Cloudflare R2) — implement the interface using your provider's SDK |
| `IImageProcessor` override | Different image library (e.g. `Magick.NET` for animated GIFs / WEBP) |
| `entity_type` polymorphic FK strings | Each consumer freely uses any string — `"Job"`, `"Vehicle"`, `"Vessel"`, `"Pet"`, etc. |
| `services.AddChthonicFiles(opts => opts.SignedUrlTtl = TimeSpan.FromHours(2))` | Default signed-URL TTL |
| `opts.MaxImageWidth = 3000` | Max dimension for auto-resized images |
| `opts.ImageQuality = 90` | JPEG/WebP quality 0-100 |

## Override S3 backend

```csharp
public class CloudflareR2Helper : IS3Helper
{
    private readonly AmazonS3Client _r2;   // R2 is S3-compatible; same SDK
    public CloudflareR2Helper(IConfiguration config)
    {
        _r2 = new AmazonS3Client(
            new BasicAWSCredentials(config["R2_ACCESS_KEY"], config["R2_SECRET_KEY"]),
            new AmazonS3Config { ServiceURL = config["R2_ENDPOINT"], ForcePathStyle = true });
    }
    public Task<string> PutAsync(...) { /* delegate to _r2 */ }
    // etc
}

builder.Services.AddSingleton<IS3Helper, CloudflareR2Helper>();
```

## Override image processor

```csharp
public class MagickImageProcessor : IImageProcessor
{
    public async Task<Stream> ResizeAsync(Stream input, int maxWidth, int maxHeight, int quality)
    {
        using var image = new MagickImage(input);
        // ...
    }
}

builder.Services.AddSingleton<IImageProcessor, MagickImageProcessor>();
```

## Adding a new entity_type

No library change — just pass the new string at upload:

```csharp
await _files.UploadAsync(systemId, "Vessel", vesselId, stream, ...);
await _files.UploadAsync(systemId, "Pet", petId, stream, ...);
```

The DB index `(entity_type, entity_id)` makes lookup fast regardless of new types.

## Convention for entity_type strings

```
Job, Vehicle, Customer, Note, Vessel, Forklift, Pet, Booking, Invoice, Estimate, Listing, ServiceCenter, ...
```

PascalCase, singular. Match the entity class name from the owning library.

## Related

- [`polymorphic-fk.md`](polymorphic-fk.md) — pattern detail.
- [`signed-urls.md`](signed-urls.md) — TTL config + edge cases.
- [`multipart-upload.md`](multipart-upload.md) — large file flow.
- [`db-blob-fallback.md`](db-blob-fallback.md) — legacy data handling.
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 1 (polymorphic FK).
