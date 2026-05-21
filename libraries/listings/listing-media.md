---
library: listings
version: 0.1.0
related-rfcs: [0014]
related-libs: [files]
last-verified: 2026-05-22
tags: [listings, media, photos]
summary: Listing photos — system_listing_media join to @chthonic/files.
---

# Listing media

Photos / hero images for a listing. Stored in `@chthonic/files`; referenced via `system_listing_media`.

## Schema

```sql
CREATE TABLE system_listing_media (
    media_id INT PRIMARY KEY AUTO_INCREMENT,
    system_listing_id INT NOT NULL,
    file_id INT NOT NULL,           -- @chthonic/files
    display_order INT NOT NULL DEFAULT 0,
    caption VARCHAR(200) NULL
);
```

The actual file lives in `@chthonic/files.file` with `entity_type='Listing'`, `entity_id=<system_listing_id>`. The `system_listing_media` row adds display order + caption.

## Upload flow

```tsx
import { FileUploadButton } from '@chthonicsystems/files';

<FileUploadButton
  entityType="Listing"
  entityId={listingId}
  systemId={systemId}
  onUploaded={async (file) => {
    await api.post(`/api/systems/my-system/listing/media`, {
      fileId: file.id,
      displayOrder: lastOrder + 100,
    });
  }}
/>
```

Two-step: upload via files; record media row via listings.

## Display in Liquid

```liquid
<div class="hero">
  <img src="{{ listing.hero_image_url }}" />
</div>

{% for media in listing.media %}
  <figure>
    <img src="{{ media.url }}" />
    {% if media.caption %}<figcaption>{{ media.caption }}</figcaption>{% endif %}
  </figure>
{% endfor %}
```

`media.url` is a long-TTL signed URL (7 days for public listings — see [`libraries/files/signed-urls.md`](../files/signed-urls.md)).

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`public-listing-page.md`](public-listing-page.md).
- [`libraries/files/`](../files/) — file storage.
