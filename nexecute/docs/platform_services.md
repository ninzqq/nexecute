# Platform services

Native and optional integrations are selected once during startup by
`createDefaultAppPlatformServices`. Feature and repository code receives typed
services and does not decide which operating system is running.

| Service | Android | macOS | Web/unsupported |
| --- | --- | --- | --- |
| Event reminders | Android local notifications | Explicit no-op | Explicit no-op |
| Calendar home widget | Android Home Widget writer | Explicit no-op | Explicit no-op |
| AI credentials | Flutter secure storage | Flutter secure storage (Keychain) | Explicitly unavailable |

The Android reminder initializer retains its existing fallback: if notification
or timezone initialization fails, startup receives a no-op scheduler and the
rest of the application can continue. Calendar widget synchronization also
continues to isolate widget failures from event streams.

macOS no-ops deliberately report reminders as unsupported and ignore widget
updates. They let Calendar, Tasks, Notes, Tags, authentication, and Firestore
operate without pretending that Android-only integrations are available.

macOS AI credentials use the data-protection Keychain, are available only while
the device is unlocked, do not synchronize through iCloud, and use a dedicated
Nexecute service name. Both macOS entitlement files include Nexecute's own
keychain access group as well as the separate Google sign-in group.

Credential lifecycle is intentionally device-local:

- Saving a replacement bearer token creates a new Keychain item before deleting
  the old one.
- Removing authentication or deleting a profile removes its Keychain item.
- Duplicating a profile copies no credential reference or secret.
- Firebase sign-out does not delete local AI profiles or credentials. They
  remain available to a later session on this personal device, just like the
  other locally stored AI settings. A future shared-device mode must clear both
  profile metadata and referenced credentials together.

`integration_test/flutter_secure_storage_macos_test.dart` exercises native
Keychain save, replacement, read, and deletion on a development-signed macOS
build. Controller tests cover replacement cleanup, profile deletion, and
credential-free duplication. Phase 2B.3 will broaden startup failure isolation
beyond the existing reminder and widget safeguards.
