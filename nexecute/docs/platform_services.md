# Platform services

Native and optional integrations are selected once during startup by
`createDefaultAppPlatformServices`. Feature and repository code receives typed
services and does not decide which operating system is running.

| Service | Android | macOS | Web/unsupported |
| --- | --- | --- | --- |
| Event reminders | Android local notifications | Explicit no-op pending implementation | Explicit no-op |
| Calendar home widget | Android Home Widget writer | Explicit no-op | Explicit no-op |
| AI credentials | Flutter secure storage | Flutter secure storage (Keychain) | Explicitly unavailable |

Each optional service is constructed behind its own failure boundary. Android
notification or timezone initialization falls back to a no-op reminder
scheduler; Android home-widget construction falls back to a no-op updater; and
Android or macOS secure-storage construction falls back to an unavailable
credential store. One failure does not prevent the remaining optional services
from being constructed.

These fallbacks preserve startup for Calendar, Tasks, Notes, Tags,
authentication, and Firestore synchronization. They expose only the affected
capability as unsupported: reminders return an unsupported result, widget calls
do nothing, and AI settings report that secure credential storage is
unavailable.

Operational failures are isolated too. Reminder scheduling or cancellation
cannot turn a successful Firestore event mutation into a failure, widget update
errors cannot interrupt event streams or theme changes, and secure-storage
errors stay within credential-dependent AI actions.

macOS no-ops deliberately report reminders as unsupported and ignore widget
updates. They let Calendar, Tasks, Notes, Tags, authentication, and Firestore
operate without pretending that Android-only integrations are available.

The permission, scheduling, recurrence, time-zone, restart, synchronization,
account-lifecycle, and verification requirements for replacing the macOS
reminder no-op are defined in `docs/macos_event_notifications.md`. Defining the
contract does not enable notifications; the no-op remains selected until its
implementation passes that document's automated and native verification gate.

The staged `MacOSEventReminderScheduler` initializes Darwin notifications with
every permission request disabled. It exposes separate permission inspection
and explicit alert-and-sound request operations, and currently supports only
one-shot event requests. It is injectable into platform composition for tests,
but is not yet the production macOS default. Recurring scheduling, lifecycle
reconciliation, device-level enablement, and the remaining verification gate
must land before that selection changes.

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
credential-free duplication. Platform-service tests inject failures into every
optional constructor, including simultaneous Android failures, and verify that
a complete degraded service bundle is still returned.
