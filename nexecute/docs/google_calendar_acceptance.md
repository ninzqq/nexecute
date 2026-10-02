# Google Calendar acceptance record

This record separates deterministic verification from live Google OAuth and
signed-device acceptance. Do not add account details, tokens, calendar IDs, or
event content to this document or test output.

## Automated verification environment

Verified on 2026-10-02 with:

- Flutter 3.47.2 stable (`d3b14c8769`), Dart 3.13.2, DevTools 2.60.0.
- `google_sign_in` 6.3.0, `google_sign_in_android` 6.2.1, and
  `google_sign_in_ios` 5.9.0 from `pubspec.lock`.
- `firebase_auth` 5.7.0, `flutter_secure_storage` 10.3.1, and `http` 1.6.0
  from `pubspec.lock`.
- Google Calendar API v3 REST contract.
- macOS 27.0 (26A428), Xcode 27.0 (27A266a), Apple silicon host.

The automated suite covers authorization lifecycle and recovery, pagination,
recurrence and all-day mapping, account-scoped identities and cache isolation,
bounded cache behavior, stale fallback, read-only mutation boundaries,
source-specific failures, and all application themes at compact and expanded
widget sizes. This is not evidence that the native Google sign-in configuration
or a signed release build works on a real account.

## Data-boundary audit

The provider graph in `lib/main.dart` supplies Google data only through
`GoogleCalendarSource` into `CompositeCalendarReadSource`. Firestore,
notifications and reminders, widgets, search, and Assistant context continue to
consume the native `EventRepository`; they do not receive a
`CalendarReadSource`. Google events are represented as read-only
`CalendarDisplayEvent` values, and the read boundary rejects external events
that advertise native edit, delete, reminder, or conversion capabilities.

The HTTP gateway receives an access token only as an in-memory request
parameter. The local-store schema contains calendar metadata, selected IDs, and
bounded event ranges, but has no token or owner-identity fields. Transport and
cache errors use fixed sanitized messages. This architecture and its mutation,
cache-schema, owner-isolation, and sanitized-failure tests are the evidence for
the Phase 5 data-boundary verification item.

## Live acceptance procedure

Run this procedure on a signed Android build and a development-signed macOS
build after the Google Cloud consent screen, Calendar API, package/bundle IDs,
signing fingerprints, and native client configuration are complete.

1. Record the device OS version, build commit, Flutter version, resolved
   `google_sign_in` platform package version, and Calendar API version.
2. Sign into Nexecute, open Calendar settings, and connect the same Google
   account explicitly. Verify the consent screen requests only Calendar list
   read-only and Calendar events read-only access.
3. Separately cancel account selection and deny consent. Verify native Nexecute
   calendar data remains usable and Firebase login is unchanged.
4. Try a different Google account. Verify connection is rejected without
   replacing the Firebase session or exposing the other account's cached data.
5. Verify primary, shared, read-only, recurring, moved-instance, timed, and
   all-day events in month, week, all-day, and agenda views. Check daylight
   saving boundaries in the calendar's source time zone.
6. Disable and re-enable calendars, refresh, restart offline, and reconnect.
   Verify selections persist, saved events are marked stale offline, and no
   duplicate occurrences appear.
7. Open event details. Verify source information and safe Google links are
   available, while Edit and Delete are absent in compact and expanded layouts.
8. Remove Nexecute's grant in Google Account settings. Verify the next request
   performs bounded recovery, reports authorization expiry, and leaves a saved
   stale copy visible when available.
9. Disconnect Calendar and log out independently. Verify only the matching
   account's Google cache is cleared and native Nexecute events remain intact.
10. Inspect release logs and diagnostics for access tokens, authorization
    headers, account identifiers, calendar identifiers, and event content.

Record only pass/fail results and sanitized defects. The signed Android and
macOS runs remain outstanding until this procedure has been completed.
