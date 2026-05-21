---
library: mobile-runtime
version: 0.1.0
related-rfcs: [0018]
related-libs: [notifications]
last-verified: 2026-05-22
tags: [mobile-runtime, push, fcm]
summary: registerPushNotifications — Firebase Cloud Messaging registration + foreground/background handlers.
---

# Push notifications

`registerPushNotifications` calls Capacitor's PushNotifications plugin:

1. Request permission (iOS) / register (Android).
2. On `registration` event → callback fires with FCM token.
3. Consumer persists the token to `/api/notifications/register-token` (server-side dispatch via `@chthonic/notifications`).
4. On `pushNotificationReceived` event → in-foreground handler fires.
5. On `pushNotificationActionPerformed` → user tapped notification; navigate to the embedded link.

## FCM token registration

```ts
import { PushNotifications } from '@capacitor/push-notifications';

PushNotifications.addListener('registration', (token) => {
  fcmTokenCallback(token.value);   // consumer-supplied
});
```

## Server-side match

`@chthonic/notifications.FcmPushService` reads tokens from the same store the consumer wrote to. Sends notifications via Firebase Admin SDK.

## Foreground handling

If the app is foregrounded when a push arrives, iOS / Android default to silent. Consumers usually:

- Display an in-app banner via `<AppToast>` (from `@chthonic/ui`).
- Refresh the affected entity list (e.g. job ticker).

## Token rotation

FCM tokens rotate occasionally. The runtime re-registers on every app launch; latest token wins. The server treats tokens as upsert keyed by `(user_id, platform)`.

## Related

- [`libraries/notifications/multi-channel-publisher.md`](../notifications/multi-channel-publisher.md).
- [`capacitor-bridge.md`](capacitor-bridge.md).
