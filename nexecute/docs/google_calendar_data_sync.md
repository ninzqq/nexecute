# Google Calendar data synchronization

Phase 3 adds the read-only Google Calendar data source used by the existing
source-aware Calendar read layer. Android and macOS use the same implementation.
Unsupported platforms keep the Google source unauthenticated and leave native
Nexecute Calendar behavior unchanged.

## Retrieval

The integration calls the Google Calendar v3 REST API directly through the
app's `http` dependency. It requests an explicit field projection and never
logs requests, headers, response bodies, account identifiers, calendar
identifiers, or event content.

Calendar-list and event responses are fully paginated. Event requests use:

- The exact `CalendarQueryRange` supplied by the month or week swipe buffer.
- `singleEvents=true` so Google expands recurrence and applies exceptions.
- `orderBy=startTime` and `showDeleted=false`.
- A 15-second timeout per attempt and at most three attempts for transport,
  quota, HTTP 429, and server failures.

Calendar failures are isolated. Successful calendars replace their bounded
snapshots while a failed calendar can continue displaying its previous cache as
stale. HTTP 401 uses the authorization service's generation-bound recovery;
concurrent rejection of one token shares a single recovery.

Timed RFC 3339 values are normalized to UTC instants while retaining Google's
source time-zone metadata. All-day dates remain calendar dates, and Google's
exclusive end date is converted to Nexecute's inclusive final date. Cancelled
instances are excluded. External links are retained only when they are valid
HTTPS URLs.

Occurrence identity is the SHA-256 digest of a canonical tuple containing the
Google account, calendar, event, and original occurrence identity. The digest
remains stable when a recurring instance moves and does not expose those raw
identifiers through `CalendarEventIdentity.toString()`.

## Selection

`GoogleCalendarSource.catalogStates` exposes calendar names, colors, access
roles, time zones, and selected identifiers for the Phase 4 settings interface.
Before an explicit selection, Google's selected calendars provide the default.
After `setSelectedCalendarIds` establishes a selection, newly discovered
calendars remain disabled until the user enables them.

Selection metadata and deselected-calendar cache removal are committed through
one serialized atomic store mutation. Calendar-list refresh is single-flight,
so a slower response cannot overwrite a newer user selection.

## Local cache

The production store lives under the platform application-support directory in
`google-calendar`. Each Firebase-user and Google-account pair receives a
directory named by a SHA-256 digest of both identifiers. Raw owner identifiers
are not used in paths.

Each owner has one strict, versioned `state.v1.json` file. Writes use a unique
sibling temporary file, flush it, and atomically rename it over the previous
state. The store rejects symlinked roots and owner directories, malformed or
noncanonical records, unsafe links, mismatched calendar ownership, duplicate
identities, and unsupported schema versions. A corrupt owner cache is deleted
and rebuilt from the API when authorization is available.

The cache is bounded to:

- 30 days of range age.
- 24 calendar/range snapshots.
- 5,000 events in total.
- 1,000 calendar metadata entries.
- A 16 MiB state file.

At most 24 calendars may be selected at once so one visible-range refresh can
be committed atomically within the snapshot bound. Metadata remains available
for up to 1,000 calendars.

Eviction is deterministic by fetch time and canonical range key. An oversized
current refresh is rejected without replacing the previous cache. Newer range
coverage shadows absent events from older overlapping snapshots, preventing
cancelled or moved events from reappearing while retaining unaffected adjacent
offline coverage.

Normal application shutdown retains the cache for offline use after ownership
by the same Firebase and Google accounts has been restored. The cache does not
persist a discoverable current-account marker, so it cannot be opened while
account ownership is unknown. Explicit Calendar disconnect,
Firebase logout/account replacement, Google-provider unlinking, and Google
account changes clear the matching owner cache. Every lookup is owner-qualified,
so cleanup failure cannot expose another account's data.

## Data boundaries

Google metadata and events remain in the application-private local cache. They
do not pass through `EventRepository` and are not copied to Firestore, search,
widgets, reminders, Assistant context, or mutation commands. Access tokens are
used only for an in-flight REST request and are never written to this cache.

## Calendar interface

Calendar settings expose connection state, the connected account, catalog
refresh, explicit calendar selection, retry, and disconnect controls. Selection
changes are saved atomically, and color indicators are accompanied by calendar
names and enabled/disabled text.

Selected Google events are merged with Nexecute events in month, week, all-day,
and selected-day agenda views. Calendar color is used only as an accent so event
titles retain theme contrast. Details identify Google Calendar, the source
calendar, read-only access, source time zone, and stale saved-copy state. Edit and
Delete actions are not available. An external action is shown only for a
revalidated HTTPS event URL.

Google refresh, authorization, stale-cache, and rate-limit messages use a
source-specific status row and never replace usable native Calendar content.
Refreshes reuse the active range stream, preserving the selected date, view
mode, page, agenda state, and week scroll position.

The cache marks fallback events with `CalendarDisplayEvent.isStale`. Phase 4 is
responsible for presenting that state and the catalog controls in the Calendar
and settings interface. Signed Android/macOS testing against real primary,
shared, recurring, all-day, and read-only calendars remains part of Phase 5.
