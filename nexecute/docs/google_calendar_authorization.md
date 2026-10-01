# Google Calendar authorization

Nexecute's Google Calendar integration is optional and read-only. It uses the
same app-scoped Google Sign-In session as Firebase login, but Calendar scopes are
requested only when the user explicitly connects the integration. Calendar
authorization never signs the user out of Firebase.

## Google Cloud prerequisites

These settings live outside Git and must be completed by an owner of Google
Cloud project `nexecute-49018` before native acceptance testing:

1. Enable **Google Calendar API** for the project.
2. In **Google Auth Platform**, configure the app identity, support email,
   developer contact, and authorized domains required by the existing Firebase
   authentication setup.
3. Add only these Calendar data scopes:
   - `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
   - `https://www.googleapis.com/auth/calendar.events.readonly`
4. While the consent screen is in testing, add each Android and macOS acceptance
   account as a test user. Publishing an external app with sensitive Calendar
   scopes may require Google's verification process.
5. Keep the Android OAuth client package name as `com.jndevworks.nexecute` and
   register the SHA fingerprints for each build used in testing.
6. Keep the macOS OAuth client, bundle identifier
   `com.jndevworks.nexecute`, callback URL scheme, Keychain group, and network
   entitlements aligned with `docs/macos_firebase_authentication.md`.

Do not commit client secrets, service-account credentials, access tokens,
account identifiers, consent screenshots containing personal data, or Calendar
payloads.

## Account and token lifecycle

Calendar access is allowed only when the Google Sign-In account's stable account
ID equals the Google provider UID attached to the current Firebase user. Email
addresses and the Firebase user UID are not used for this comparison.

Access tokens are obtained from Google Sign-In when needed. They are held only by
the caller for the request lifecycle and are not persisted to Firestore, shared
preferences, secure storage, logs, or diagnostics. A rejected token permits one
authentication-cache refresh; another rejection leaves authorization expired
instead of retrying requests indefinitely. Token handles are tied to one
connection generation, so a late request from an old account or connection
cannot expire a newer connection.

Disconnecting Calendar clears Nexecute's in-memory authorization state, signs
out the shared local Google provider session, and invokes account-scoped cache
cleanup without calling Firebase sign-out. It does **not** necessarily revoke
Nexecute's OAuth grant at Google. A user who wants to revoke the grant must
remove Nexecute from the third-party access section of their Google Account.

Firebase logout, Firebase account replacement, Google provider unlinking, and a
Google account change also invalidate Calendar authorization and invoke
account-scoped cache cleanup. The cache implementation is introduced in Phase 3;
Phase 2 supplies the lifecycle boundary and a no-op implementation.

## Native verification

The provider boundary has deterministic coverage for cancellation, denial,
account mismatch, token expiration and recovery, disconnect, logout, provider
unlinking, stale operations, account changes, disposal, and unsupported
platforms. The real consent flow still requires device testing after the Cloud
configuration is complete:

1. Sign into Nexecute with a Google account, explicitly connect Calendar, and
   confirm that the consent screen requests only the two read-only scopes.
2. Cancel the chooser and deny consent separately; confirm that Nexecute login
   and native Calendar remain usable.
3. Connect the matching account and confirm the service reports that account as
   connected without requesting consent during app startup or Firebase login.
4. Attempt to choose another account and confirm that Calendar connection is
   rejected without changing the Firebase session.
5. Disconnect Calendar and confirm that Nexecute remains logged in. Reconnect
   and note that Google may reuse the existing grant without showing consent.
6. Remove Nexecute's grant in Google Account settings and confirm that the next
   authorized request expires cleanly after one recovery attempt.
7. Repeat on a signed Android build and a development-signed macOS build.

Record tested OS, Flutter, `google_sign_in`, and Calendar API versions, but no
tokens, account details, calendar identifiers, or event content.
