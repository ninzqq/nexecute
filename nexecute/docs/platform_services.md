# Platform services

Native and optional integrations are selected once during startup by
`createDefaultAppPlatformServices`. Feature and repository code receives typed
services and does not decide which operating system is running.

| Service | Android | macOS in Phase 2B.1 | Web/unsupported |
| --- | --- | --- | --- |
| Event reminders | Android local notifications | Explicit no-op | Explicit no-op |
| Calendar home widget | Android Home Widget writer | Explicit no-op | Explicit no-op |
| AI credentials | Flutter secure storage | Explicitly unavailable until Phase 2B.2 | Explicitly unavailable |

The Android reminder initializer retains its existing fallback: if notification
or timezone initialization fails, startup receives a no-op scheduler and the
rest of the application can continue. Calendar widget synchronization also
continues to isolate widget failures from event streams.

macOS no-ops deliberately report reminders as unsupported and ignore widget
updates. They let Calendar, Tasks, Notes, Tags, authentication, and Firestore
operate without pretending that Android-only integrations are available.

Phase 2B.2 will replace only the macOS credential-store entry after its keychain
lifecycle is verified. Phase 2B.3 will broaden startup failure isolation beyond
the existing reminder and widget safeguards.
