# macOS Firebase authentication

Nexecute's macOS runner uses the stable bundle identifier
`com.jndevworks.nexecute` and the existing Firebase project
`nexecute-49018`. The Android application remains registered as
`com.jndevworks.nexecute`; do not select or restore the legacy
`com.example.nexecute` registrations when refreshing configuration.

## Tracked configuration

- `lib/firebase_options.dart` contains the generated Android and macOS
  `FirebaseOptions` values.
- `android/app/google-services.json` remains bound to the existing Android app.
- `macos/Runner/GoogleService-Info.plist` is bound to the macOS Runner target.
- `macos/Runner/Info.plist` declares the Google client ID and reverse-client-ID
  callback URL scheme.
- The macOS entitlements allow outbound network requests and the keychain access
  group required by Google Sign-In.

Firebase configuration contains app and project identifiers, not service-account
credentials. Never add service-account JSON, signing certificates, provisioning
profiles, private keys, access tokens, account data, or personal endpoint URLs.

To refresh the generated files, authenticate both CLIs and run this command from
the Flutter application directory:

```sh
flutterfire configure \
  --project=nexecute-49018 \
  --platforms=android,macos \
  --android-package-name=com.jndevworks.nexecute \
  --macos-bundle-id=com.jndevworks.nexecute \
  --macos-target=Runner \
  --android-out=android/app/google-services.json \
  --macos-out=macos/Runner/GoogleService-Info.plist \
  --out=lib/firebase_options.dart \
  --overwrite-firebase-options
```

After regeneration, verify that `firebase.json` and
`lib/firebase_options.dart` still reference Android app
`1:810257036214:android:67a30b5c8095ffcb038717` and that FlutterFire did not
restore a legacy Android default.

## Console and signing prerequisites

These settings live outside Git and must be checked by a Firebase project owner
or by the developer running the app:

1. In Firebase Console, open **Authentication > Sign-in method** and keep both
   Google and Anonymous authentication enabled. Google requires a project
   support email.
2. If the Google OAuth consent screen is still in testing, add the accounts used
   for alpha testing as test users in Google Cloud Console.
3. In Xcode, select the Runner target and a local Apple development team. Keep
   the bundle identifier exactly `com.jndevworks.nexecute`; do not commit
   personal signing changes.
4. Confirm that the built Runner has Keychain Sharing and outgoing network
   access. The corresponding entitlements are tracked, but the signing identity
   and provisioning state are local to each developer.

## Development-signed verification

Run `flutter run -d macos`, then complete this checklist before marking Phase 2A
fully complete:

1. Start while signed out and confirm that the login screen appears without an
   unsupported-platform exception.
2. Open Google Sign-In, cancel the chooser, and confirm that the login screen
   remains usable without an error.
3. Sign in with an alpha account and confirm that its existing Calendar, Tasks,
   Notes, and Tags become available.
4. Quit and relaunch the app and confirm that the Firebase session is restored.
5. Sign out and confirm that the app returns directly to the login screen without
   opening a Google account chooser.
6. Retry with networking disabled and confirm that a retryable authentication
   message is shown without exposing provider details or tokens.

The provider boundary and login UI have automated coverage for session stream
restoration, cancellation, sign-out, and failures. The real Google chooser and
development signing still require this interactive macOS pass.

Native compilation can be checked without a personal signing identity:

```sh
xcodebuild \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -derivedDataPath build/macos_xcode \
  CODE_SIGNING_ALLOWED=NO \
  build
```

That build does not exercise keychain sharing or Google callbacks. A normal
`flutter build macos --debug` intentionally requires a local development team
because Google Sign-In's keychain access-group entitlement cannot be ad-hoc
signed.

## Firestore isolation

The desktop client uses the same client SDK and `users/{userId}` paths as
Android. It has no service-account or Admin SDK path. `firestore.rules` permits
access only when `request.auth.uid` matches the path's `userId`, including every
nested collection.

Run the isolation suite with the Firestore emulator:

```sh
firebase emulators:exec --only firestore \
  "npm --prefix emulator_tests test" \
  --project nexecute-emulator-tests
```

The suite proves that an owner can access nested data while unauthenticated and
cross-user reads and writes are rejected. A Java runtime is required; Android
Studio's bundled JBR is sufficient when no system JDK is installed.
