# macOS networking and build

## Network and sandbox policy

The macOS application remains sandboxed. Both debug and release builds have
`com.apple.security.network.client`, which permits outbound connections for
Firebase, Google authentication, Firestore, and user-configured AI endpoints.
Release has no incoming-network entitlement. Debug additionally has
`com.apple.security.network.server` and `com.apple.security.cs.allow-jit` only
for Flutter development tooling.

The runner declares why it may contact a user-configured server on the local
network. macOS 15 and later can request Local Network permission on the first
such connection. Nexecute does not browse or advertise Bonjour services, so it
does not declare service types. See Apple's
[local-network privacy technote](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
and [App Sandbox network entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client)
documentation.

No `NSAllowsArbitraryLoads`, per-domain ATS exception, certificate override,
inbound release entitlement, or multicast entitlement is configured.

## AI transport behavior

| Endpoint | Behavior |
| --- | --- |
| HTTPS | Preferred. Uses the operating system trust store and normal hostname, validity, and certificate-chain verification. |
| Plain HTTP | Accepted by native clients with an explicit warning. Use only for a server on a trusted LAN or tailnet because prompts and responses are unencrypted. |
| Local address or name | Direct user-entered IPv4, IPv6, single-label, and `.local` names are allowed. Nexecute performs no network discovery. macOS may require Local Network permission. |
| Tailscale | Prefer a valid HTTPS `*.ts.net` or MagicDNS endpoint. A private address does not relax TLS verification. |
| Invalid certificate | Rejected. Diagnostics explain hostname, trust-chain, date, and device-clock checks; Nexecute has no trust-bypass switch. |
| Offline startup | AI networking is lazy and begins only when the user tests a connection, discovers models, or sends a request. An unreachable AI server cannot block application startup or core data features. |

Base URLs cannot contain credentials, query parameters, or fragments. Native
plain-HTTP warnings are a deliberate personal-use trade-off, not a global
transport-security exception. Flutter Web retains its stricter mixed-content
and credential restrictions.

## Device-local data and safe diagnostics

Connection-profile metadata, including its base URL, stays in local shared
preferences. Bearer tokens stay in Android secure storage or the macOS
data-protection Keychain; Firestore receives only conversations and opaque
profile identifiers, never endpoint credentials or profile metadata.

User-facing and persisted failure output is provider-neutral. Provider response
bodies are used transiently only where needed to classify a failure, then
discarded. Diagnostics and failed-message text contain no bearer token, raw
provider payload, low-level exception text, or configured endpoint URL. Review
server logs locally when provider-specific detail is necessary.

## Clean debug build prerequisites

- A macOS host with the Flutter SDK and Xcode command-line tools installed.
- Flutter macOS desktop support enabled and project packages resolved with
  `flutter pub get`.
- An Apple-issued development identity available to Xcode. Select a development
  team for Runner if the tracked team is not available to the local account.
- Access to the signing identity's private key in Keychain. A macOS prompt asks
  for the login-keychain password, which can differ from an Apple Account
  password.
- The tracked `macos/Runner/GoogleService-Info.plist`, URL callback scheme, and
  Firebase options intact. Google and Anonymous providers must remain enabled as
  described in `docs/macos_firebase_authentication.md`.
- Local Network permission granted in **System Settings > Privacy & Security >
  Local Network** when testing a LAN endpoint. Denial affects only that endpoint.

From a clean checkout, verify that `git status --porcelain` prints nothing, then
run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build macos --debug
flutter test integration_test/macos_startup_smoke_test.dart -d macos
```

The build output is
`build/macos/Build/Products/Debug/nexecute.app`. The startup smoke test performs
real Firebase, local-preference, and platform-service initialization and passes
only after reaching either the authentication screen or the signed-in main
shell without an unsupported-platform exception.

For a compile-only build without signing, use the `xcodebuild` command in
`docs/macos_firebase_authentication.md`. That variant cannot verify Google
callbacks, Keychain access groups, or stable local-network privacy identity.

## Verification record

Phase 2C was verified on 2026-09-01 with Flutter 3.47.2, Dart 3.13.2, and
Xcode 26.6 (17F113). A disposable clean checkout completed dependency
resolution and a debug macOS build without modifying tracked files. The
production-path startup smoke test also passed from a development-signed local
build, reaching an application shell after real service initialization.
