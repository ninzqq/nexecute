# macOS event-notification contract

## Status and scope

This document defines the behavior required before native Calendar event
notifications are enabled on macOS. It is an implementation contract, not an
indication that the feature is active. Until the implementation and its tests
are complete, `createDefaultAppPlatformServices` must continue selecting the
explicit no-op reminder scheduler on macOS.

The first release covers only the reminder preference already stored on an
event: at the start time, or one of the existing offsets before it. It does not
add task reminders, remote push, notification actions, critical or time-sensitive
alerts, badges, attachments, custom sounds, or per-occurrence recurrence
exceptions.

The Firestore reminder preference is synchronized application data. Permission,
the device-level enabled state, pending notification requests, and reconciliation
metadata are local derived state and must never be written to Firestore.

## Device-level enablement and permission

Event notifications are enabled separately for each Firebase user on each Mac.
The local state starts as not configured. A different account on the same Mac
does not inherit another account's enabled state.

The application must initialize the Darwin notification plugin without asking
for alert, sound, or badge permission. It may ask for alert and sound access only
after one of these explicit user actions:

- selecting **Enable notifications** in a contextual explanation shown after
  saving an event with a reminder; or
- enabling **Event notifications on this Mac** in application settings.

Saving an event is never conditional on the answer. A reminder synchronized
from another device may be reconciled after access is already enabled, but must
not cause a permission prompt during startup or synchronization. Badge,
provisional, critical-alert, and app-settings permissions are not requested.

Turning the device-level setting off cancels all Nexecute event notifications
for that user without changing event documents or revoking the operating-system
permission. Turning it on requests access when necessary and then reconciles
the user's events. If access is denied, Nexecute explains that the event was
saved but notifications are off on this Mac and offers an explicit route to
System Settings. It does not repeatedly request access or open System Settings
without another user action.

Permission denial, an unavailable notifications service, or a plugin failure
must not block startup, authentication, Firestore access, or an event mutation.
User-facing errors are short and actionable; diagnostics contain status and
counts, never event content, private URLs, credentials, or notification payloads.

## Notification content and interaction

A scheduled notification uses the event title and, when present, its
description. Otherwise its body says that the event is starting now or soon.
The operating system's notification-preview setting controls whether that
content is visible on the lock screen. Nexecute must not add tags, Firestore
paths, account identifiers, endpoint URLs, or other application data to the
visible content.

The notification uses the default sound, no badge, normal interruption level,
and a constant Calendar-event thread identifier. It is presented while Nexecute
is in the foreground as well as in the background. Clicking it activates
Nexecute. Opening a particular event from the payload is a later enhancement
and must tolerate a deleted event or changed account before it is enabled.

The payload contains only the opaque event identifier. Notification request
identifiers are deterministic, namespaced hashes of the account, event, and,
when needed, occurrence key; raw user identifiers are not exposed in them.

## Scheduling contract

Scheduling runs only after an event write succeeds. Cancellation runs after a
delete succeeds. Failures in either operation are isolated from the successful
Firestore mutation, matching the existing repository decorator contract.

For every create or update, the scheduler first removes all pending requests
for that event and then applies the current state:

- `none` leaves no pending request;
- a deleted event leaves no pending request;
- a non-recurring event produces one request when its reminder time is in the
  future;
- a non-recurring event whose reminder time has passed produces no request and
  reports `triggerInPast`; and
- a recurring event follows the recurrence rules below.

All-day events keep the same start-time and offset semantics used by the shared
event model; macOS does not silently move them to another time of day.

Cancellation is series-wide. The implementation must be able to remove every
request derived from an event identifier, including requests created for
individual future occurrences. A small device-local registry may be used for
that purpose, but it stores identifiers and scheduling metadata only, not event
titles or descriptions. A missing or corrupt registry is repaired from the
pending Nexecute requests and current event data.

## Recurrence

Each recurring series remains one Firestore document and one scheduling unit.
A generated Calendar occurrence must never be scheduled as if it were an
independent event.

Daily and weekly series may use a single repeating calendar request when tests
prove that its local weekday/time and reminder offset match the shared
recurrence model across daylight-saving changes. Monthly and yearly series use
explicit one-shot occurrence requests generated with the same calendar rules as
the application. This is required because Nexecute clamps month-end dates and
maps a leap-day anniversary to February 28 in non-leap years, behavior that a
single day-of-month repeating trigger cannot express reliably.

Explicit occurrences use a rolling 24-month look-ahead. Nexecute owns at most
48 pending event-notification requests in total and schedules the nearest
eligible triggers first. Repeating requests count toward that total. Reaching
the limit never evicts another application's notifications or changes Firestore
data; the local notification status reports that later reminders are waiting
for capacity. Every reconciliation refills the nearest available requests.

The capacity and horizon are deliberately conservative initial-release limits.
Changing either later requires scheduling tests and a roadmap update, not a
data migration.

Any change to title, description, start, end, reminder, or recurrence cancels
all requests for the series and rebuilds them. Editing a displayed generated
occurrence therefore updates the complete series, as the Calendar already does.
Deleting any displayed occurrence deletes and cancels the complete series.
Per-occurrence edits, exclusions, and snoozes remain out of scope.

## Time zone and clock behavior

The scheduler resolves reminder times in the current macOS IANA time zone using
the same `DateTime` values the application currently displays. It does not add
or persist a second event-time-zone model. The last reconciled IANA zone is
stored locally for each enabled user.

On startup and each foreground transition, a changed time zone causes future
requests to be rebuilt from current event models. A one-shot event therefore
continues to follow its stored instant as represented by the application, while
recurrence continues to follow the application's current local-calendar
expansion rules.

For daylight-saving transitions, there must be exactly one request per logical
occurrence. A local time skipped by a spring-forward transition moves to the
first valid local instant after the gap. An ambiguous fall-back time uses its
first occurrence. These choices must be pinned by tests with a fake clock and a
known transition zone before release.

Manual system-clock changes are handled on the next foreground reconciliation.
No reminder that is already in the past is fired merely because reconciliation
ran late.

## Restart, synchronization, and account lifecycle

Pending operating-system requests are expected to survive application restart,
sleep, and reboot; initialization must not blindly delete them. After an
authenticated startup, and whenever the first usable event snapshot arrives, a
non-blocking reconciler compares Nexecute's pending requests with current event
data. It cancels confirmed orphans and stale requests, adds missing requests,
and replenishes the recurrence horizon.

Reconciliation also runs after:

- a local event mutation;
- a debounced event-stream change, including an edit from another device;
- returning to the foreground;
- a detected time-zone change; and
- enabling event notifications for the current user.

Cached Firestore data may be used while offline. A loading state, stream error,
or unavailable network is not proof that events were deleted and must not cause
pending requests to be erased. An authoritative deletion, disabling a reminder,
or disabling notifications locally does cancel the applicable requests.

Signing out cancels every pending event notification for that account so event
content cannot appear after the account leaves the application. The local
enabled preference may be retained for the same account on this personal Mac;
signing back into that account reconciles again if operating-system access still
exists. Switching accounts cancels the old account before considering the new
one and never prompts on behalf of the new account during startup.

## Result handling and failure isolation

The existing scheduler outcomes remain the minimum result vocabulary:
`scheduled`, `notRequested`, `triggerInPast`, `permissionDenied`, `unsupported`,
and `failed`. Reconciliation additionally needs a capacity-limited state so the
interface can distinguish a valid reminder waiting for a local slot from a
plugin failure.

The event editor and settings UI surface local outcomes without implying that
the synchronized event write failed:

- permission denied: **Event saved. Notifications are off on this Mac.**
- reminder time passed: **Event saved. The reminder time has already passed.**
- scheduling/capacity failure: **Event saved, but its reminder could not be
  scheduled on this Mac.**

The macOS implementation is created behind the existing independent reminder
service boundary. Initialization failure selects the no-op scheduler and does
not affect widgets, secure credentials, or core services. Runtime scheduling,
cancellation, event-stream, and reconciliation failures are contained within
the reminder capability.

## Implementation shape

The initial implementation should contain two responsibilities:

1. A macOS scheduler adapter around the local-notifications plugin, responsible
   for permission state and individual pending requests.
2. A lifecycle reconciler, started only for an authenticated and locally
   enabled user, responsible for event snapshots, account changes, foreground
   and time-zone checks, recurrence expansion, capacity, and orphan cleanup.

The repository decorator remains responsible for best-effort scheduling after
successful local mutations. Cross-device and restart correctness belong to the
reconciler rather than to feature widgets. Platform checks remain in startup
composition, not Calendar presentation or domain code.

## Verification gate

macOS must keep the no-op scheduler until automated coverage verifies:

- initialization never prompts and permission requests follow only explicit
  enablement;
- allowed, denied, later-denied, unsupported, and initialization-failure paths;
- one-shot scheduling, passed triggers, update-before-reschedule, disable, and
  delete cancellation;
- daily and weekly daylight-saving behavior, monthly month-end clamping, yearly
  leap-day behavior, and reminder offsets that cross a day boundary;
- whole-series edits and deletion from a generated occurrence;
- deterministic identifiers and cancellation of every occurrence request;
- the 24-month horizon, 48-request capacity, nearest-first ordering, and
  replenishment;
- restart reconciliation, confirmed orphan removal, cached offline startup,
  remote-device edits, time-zone changes, sign-out, and account switching; and
- failure isolation plus content-, identifier-, and diagnostic-privacy rules.

A development-signed native build must then manually verify the permission
prompt, System Settings recovery, banner and sound in foreground/background,
click-to-activate, sleep/wake, application restart, system reboot, time-zone
change, denial, and core application behavior when notifications are
unavailable. Results and the tested macOS/plugin versions are recorded in the
roadmap before replacing the no-op service.
