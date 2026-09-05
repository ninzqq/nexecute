# Nexecute Roadmap

## Roadmap maintenance

- Update this document whenever roadmap work is started, changed, completed,
  deferred, or replaced by another approach.
- Keep feature statuses and implementation checklists aligned with the actual
  application state.
- Record meaningful scope and architecture decisions here so work can resume
  later without relying on conversation history.

## ~~Tasks / to-do list~~

**Status:** ✅ Completed

Add a deliberately simple, user-specific task list alongside Calendar and
Notes (Quicxecs).

### ~~Version 1 scope~~ ✅

- [x] ~~Add a task with a required title.~~
- [x] ~~Edit an existing task's title.~~
- [x] ~~Mark a task as completed or active.~~
- [x] ~~Delete a task, with an Undo snackbar where practical.~~
- [x] ~~Keep completed tasks in the app.~~
- [x] ~~Hide completed tasks by default inside a collapsed `Completed (n)`~~
  ~~section.~~
- [x] ~~Allow completed tasks to be expanded, viewed, and restored to the~~
  ~~active list.~~
- [x] ~~Persist tasks under the authenticated user in Firestore.~~
- [x] ~~Support all application themes.~~

Not included in version 1: descriptions, tags, priorities, due dates,
subtasks, manual ordering, or task-to-event conversion.

### ~~Navigation and appearance~~ ✅

- [x] ~~Replace the custom two-page bottom bar and center-notched Add button~~
  ~~with a Material 3 `NavigationBar`.~~
- [x] ~~Use three labeled destinations: **Calendar**, **Tasks**, and **Notes**.~~
- [x] ~~Keep the labeled bottom navigation compact at 64 logical pixels so it~~
  ~~does not consume unnecessary content height.~~
- [x] ~~Add a context-aware floating action button at the bottom-right:~~
  ~~`+ Event`, `+ Task`, or `+ Note`.~~
- [x] ~~Show active tasks as a clean checkbox list rather than note-style~~
  ~~cards.~~
- [x] ~~Show completed tasks with strikethrough text and reduced opacity.~~
- [x] ~~Preserve each page's state while moving between destinations.~~

### ~~Data model~~ ✅

Store tasks at:

```text
users/{userId}/todos/{todoId}
```

Minimum fields:

```text
id
title
isCompleted
createdAt
updatedAt
completedAt (nullable)
```

Required operations:

- [x] ~~Stream the current user's tasks.~~
- [x] ~~Add a task.~~
- [x] ~~Edit a task title.~~
- [x] ~~Set completed/active state.~~
- [x] ~~Delete a task.~~

### ~~Implementation checklist~~ ✅

- [x] ~~Refactor the app shell to the three-destination `NavigationBar`.~~
- [x] ~~Add the context-aware floating action button.~~
- [x] ~~Add the `TodoItem` model and Firestore serialization.~~
- [x] ~~Add task stream and CRUD operations.~~
- [x] ~~Register the task stream provider.~~
- [x] ~~Build the active task list and empty state.~~
- [x] ~~Build the collapsed completed-task section.~~
- [x] ~~Add the task creation and editing sheet.~~
- [x] ~~Add completion, restoration, deletion, and Undo interactions.~~
- [x] ~~Verify Firestore security rules for the `todos` collection.~~
- [x] ~~Add model, interaction, persistence, and navigation tests.~~
- [x] ~~Verify the page under Cyberpunk, Midnight, Forest, and Neutral themes.~~

Firestore rules are tracked in `firestore.rules`. They restrict each
authenticated user to their own `users/{userId}` document and its nested
collections, including `todos`.

### ~~Acceptance criteria~~ ✅

- [x] ~~Tasks persist separately for each authenticated user.~~
- [x] ~~Adding, editing, completing, restoring, and deleting tasks work.~~
- [x] ~~Completed tasks leave the active list and enter the collapsed completed~~
  ~~section immediately.~~
- [x] ~~Navigation preserves Calendar, Tasks, and Notes page state.~~
- [x] ~~The floating action button always communicates what it will create.~~
- [x] ~~The Android build and relevant automated tests pass.~~

## Calendar event reminders

**Status:** ✅ Completed

- [x] ~~Let users choose no reminder, the event start, or a preset from five~~
  ~~minutes through one week before the event.~~
- [x] ~~Persist the reminder preference with the event using data schema version~~
  ~~2 and migrate older events to no reminder.~~
- [x] ~~Schedule exact local Android notifications after event creation or edits~~
  ~~and cancel them when reminders are disabled or events are deleted.~~
- [x] ~~Request Android notification and exact-alarm access only when a reminder~~
  ~~is enabled, and restore scheduled notifications after reboot or app update.~~
- [x] ~~Show reminder settings in the event editor and event details.~~
- [x] ~~Cover reminder timing, persistence, mutation lifecycle, editor behavior,~~
  ~~Android scheduling and cancellation, and the debug APK build.~~

The reminder preference synchronizes through Firestore, while the scheduled
alarm itself is local to the Android device where the event is created or
edited. Cross-device reminder reconciliation can be added later if needed.

Android treats event times as minute-precision user input. If an **At event
time** reminder becomes due while the event is being saved, the notification
is delivered immediately during that same displayed minute instead of being
silently discarded as already past. Older past reminders remain discarded and
recurring reminders retain their existing next-occurrence behavior.

## Calendar event recurrence

**Status:** ✅ Completed

- [x] Let users choose no recurrence or repeat an event daily, weekly, monthly,
  or yearly.
- [x] Persist recurrence with the event in Firestore while treating older
  events without recurrence data as non-recurring.
- [x] Expand only the recurring occurrences needed for the visible calendar
  range rather than storing a separate Firestore document for every occurrence.
- [x] Show generated occurrences in month, week, selected-day agenda, and home
  widget data using their occurrence dates and times.
- [x] Preserve the original series schedule when a generated occurrence is
  opened and edited without changing its dates.
- [x] Show recurrence in the event editor and event details.
- [x] Schedule recurring Android reminders using daily, weekly, monthly, or
  yearly notification date-time matching.
- [x] Cover recurrence selection, Firestore mapping, daily and weekly
  expansion, month-end behavior, yearly events, leap days, multi-day spans,
  series editing, and reminder scheduling with automated tests.

Each recurring series remains one event document. Calendar reads combine the
bounded overlap query used for non-recurring events with a query for recurring
series, then generate only the occurrences overlapping the requested calendar
range on the client. Editing or deleting a displayed occurrence currently
applies to the complete series; per-occurrence exceptions are not part of this
scope.

## Responsive event details

**Status:** ✅ Completed

- [x] Give event titles a clear header without crowding them with edit and
  delete icon buttons.
- [x] Group date, time, reminder, and recurrence into one structured summary.
- [x] Present descriptions and tags as distinct readable sections.
- [x] Use labeled edit and delete actions on both mobile sheets and desktop
  side panes.
- [x] Let mobile sheets size to their content and constrain wide detail content
  to a readable width without maintaining separate implementations.
- [x] Close mobile details from the modal barrier and desktop details from the
  unused pane background while keeping interactions inside the details open.
- [x] Cover narrow, wide, bottom-sheet, and desktop side-pane layouts with
  widget tests.

## Calendar week-view readability

**Status:** ✅ Completed

- [x] Use a fixed 56-logical-pixel hour scale instead of compressing all 24
  hours into the available height.
- [x] Keep the date and all-day headers fixed while the time grid scrolls
  vertically from midnight through the end of the day.
- [x] Open the week view at 07:00 and preserve the chosen vertical position
  while moving between weeks.
- [x] Keep 30-minute event titles visible without adding descriptions to the
  narrow week-grid cards.
- [x] Preserve horizontal week swipes, event selection, overlapping-event
  lanes, and access to the earliest and latest hours with automated tests.

## Compact calendar toolbar

**Status:** ✅ Completed

- [x] Combine Today, period navigation, the current period, and the Week/Month
  selector into one row at every layout width.
- [x] Use denser controls and an abbreviated period label on narrow phones.
- [x] Preserve the week view's 07:00 initial position after reclaiming toolbar
  height.
- [x] Cover desktop, phone, and narrow-phone toolbar arrangements with widget
  tests.

## Mobile editor keyboard handling

**Status:** ✅ Completed

- [x] Keep the event/note editor action row pinned above the on-screen keyboard
  while the form fields scroll independently.
- [x] Allow an event to be saved while its title field still owns keyboard
  focus, without first dismissing the keyboard or scrolling to the form end.
- [x] Keep the Event/Quicxec selector and event date controls within narrow
  Android phone widths.
- [x] Cover keyboard insets, Save-button hit testing, persistence, and existing
  editor/navigation behavior with automated tests.
- [x] Give plain-text notes and event descriptions taller bounded writing areas
  while retaining independent field and editor scrolling for long content.

## Future roadmap

The application should continue developing as a focused personal productivity
tool built around Calendar, Tasks, and Notes. New functionality should connect
these areas without making the core workflows dependent on AI or a permanent
network connection.

### Cross-platform laptop access

**Status:** 📋 Planned — adaptive desktop foundation first, native macOS second

Provide access to the same Firestore-backed Calendar, Tasks, Notes, and Tags
from laptop-sized devices without creating a second synchronization system.
All clients should continue using the same authenticated, user-specific
Firestore data.

The first native laptop target will be macOS because it can reuse Flutter's
existing macOS runner while providing direct private-network access to local AI
endpoints, native secure storage, and a path to desktop notifications. The
shared adaptive interface remains platform-neutral so Flutter Web can follow
without a second UI implementation.

#### Known starting point

- The generated Flutter macOS runner and compatible plugin pods already exist.
- Firebase options are currently configured only for Android; application
  startup explicitly rejects macOS and Web.
- No macOS `GoogleService-Info.plist`, Google sign-in configuration,
  entitlements, signing setup, or release workflow is committed.
- Event reminders and home-screen widgets are intentionally activated only on
  Android. macOS must start with explicit supported/no-op service boundaries
  rather than assuming Android behavior.
- The current application shell uses compact bottom navigation. Individual
  views have some responsive sizing, but there is no shared desktop breakpoint
  contract, `NavigationRail`, or persistent desktop workspace yet.
- Firebase configuration files may identify the application but credentials,
  signing keys, personal endpoint URLs, and private test data must never be
  committed.

#### Delivery order

1. Build and verify the shared adaptive desktop shell without requiring macOS
   Firebase access.
2. Configure the macOS Firebase application, authentication, platform service
   boundaries, and network entitlements.
3. Validate a private macOS alpha against the existing Firestore account and
   optional local/private AI connections.
4. Add native desktop conveniences only after the core workflows are stable.
5. Reuse the same shell for a separately configured and hosted web client.

#### Phase 1: shared adaptive desktop foundation

##### Phase 1A: breakpoint and shell contract — complete

- [x] Define centralized compact, medium, and expanded layout classes so
  feature screens do not invent independent width thresholds.
- [x] Extract the top-level navigation destinations and selected-destination
  state from the phone-only shell into one reusable adaptive shell.
- [x] Preserve the existing bottom `NavigationBar` on compact layouts.
- [x] Keep the application navigation permanently visible on medium and
  expanded layouts, using a compact, labeled rail on medium widths and the
  grouped menu on expanded widths.
- [x] Preserve the selected destination and feature state when a window crosses
  a breakpoint instead of rebuilding a separate application tree.
- [x] Keep the drawer and existing named routes on compact layouts, with those
  actions given persistent placement on medium and expanded layouts.
- [x] Cover compact, medium, expanded, and live-resize transitions with widget
  tests, including overflow checks and destination-state preservation.

**Phase 1A boundary:** Do not configure Firebase for macOS, redesign individual
features, or add native desktop integrations in this slice. It should be
testable using the existing platform-independent widget test environment.

##### Phase 1B: desktop feature layouts — complete

- [x] Allow Calendar and the selected-day agenda/details to use a side-by-side
  layout when enough width is available while retaining the compact flow.
- [x] Increase the Notes masonry-grid column count from the shared layout class
  and keep editor sheets usable at desktop widths.
- [x] Constrain long Task and Assistant content to readable widths instead of
  stretching text across the complete window.
- [x] Audit dialogs, bottom sheets, popups, date/time pickers, loading states,
  and empty/error states in freely resizable windows.
- [x] Add desktop-appropriate focus traversal, hover feedback, scroll behavior,
  and minimum interactive sizes without forking feature implementations.
- [x] Verify the adaptive layouts under every application theme at representative
  phone, tablet, laptop, and wide-window sizes.

Expanded Calendar windows keep the selected-day agenda in a persistent side
pane and replace it with scrollable event details when an event is opened.
Compact windows retain the resizable bottom agenda and modal detail flow. Notes
use two, three, or four masonry columns from the shared layout class. Task and
Assistant content is centered at readable widths, and custom editor/detail
bottom sheets are capped at 640 logical pixels on non-compact layouts.

##### Phase 1C: baseline desktop commands — complete

- [x] Add discoverable keyboard shortcuts for primary navigation, create,
  search, save/confirm, close/cancel, and focusing the Assistant composer.
- [x] Prevent shortcuts from firing while an incompatible dialog, text field,
  or confirmation flow owns keyboard focus.
- [x] Add semantics and focus-order tests for keyboard-only navigation.
- [x] Defer global shortcuts, menu-bar commands, and operating-system services
  until the native macOS alpha is stable.

The shared shell exposes Ctrl/Command plus 1–3 for Calendar, Tasks, and Notes,
Ctrl/Command+N for contextual creation, and Ctrl/Command+K for search. Editors
use Ctrl/Command+Enter to confirm and Escape to cancel; Escape also dismisses
expanded Calendar details. The Assistant adds Ctrl/Command+Shift+A for its
composer and Ctrl/Command+Enter to send. A keyboard-shortcut reference is
available from the navigation drawer, with platform-appropriate labels.

Global shell commands are suppressed while editable content or another modal
route owns focus. Editor and Assistant command regions deliberately handle only
their compatible commands. Focus and semantics ordering remains navigation,
content, then contextual creation across compact and rail layouts.

#### Phase 2: native macOS bootstrap

##### Phase 2A: Firebase and Google authentication

- [x] Register the macOS application in the existing Firebase project using a
  stable bundle identifier owned by Nexecute.
- [x] Regenerate FlutterFire options for Android and macOS without changing the
  existing Android application identity or data project.
- [x] Add the required macOS Firebase configuration and Google sign-in callback
  setup, documenting which console-side steps cannot be reproduced from Git.
- [x] Verify sign-in, sign-out, session restoration, cancellation, and
  authentication failures on a development-signed macOS build.
- [x] Confirm that Firestore rules continue to isolate every user's documents;
  the desktop client must not introduce a privileged synchronization path.

The macOS Firebase app uses `com.jndevworks.nexecute`. Automated authentication
coverage verifies session-stream restoration, cancellation, visible failures,
and non-interactive sign-out, and the Firestore emulator suite confirms owner,
unauthenticated, and cross-user access behavior. The interactive authentication
flow was also verified by launching a locally development-signed build from
Xcode. See `docs/macos_firebase_authentication.md` for the console prerequisites
and repeatable test checklist.

##### Phase 2B: platform service boundaries

- [x] Refactor startup registration so each platform receives an explicit
  implementation for reminders, widgets, secure credentials, and other native
  services rather than scattered Android checks.
- [x] Keep Android reminder and home-widget behavior unchanged.
- [x] Start macOS with a documented no-op for unsupported native features, then
  enable them separately only when their behavior is tested.
- [x] Verify `flutter_secure_storage` on macOS, including save, replacement,
  deletion, duplicate-profile behavior, and sign-out expectations.
- [x] Ensure an unavailable optional native service cannot prevent Calendar,
  Tasks, Notes, Tags, authentication, or Firestore synchronization from
  starting.

**Phase 2B.1 complete:** Startup now selects one typed platform-service bundle.
Android retains local event reminders, calendar home-widget updates, and secure
AI credentials. macOS uses explicit no-op reminder and widget implementations
and keeps AI credential storage unavailable until its keychain lifecycle is
verified in Phase 2B.2. The service matrix and boundaries are documented in
`docs/platform_services.md`.

**Phase 2B.2 complete:** macOS now stores optional AI bearer tokens in its
data-protection Keychain under Nexecute's own access group. Native integration
coverage verifies save, replacement, read, and deletion; controller coverage
verifies replacement cleanup, deletion with a profile, and credential-free
duplication. Credentials and local AI profile settings intentionally survive
Firebase sign-out on this personal device. The exact lifecycle and shared-device
caveat are documented in `docs/platform_services.md`.

**Phase 2B.3 complete:** Every optional native service now has an independent
construction boundary. Notification, home-widget, or secure-storage failures
degrade only that capability to its no-op or unavailable implementation, while
the platform bundle and core application services can still start. Existing
repository and theme guards isolate later reminder and widget operation errors;
credential errors remain confined to credential-dependent AI actions. Tests
cover simultaneous Android failures, per-service independence, and unavailable
macOS Keychain construction.

##### Phase 2C: networking, entitlements, and first build

- [x] Configure the minimum sandbox/network entitlements needed for Firebase,
  Google sign-in, HTTPS endpoints, and user-configured local/private AI
  endpoints.
- [x] Define deliberate transport behavior for plain HTTP, local network names,
  Tailscale HTTPS/MagicDNS, certificate failures, and offline startup without
  broad permanent security exceptions.
- [x] Confirm that direct AI endpoint credentials remain device-local and that
  diagnostic output contains no token, raw payload, or personal URL.
- [x] Produce a debug macOS build from a clean checkout and document all manual
  prerequisites.
- [x] Add a lightweight macOS smoke test that proves startup reaches the
  authentication or main application shell without an unsupported-platform
  exception.

**Phase 2C complete:** Debug and release builds retain the sandbox and minimum
outbound-network entitlement, while local-network access has a focused privacy
description and release adds no inbound, discovery, arbitrary-load, or TLS
bypass capability. Transport and diagnostic behavior is documented and tested;
credentials remain in device secure storage and provider payloads, tokens, and
personal endpoint URLs are excluded from surfaced failure output. A disposable
clean checkout produced a debug macOS build, and a development-signed startup
smoke reached the authentication or main shell through the production
initialization path.

#### Phase 3: private macOS alpha

- [ ] Sign in with the same Google account used on Android and verify existing
  Calendar, recurring events, Tasks, Notes, Tags, and AI conversations appear.
- [ ] Create, edit, complete, and delete representative records on macOS and
  verify synchronization in both directions with Android.
- [ ] Verify compact-to-wide resizing, all themes, keyboard-only navigation,
  sleep/wake, offline launch, reconnection, and application restart.
- [ ] Verify Assistant chat and confirmed proposal workflows when the AI server
  is available, slow, unreachable, or intentionally offline; core workflows
  must remain usable in every case.
- [ ] Verify direct local-network and Tailscale endpoint access without
  recording private addresses, credentials, or conversation content.
- [ ] Choose and document the initial personal distribution method: local Xcode
  run, development-signed archive, or manually installed signed build.
- [ ] Record the tested macOS, Flutter, Firebase plugin, Ollama/API, and model
  versions needed to reproduce the alpha results.

#### Phase 4: native macOS enhancements

- [x] Define native event-notification permission, rescheduling, recurrence,
  time-zone, restart, synchronization, account, and series-edit behavior.
- [ ] Implement the macOS notification scheduler and lifecycle reconciler behind
  the existing optional-service boundary.
- [ ] Replace the macOS reminder no-op only after the automated and native
  notification verification gate passes.
- [x] Add macOS menu commands and standard shortcut labels for supported app
  actions.
- [ ] Consider right-click menus, drag and drop, file import/export, menu-bar
  access, and global shortcuts as separate opt-in tasks.
- [ ] Decide whether personal builds remain manually installed or require a
  signed packaging and update mechanism.
- [ ] Keep every native enhancement optional so failure or denial of an
  operating-system permission cannot block core data access.

The signed-in macOS shell now installs a native application menu without
changing Android or other platforms. File exposes contextual New Event, Task,
or Note; Navigate exposes Calendar, Tasks, Notes, Search, and Assistant; the
application and Help menus expose Settings and the keyboard-shortcut reference.
Standard About, Services, Hide, Quit, text-editing, minimize, zoom, full-screen,
and window-order commands remain native macOS items. Menu commands reuse the
shell's guarded actions, so an editor, dialog, or confirmation route prevents
incompatible navigation and creation commands from firing.

The macOS event-notification contract is recorded in
`docs/macos_event_notifications.md`. It keeps permission explicitly
user-initiated, treats pending requests as device-local derived state, defines
whole-series and cross-device reconciliation, and uses explicit future
occurrences where native repeating triggers cannot reproduce month-end or leap
day behavior. macOS continues using the reminder no-op until the scheduler,
reconciler, failure isolation, and native behavior pass the documented gate.

**Notification implementation slice 1 complete:** A macOS scheduler adapter
now initializes the local-notifications plugin without prompting, can inspect
permission or explicitly request alert and sound access, and can build a
privacy-bounded one-shot event notification. Scheduling never requests access
implicitly. Recurring reminders remain deferred to the lifecycle reconciler,
and production macOS composition deliberately continues selecting the no-op
scheduler until the remaining implementation and verification slices are
complete. The adapter has an injectable initialization boundary so construction
failure remains isolated from Keychain and core services.

#### Phase 5: web follow-up

- [ ] Configure the Flutter Web Firebase application, authorized authentication
  domains, Google sign-in flow, branding, icons, and PWA manifest.
- [ ] Reuse the adaptive shell and repositories; do not create separate web
  feature implementations or a second synchronization system.
- [ ] Keep direct hosted-provider credentials disabled in Web and use only
  browser-compatible endpoints or a user-owned gateway.
- [ ] Deploy a private Firebase Hosting release and verify that core workflows
  remain useful when the home AI server is offline.
- [ ] Add installable PWA behavior after authentication, routing, refresh, and
  offline/error states are reliable.
- [ ] Continue serving Linux and Windows laptops through the web client unless
  their native Firebase and authentication paths gain a deliberate supported
  design.

#### Cross-platform acceptance criteria

- The same Google account sees the same data on Android and the laptop client.
- Core Calendar, Tasks, and Notes workflows work at phone and desktop widths.
- Navigation adapts across live window resizing without maintaining separate
  feature implementations or losing the selected destination.
- Optional reminders, widgets, secure storage, AI endpoints, and other native
  services cannot prevent the core application from starting.
- The macOS client remains useful when every configured AI endpoint is
  unreachable.
- Authentication and Firestore rules protect data on every enabled target.
- Android behavior remains unchanged while the shared shell and service
  boundaries are introduced.
- Desktop builds, logs, diagnostics, and committed configuration contain no
  signing material, credentials, personal URLs, or private application data.

### Configurable AI assistant / intelligent quick capture

**Status:** 🚧 In progress

Provide a provider-neutral assistant that can use a local model server, a
private AI gateway, or hosted model providers without coupling Nexecute's
domain or interface to one vendor. The first usable release is a full-screen
chat backed by a configurable OpenAI-compatible endpoint. Later releases add
explicit application context, narrow read tools, and confirmed structured
actions across Calendar, Tasks, and Notes.

AI must remain an optional capability. Calendar, Tasks, Notes, authentication,
and Firestore synchronization must continue to work when every configured AI
endpoint is offline.

Example requests:

- "Remind me to renew my insurance next Friday."
- "Schedule gym on Monday, Wednesday, and Friday at 18:00."
- "Turn this note into three tasks."
- "Summarize my unfinished checklist."
- "What do I have planned tomorrow?"

#### Architecture decisions

- [x] Use connection profiles rather than a hard-coded AI provider.
- [x] Define an independent assistant repository whose public interface uses
  only Nexecute domain types.
- [x] Normalize provider streams into text deltas, completion metadata, tool
  calls, and failures before they reach presentation code.
- [x] Start with the OpenAI-compatible Chat Completions protocol so one adapter
  can support Ollama and other compatible local or private endpoints.
- [x] Add the OpenAI Responses, Anthropic Messages, and Nexecute gateway
  protocols behind the same repository as later adapters.
- [x] Use a BYOK model: every user supplies and pays for their own hosted-model
  account, API key, endpoint, and model. Nexecute never provides a shared
  provider key or pays for another user's inference.
- [x] Allow direct hosted-provider credentials only in native applications as
  an explicit personal-use trade-off. Store them in platform secure storage,
  never Firestore, shared preferences, logs, analytics, or exports.
- [x] Do not support direct hosted-provider keys in Flutter Web. A future web
  client must use a user-owned gateway or another server-side credential
  boundary.
- [x] Permit direct connections to local or private endpoints that do not
  require a hosted-provider secret, including endpoints reached over Tailscale.
- [x] Store endpoint profiles locally, but synchronize conversation metadata
  and completed/interrupted messages through the signed-in user's Firestore
  data. Rely on Firestore's local cache for offline reads and queued writes.
  Keep streaming drafts in memory until they reach a persistable state.
- [x] Keep any supported native endpoint credential in platform secure storage
  rather than Firestore or plain shared preferences.
- [x] Keep hosted inference disabled by default. Require explicit paid-use
  activation and conservative request/token limits in addition to the
  provider's own prepaid balance or hard spending controls.
- [x] Expose the assistant through the drawer as a full-screen route instead of
  adding a fourth bottom-navigation destination.

Minimum connection-profile fields:

```text
id
name
protocol
baseUrl
modelId
authenticationMode
credentialReference (nullable)
capabilityOverrides (optional)
```

Initial protocols:

```text
openAiCompatibleChat
openAiResponses
anthropicMessages
nexecuteGateway
```

#### Step 1: roadmap rescope ✅

- [x] Replace the local-server-specific proposal with a provider-neutral
  architecture.
- [x] Define the local endpoint, native BYOK, and optional user-owned gateway
  security boundaries.
- [x] Record the implementation sequence and acceptance criteria.

#### Step 2: provider-neutral foundation ✅

- [x] ~~Add the connection profile, protocol, message, conversation,~~
  ~~stream-event, model-info, and connection-result domain types.~~
- [x] ~~Add `AiAssistantRepository`, `AiConnectionProfileStore`, and~~
  ~~`AiConversationStore` interfaces.~~
- [x] ~~Return a response handle that exposes normalized stream events and an~~
  ~~explicit cancellation operation.~~
- [x] ~~Add fake implementations and contract tests before wiring a real~~
  ~~server.~~
- [x] ~~Register the assistant dependencies with Provider without making~~
  ~~startup depend on endpoint availability.~~

#### Step 3: AI settings and connection profiles ✅

- [x] ~~Add an AI section to Settings.~~
- [x] ~~Let users add, edit, duplicate, delete, and select connection~~
  ~~profiles.~~
- [x] ~~Persist non-secret profile metadata and the active selection locally.~~
- [x] ~~Support protocol, base URL, model ID, and authentication-mode fields.~~
- [x] ~~Expose model discovery through the assistant repository while still~~
  ~~allowing a model ID to be entered manually.~~
- [x] ~~Add connection-test presentation for connecting, connected,~~
  ~~authentication failure, model missing, timeout, and unreachable results.~~
- [x] ~~Validate URLs and warn when a plain-HTTP endpoint is unsuitable for the~~
  ~~current platform or network context.~~

#### Step 4: first chat vertical slice ✅

- [x] ~~Implement connection testing and model discovery for OpenAI-compatible~~
  ~~endpoints.~~
- [x] ~~Implement streaming OpenAI-compatible Chat Completions over HTTP.~~
- [x] ~~Add an `/assistant` route and Assistant drawer entry.~~
- [x] ~~Build conversation-list, empty, conversation, and composer states.~~
- [x] ~~Stream assistant text into the active message.~~
- [x] ~~Allow an in-progress response to be stopped and a failed or interrupted~~
  ~~response to be retried.~~
- [x] ~~Preserve partial responses when generation is cancelled or fails.~~
- [x] ~~Synchronize conversation history through Firestore and restore it across~~
  ~~signed-in devices, while retaining Firestore's offline cache behavior.~~
- [x] ~~Show the active connection and model in the conversation view.~~
- [x] ~~Verify offline/error behavior and all application themes.~~

Conversation documents are stored at
`users/{userId}/aiConversations/{conversationId}` with lightweight metadata in
the conversation document and messages in its `messages` subcollection. This
keeps conversation-list reads small, avoids Firestore's per-document size limit
for long chats, and lets message batches use Firestore's offline write queue.
API credentials and provider-internal reasoning are never written to these
documents. User messages are queued locally before generation; assistant
messages are queued once they complete, fail, or are stopped so partial output
can sync without writing every streamed token.

#### Step 5: local phase 1 — validate real chat 🚧

**Remaining work:** ⏸ Deferred until the owner has time and access to the PC
running Ollama.

Validate the existing vertical slice against the owner's real Ollama server
before adding hosted providers or advanced application actions.

> **Why this remains unfinished:** Real Ollama connection testing, model
> discovery, streaming chat, Stop, Retry, and partial-response preservation
> have been exercised by the owner. Conversation restoration and Firestore
> synchronization have also been verified between a phone and a tablet, and
> real-server access works over both the home network and Tailscale. The
> remaining failure-condition and transport checks have not been run and
> recorded systematically. They are intentionally deferred until the owner has
> time and access to the PC running Ollama. Automated development work must not
> contact the owner's real model endpoint unless the owner explicitly requests
> that specific test.

- [x] Verify connection testing and model discovery against Ollama's
  OpenAI-compatible API.
- [x] Verify streaming chat, Stop, Retry, and partial-response preservation
  against a real local model.
- [x] Verify conversation restoration and Firestore synchronization between
  signed-in devices without storing endpoint credentials in Firestore.
- [x] Verify access over the home network and over Tailscale.
- [ ] Exercise model cold start, warm-up delay, endpoint-offline, timeout,
  interrupted-stream, and malformed-response behavior.
- [ ] Improve diagnostics and recovery guidance for any failures discovered by
  real-server testing.
- [ ] Verify Android plain-HTTP behavior for trusted local endpoints and prefer
  Tailscale HTTPS/MagicDNS for remote access.
- [ ] Record the tested Ollama/API versions and model capabilities without
  committing personal URLs, credentials, or conversation content.

#### Step 6: local phase 2 — configuration and reliability hardening

##### Step 6A: generation controls ✅

- [x] Persist reasoning effort, maximum output tokens, connection/start
  timeout, and stream-idle timeout in each connection profile.
- [x] Keep automatic reasoning provider-compatible by omitting the optional
  request field; send an explicit effort only when selected.
- [x] Apply output and timeout limits to model discovery and streamed chat
  requests.
- [x] Show streamed model reasoning in a collapsible, session-only chat panel
  and live during Note-to-Task and Note-to-Event proposal generation, without
  persisting it to Firestore or sending it back to the model.
- [x] Provide bounded editor validation and backward-compatible defaults for
  existing saved profiles.
- [x] Add a bounded, locally stored system prompt per connection profile with
  a concise Nexecute default plus Restore default and Clear controls.
- [x] Send the configured system prompt once before conversation messages on
  every request without persisting it into Firestore conversation history.

Current defaults are automatic reasoning, 1,024 maximum output tokens, a
120-second connection/start timeout, a 90-second stream-idle timeout, and the
concise Nexecute assistant system prompt. A blank profile prompt sends no
system message.

##### Step 6B: remaining reliability and secure access 🚧

> **Why this remains unfinished:** Protocol diagnostics, actionable recovery
> guidance, capability overrides, response normalization, timeout handling,
> native bearer-token storage, and the manual-only generation retry policy are
> implemented. Generation requests are never retried automatically. The
> remaining work needs evidence from real servers before exposing
> model-specific context/warm-up controls or completing broader platform and
> network failure testing.

- [x] Show protocol-default, confirmed-supported, confirmed-unsupported, and
  unconfirmed capabilities for each profile, with editable per-model
  overrides stored in the local connection profile.
- [x] Stop assuming that every OpenAI-compatible model supports tools or
  structured output; treat reasoning, tools, and structured output as
  unconfirmed until explicitly recorded or detected.
- [x] Normalize the common `reasoning`, `reasoning_content`, and `thinking`
  fields without persisting provider reasoning.
- [x] Accept a complete OpenAI-compatible message when a server ignores the
  requested streaming delta format.
- [x] Report empty, malformed, unreachable, timed-out, and HTTP-failed
  responses as actionable normalized failures instead of silently completing.

- [x] Add platform secure credential storage for optional local/private
  endpoint bearer tokens.
- [ ] Add explicit context-window and warm-up settings where the server and
  protocol support them reliably.
- [x] Keep automatic retries away from ambiguous generation requests that may
  already have completed or incurred provider work.
- [x] Add actionable diagnostics for DNS, TLS, CORS, mixed-content, local
  network, authentication, model-missing, and protocol-compatibility failures.
  - [x] Define stable provider-neutral diagnostic categories and an immutable,
    user-safe guidance contract that connection and response failures can
    carry without breaking existing callers.
  - [x] Classify transport, HTTP, timeout, configuration, and response failures
    into those diagnostics without exposing credentials or raw payloads.
  - [x] Present the diagnostics consistently in connection tests, chat, and
    structured proposal workflows.

Bearer tokens are stored on the current Android and macOS clients through
`flutter_secure_storage`; only opaque credential references remain in local
connection-profile metadata. OpenAI-compatible model discovery, connection
tests, and chat resolve the token per request and send it through the
`Authorization` header. Tokens are not copied when profiles are duplicated,
are deleted when replaced, removed, or when their profile is deleted, and are
redacted from endpoint errors. Direct credentials remain disabled on Flutter
Web and on native targets that have not yet received their platform security
configuration. The storage dependency requires at least Android API 23; the
current Flutter toolchain already targets API 24. Android Auto Backup is
disabled so encrypted preferences are not restored without the device-bound
KeyStore key. Configurable API-key headers remain a separate follow-up because
their header-name contract is not yet defined.

#### Step 7: local phase 3 — first confirmed structured action ✅

Start with **Note → proposed tasks** as the first end-to-end application AI
workflow.

##### Step 7A: structured proposal foundation ✅

- [x] Define version 1 as an exact JSON object containing zero to ten one-line
  task titles of at most 200 characters each.
- [x] Build a short extraction prompt that JSON-encodes bounded note title and
  content as untrusted data rather than interpolating them into instructions.
- [x] Parse exact JSON or one JSON code fence and reject extra fields,
  unsupported versions, oversized responses, invalid titles, and duplicate
  tasks with typed, user-safe failures.
- [x] Keep the contract independent from Firestore, `TodoRepository`, and UI
  state so parsing model output can never create tasks by itself.

##### Step 7B: note selection, preview, and model request ✅

- [x] Let the user explicitly select one note and preview exactly what will be
  sent to the model.
- [x] Show the selected connection and model before sending anything.
- [x] Send the dedicated extraction prompt through the active AI connection
  and allow the request to be cancelled.
- [x] Keep extraction outside chat history and Firestore, parse the response
  locally, and stop at a proposal-count confirmation until review UI exists.

##### Step 7C: proposal review ✅

- [x] Present valid proposed tasks with Edit, selection, Create, and Discard
  controls, while keeping review local until the confirmed creation flow.
- [x] Treat malformed, incomplete, and adversarial model output as recoverable
  untrusted input with retry or cancel guidance.

##### Step 7D: confirmed, idempotent creation ✅

###### Step 7D-a: atomic, idempotent repository operation ✅

- [x] Add a validated bulk-creation command with a stable creation ID, source
  note ID, selected titles, and creation timestamp.
- [x] Write all selected tasks through one Firestore batch using deterministic
  document IDs, so retrying the exact command cannot create duplicates or a
  partial set.

###### Step 7D-b: explicit confirmation and creation states ✅

- [x] Show the exact selected titles again and require explicit confirmation
  before writing through `TodoRepository`.
- [x] Freeze the confirmed command, prevent repeated submission, and make an
  uncertain failure retry the exact same idempotent command.

###### Step 7D-c: completed workflow verification ✅

- [x] Preserve the source note, report the creation result, and cover the
  complete workflow with widget and Firestore emulator tests.

#### Step 8: local phase 4 — repeatable quality evaluation ✅

- [x] Create a small, non-personal Finnish and English evaluation set for chat
  and note-to-task extraction.
- [x] Cover simple and multiple tasks, dates, ambiguity, missing information,
  prompt injection inside notes, hallucinations, and malformed structured data.
- [x] Separate transport/application failures from prompt and model-quality
  failures.
- [x] Record results by model and model version so hosted providers can later be
  compared against the same cases.

The version 1 suite contains 30 synthetic bilingual and deterministic cases.
The command-line runner uses the production chat prompt, note-task prompt
builder, endpoint adapter, and strict proposal parser. Reports record the suite,
exact model and model version/tag/digest, generation settings, prompts, output,
usage, and one of four outcomes: passed, transport failure, application
failure, or quality failure. Generated reports remain local and ignored until
reviewed and deliberately selected as safe comparison baselines. The suite can
be validated without endpoint access, and real model runs remain opt-in.

#### Step 9: optional application context and narrow reads ✅

Ship explicit, request-scoped context attachments before model-requested read
tools. Attachments must work with models that have no tool capability. Context
payloads and later tool results remain session-only rather than being copied
into Firestore conversation history; only the ordinary user message and final
assistant response persist.

##### Step 9A: context contract and privacy limits ✅

- [x] Define immutable, provider-neutral version 1 context envelopes for
  selected notes, active tasks, and bounded event ranges.
- [x] Map application models to explicit AI context fields without Firestore
  paths, document IDs, credentials, tags, folders, reminders, or unrelated
  metadata.
- [x] Mark serialized context as untrusted application data and expose field,
  checklist-item, record, and whole-payload truncation through explicit flags
  and omission counts.
- [x] Enforce deterministic limits before any attachment UI or model request is
  added.

Version 1 allows three selected notes, 4,000 content characters per note and
12,000 across notes, 50 checklist items per note, 50 active tasks, 100 events,
a 31-day event range, 300-character general titles, 200-character task titles,
500-character checklist items and event descriptions, and 24,000 characters
for the complete serialized envelope. Selected notes receive priority if the
whole-payload cap requires additional records to be omitted.

##### Step 9B: bounded application read service ✅

- [x] Add a dedicated application-layer service that maps data obtained through
  Nexecute repositories into the Step 9A context types.
- [x] Support bounded `listTasks`, `eventsForDateRange`, `searchNotes`, and
  `getNote` operations without exposing Firebase details to AI infrastructure.
- [x] Validate date ranges, search queries, identifiers, result counts, field
  lengths, and user-selected scope at the application boundary.

The read service accepts an immutable per-request authorization scope and
rejects unauthorized operations before touching a repository. It consumes the
first non-loading repository snapshot, bounds and maps the result locally, and
normalizes unauthenticated, unavailable, timed-out, invalid, and missing-data
failures without exposing underlying Firebase errors. Note search is the same
predictable local text matching used by unified search, excludes trashed notes,
and returns at most three matches. Trusted application-local note IDs are kept
outside the serialized context so a later tool coordinator can replace them
with request-scoped opaque references.

##### Step 9C: explicit one-message attachments ✅

- [x] Let users select notes, active tasks, today's events, or a bounded custom
  event range beside the assistant composer.
- [x] Preview the exact fields and text that will be sent, including truncation
  and omitted-record counts, and allow each attachment to be removed.
- [x] Send attached context as untrusted JSON for one user request, clear it
  after a successful send, and never attach application data automatically.
- [x] Support requests such as planning a day, summarizing a selected note, and
  summarizing unfinished tasks without requiring tool-capable models.

The assistant composer now offers explicit note search, unfinished-task,
today-event, and custom event-range attachments. The visible preview is the
canonical bounded envelope passed to the current chat request; attachments are
removable, remain available if a request cannot start, and clear once the
request starts. The OpenAI-compatible adapter places the envelope immediately
before the current user message with a warning that it is untrusted data, while
the conversation store continues to receive only ordinary user and assistant
messages.

##### Step 9D: provider-neutral read-tool protocol ✅

- [x] Add normalized tool definitions, strict argument schemas, assistant tool
  calls, and tool-result continuation messages to the AI domain.
- [x] Serialize tool definitions and parse fragmented tool-call streams in the
  OpenAI-compatible adapter.
- [x] Advertise read tools only when the active profile has tools explicitly
  confirmed as supported and the user has granted the relevant request scope.

The provider-neutral contract now covers the four bounded reads, fully required
JSON argument schemas with no additional properties, immutable calls and tool
results, and transient assistant/result continuation messages. Read-tool
advertisement requires both an explicit per-profile tools confirmation and a
matching request authorization; protocol defaults alone are insufficient. The
OpenAI-compatible adapter serializes only that filtered catalog, reconstructs
parallel calls whose IDs, names, and JSON arguments arrive across stream
fragments, and normalizes malformed calls as invalid endpoint responses. Tool
execution and continuation-round coordination are supplied separately by Step
9E.

##### Step 9E: authorized read-tool execution ✅

- [x] Validate and execute approved read calls through the Step 9B service,
  return only bounded context results, and continue generation to a final text
  response.
- [x] Bound tool calls, continuation rounds, cumulative result size, timeouts,
  and cancellation while safely rejecting unknown, malformed, excessive, or
  unauthorized requests.
- [x] Keep transient tool calls and results out of conversation persistence and
  leave every application write for Step 10's confirmed-action path.

A request-scoped coordinator now validates exact argument sets and types,
executes only authorized reads through the Step 9B service, returns bounded
context JSON, and feeds transient assistant calls and results into subsequent
model rounds until final text is produced. Search results receive temporary
opaque note references rather than application IDs. A session allows at most
four calls per round, eight calls total, three continuation rounds, 4,000
argument characters per call, 48,000 cumulative result characters, and 30
seconds per read. Unknown, malformed, unauthorized, timed-out, and unavailable
calls become safe tool errors; excessive sessions fail closed. Cancellation
stops the active model response and prevents further continuations. Explicit
Step 9C task, event-range, and selected-note attachments grant only equivalent
request-scoped reads, and neither calls nor results enter conversation storage.

##### Step 9F: completed workflow verification ✅

- [x] Cover exact preview/request equality, opt-in behavior, persistence
  exclusion, offline and failure states, capability fallback, all limits, and
  every application theme.
- [x] Extend the repeatable quality suite with attached-context questions and
  malformed, excessive, unknown, and unauthorized tool-call cases.
- [x] Verify that no request contains Firebase credentials, document paths, or
  application data outside the user's explicit scope.

The completed workflow is covered from repository mapping through the exact
wire request. Widget tests exercise the canonical preview/request equality,
one-message persistence exclusion, explicit opt-in, offline retention, and
non-tool fallback under all four application themes. Boundary and coordinator
tests cover every context and tool-session limit plus normalized read,
transport, timeout, cancellation, and capability failure states. A wire-level
privacy assertion builds context from application records containing synthetic
document paths, IDs, credential-like metadata, and an out-of-scope completed
task, then verifies that none reaches the provider request.

Quality-suite version 1.1.0 adds bilingual attached-task questions and four
deterministic production-coordinator fixtures for malformed, excessive,
unknown, and unauthorized tool calls. The guardrail fixtures run locally,
perform zero endpoint requests and zero application reads, and fail the suite
if a rejected call crosses the authorization boundary.

#### Firebase data and AI tool boundary

- Do not give any model provider Firebase credentials, Firebase user tokens, a
  service account, or unrestricted Firestore access.
- Let the authenticated Nexecute client continue reading and writing Firestore
  through its repositories and the existing user-specific security rules.
- Convert only the relevant records into small, explicit JSON context objects
  before sending them to a model. Exclude fields that are unnecessary for the
  current request.
- Support narrow read tools such as `listTasks`, `eventsForDateRange`,
  `searchNotes`, and `getNote`, executed by the Nexecute client rather than by
  the model or AI server.
- Return tool results to the model so it can reason about the selected data
  without knowing how Firebase is configured.
- Limit reads by date range, search query, result count, and user-selected
  context instead of attempting to place the complete database in the model's
  context window.
- Treat all model output as untrusted. Validate identifiers, dates, field
  lengths, allowed action types, and required values inside Nexecute.
- Represent writes as proposed actions and require confirmation before the app
  calls its normal repositories to create or modify Firestore documents.
- A hosted-provider gateway may verify the signed-in user's Firebase identity,
  but it must not use that identity to provide the model with general Firestore
  access.

#### Step 10: additional structured, confirmed actions

Extend the proven Note → proposed tasks workflow one bounded action at a time.
The first scope is **Note → proposed calendar event**. It proposes at most one
new event from one explicitly selected note and does not let the model select,
edit, move, complete, or delete existing application data.

##### Step 10A: event proposal contract and prompt

- [x] Define a versioned, provider-neutral JSON contract for at most one event
  proposal containing a bounded title and description, local calendar date and
  time fields, end date and time, and an all-day flag.
- [x] Keep tags and reminders out of the model contract initially. Let the user
  select them with trusted Nexecute controls during review.
- [x] Build a dedicated prompt from one explicitly selected, size-bounded note.
  Include the device's reference date, local time, and UTC offset so relative
  dates have explicit context without exposing unrelated application data.
- [x] Require ambiguous or missing dates and times to remain visibly incomplete
  instead of letting the model silently invent required scheduling details.
- [x] Parse the response locally and reject extra fields, unsupported schema
  versions, invalid calendar values, reversed ranges, excessive durations,
  oversized text, and unexpected output outside the allowed JSON envelope.
- [x] Keep Firestore IDs, repository commands, reminder permissions, and write
  decisions outside model output.

##### Step 10B: explicit selection and editable review

- [x] Add a Note action that previews exactly what will be sent and identifies
  the active connection and model before starting the proposal request.
- [x] Present the result in an event-specific review sheet using the application's
  trusted date, time, all-day, tag, and reminder controls.
- [x] Highlight missing or AI-suggested scheduling values and require the user
  to resolve every required field before the draft is ready for confirmation.
- [x] Provide Edit, Retry, Discard, and review-ready states while keeping the
  proposal local and out of chat history and Firestore.

##### Step 10C: confirmed and idempotent event creation

- [x] Turn the review-ready handoff into the final Create confirmation and
  introduce a validated create-event command with a stable creation ID, source
  note ID, frozen reviewed values, and creation timestamp.
- [x] Use a deterministic event document ID so retrying the exact confirmed
  command cannot create a duplicate after an uncertain write result.
- [x] Execute the frozen command through the normal `EventRepository` and event
  reminder scheduling pipeline; model-facing code must never call Firestore or
  platform reminder APIs directly.
- [x] Preserve the source note, prevent repeated submission, and retry only the
  exact same confirmed command after an uncertain failure.

##### Step 10D: verification and rollout

- [x] Cover strict parsing, prompt injection, Finnish and English date phrases,
  missing information, invalid and overnight ranges, all-day events, local time
  changes, and oversized output with deterministic tests.
- [x] Add controller and widget tests for preview, editing, confirmation,
  cancellation, retry, and no-write-before-confirmation behavior.
- [x] Add repository-contract and Firestore Emulator tests for deterministic
  creation, duplicate retries, source-note preservation, and reminder handoff.
- [ ] Validate the bounded workflow against the owner's real Ollama model and
  record quality results before expanding the action set.

Verification on 2026-08-30: `flutter analyze` completed without issues; all 281
deterministic tests passed with the opt-in Ollama smoke test skipped; the Android
repository integration test passed against local Auth and Firestore emulators;
and quality-suite version 1.2.0 validated 37 cases in dry-run mode. The live
Note → Event Ollama run remains intentionally open until an endpoint, model ID,
and immutable model version or digest are supplied to the quality runner.

##### Later Step 10 scopes

- [ ] Consider chat → proposed task, note, or event only after the dedicated
  Note → Event workflow is reliable.
- [ ] Add Task → proposed event and Event → proposed follow-up task as separate
  bounded workflows with their own source previews and schemas.
- [ ] Defer AI-proposed updates, completion, moving, and deletion of existing
  data until creation-only actions are proven. Those operations require explicit
  target selection, current-version checks, conflict handling, and a final
  confirmation showing the exact before-and-after values.

#### Step 11: user-defined prompt skills

Let users create, import, manage, and selectively activate reusable instruction
sets independently from AI connection profiles. The first version is deliberately
prompt-only: a skill may influence how the assistant reasons about and formats a
response, but it cannot provide executable code, implement tools, grant itself
access to application data, or write through an application repository.

Use three distinct lifecycle terms throughout the implementation and interface:

- **Installed** means that the complete skill is stored in Nexecute.
- **Enabled** means that the skill is available for selection.
- **Active** means that its complete instructions are included in the current
  request. Inactive skill bodies must never be added to the model context merely
  because they are installed or enabled.

This separation must allow a user to accumulate hundreds of locally stored
skills without increasing the token cost of ordinary requests. Usually one
primary skill and at most a few compatible supporting skills should be active.

##### Step 11A: skill contract and trust boundary

- [x] Add a versioned, provider-neutral `AiSkill` domain model containing an ID,
  name, description, instruction body, enabled state, output mode, creation and
  update timestamps, and an immutable revision or content hash.
- [x] Keep skills independent from connection profiles so the same skill can be
  used with any compatible endpoint and model.
- [x] Support text output only in version 1. Reserve versioned fields for later
  app-owned tool and structured-output identifiers without accepting arbitrary
  schemas, executors, scripts, network requests, or filesystem access.
- [x] Define conservative domain validation for Unicode, identifiers, names,
  descriptions, timestamps, and instruction size. Permit at least 16,000
  instruction characters so an approximately 11,000-character Finnish language
  skill can be represented intact.
- [x] Apply the contract to UTF-8 `SKILL.md` decoding and reject unknown or
  malformed frontmatter fields during import.
- [x] Treat imported skill instructions as user-authored configuration that may
  refine assistant behavior but can never remove or supersede immutable Nexecute
  policies, request-scoped data authorization, output validation, or confirmed
  write requirements.
- [x] Warn users not to place credentials or secrets in skills when the Step
  11D management interface is added.
- [x] Never copy a skill body into diagnostics, analytics, logs, Firestore
  conversation messages, or tool transcripts.

Suggested version 1 `SKILL.md` representation:

```markdown
---
schemaVersion: 1
id: suomen-kieli
name: Suomen kieli
description: Suomenkielisen tekstin tuottaminen ja tarkistaminen.
outputMode: text
---

Skill instructions begin here.
```

Also accept a body-only Markdown file by asking the user for the missing name
and description during import. Do not interpret links, Markdown includes, paths,
or code blocks as dependencies or executable content.

##### Step 11B: local storage and import/export

- [x] Add an `AiSkillStore` interface and a local implementation designed for
  many multi-kilobyte documents. Do not store the complete catalog as one large
  shared-preferences value; keep a small searchable metadata index separate from
  bounded skill bodies and use atomic replacement for edits and imports.
- [x] Register the store as an optional AI dependency so corrupt or unavailable
  skill storage cannot prevent Calendar, Tasks, Notes, or ordinary AI chat from
  starting.
- [x] Add strict versioned decoding, duplicate-ID conflict handling,
  deterministic filename normalization, and protection against path traversal,
  symbolic-link traversal, and oversized imports.
- [x] Add an ordered metadata-index migration when the first persisted schema
  change is introduced; version 1 migrates to the category-aware index.
- [x] Keep skills local in the first release, matching connection-profile
  privacy. Provide explicit `SKILL.md` import and export before considering a
  synchronized Firestore collection, security rules, conflict resolution, and
  cross-device active-skill semantics.
- [x] Load and search skill metadata without loading every instruction body into
  memory. Load the complete body only for viewing, editing, exporting, or request
  activation.

The version 1 local store uses an atomically replaced JSON metadata index and
separate immutable Markdown bodies addressed by skill ID and content hash. A
body is read only when one skill is requested, and its reconstructed hash must
match the index before it is returned. Full-frontmatter and body-only
`SKILL.md` documents can be decoded and exported through the same bounded codec;
the management interface and platform file picker remain Step 11D work.

##### Step 11C: prompt composition and request semantics

- [x] Introduce one `AiPromptComposer` used by ordinary chat requests. Compose
  instructions in deterministic precedence order: immutable Nexecute policy,
  profile-level preferences, active skill instructions, and trusted
  request-specific workflow constraints.
- [x] Stop using the editable connection-profile prompt as the only system-level
  safety instruction. Preserve backward compatibility by treating existing
  profile prompts as user preferences beneath the immutable policy.
- [x] Add immutable resolved skill invocations to `AiChatRequest`, including the
  skill ID, display name, revision or hash, and validated instruction body.
  Provider adapters should receive only the already composed instruction text.
- [x] Define active skills per conversation, with an explicit option to apply a
  change only to the next request. Persist only the minimal skill IDs and
  revisions needed for interface continuity; never persist instruction bodies
  in Firestore conversation messages or tool transcripts.
- [x] Specify recovery when a synchronized conversation refers to a local skill
  that is missing or has changed on the current device. Show the mismatch and
  require an explicit replacement, import, or skill-free continuation rather
  than silently using different instructions.
- [x] Keep dedicated Note-to-Task, Note-to-Event, and later structured workflows
  on their fixed prompts unless each workflow explicitly defines how a skill can
  participate without weakening its schema and confirmation contract.

Ordinary chat now resolves the conversation's pinned skill IDs and content
hashes against the local store before persisting or sending a user message. The
single prompt composer emits the immutable Nexecute policy first, then
JSON-bounded profile preferences and active skills in deterministic skill-ID
order, followed by optional app-owned workflow constraints. Missing, disabled,
changed, corrupt, or unavailable skill revisions block by default and surface a
body-free recovery result; continuing without skills must be explicit and does
not silently rewrite the conversation's pinned references. A next-request
override remains in memory and is consumed once. Firestore conversation metadata
contains only skill IDs and hashes, while provider adapters serialize only the
already composed instruction string. Dedicated structured Note workflows remain
skill-free.

##### Step 11D: management and activation interface

- [x] Add a Skills area under AI Settings with create, import, inspect, edit,
  duplicate, enable/disable, export, and delete actions.
- [x] Show validation and conflict errors before saving. For a body-only import,
  collect the required metadata without modifying the original instruction body.
- [x] Add an assistant skill picker and persistent active-skill chips near the
  composer. Make the exact active set visible before every request and allow
  individual skills or the complete set to be deactivated quickly.
- [x] Support an optional local default-active set with revision conflict checks,
  but never make newly imported skills active automatically.
- [x] Apply the Step 11E combined prompt budget to the default-active set before
  enabling budgeted multi-skill activation.
- [x] Preview the composed instruction sources and their order without including
  credentials, attached application data, or hidden provider payloads.
- [x] Clearly distinguish an unavailable skill from a disabled or inactive one
  and preserve ordinary chat when skill loading fails.

AI Settings now provides searchable local skill cards, a bounded editor, exact
body inspection, duplication, enable/disable and default controls, confirmed
replacement and deletion, and cross-platform `SKILL.md` import/export. Body-only
imports collect metadata separately and keep the instruction body unchanged;
validation and optimistic conflicts are surfaced before a write. The assistant
shows the effective skill set above the composer, supports conversation or
one-request scope, and labels inactive, disabled, changed, missing, and storage-
unavailable states. Its source-order preview includes only safe metadata, and a
mismatch requires review or an explicit skill-free send. Local default
references contain only IDs and hashes and apply only when starting a new
conversation. Step 11E applies combined prompt-budget enforcement and keeps
multi-skill sets behind an explicit connection opt-in.

##### Step 11E: context budgeting and conflict handling

**Status:** Completed. Conservative byte accounting, explicit context settings,
whole-turn history bounds, category conflicts, and opt-in multi-skill activation.

- [x] Add provider-neutral request-budget accounting before allowing multiple
  active skills. Reserve space for the model output, conversation history,
  attached context, tool continuations, and fixed policy before allocating space
  to skill instructions.
- [x] Add an explicit context-window setting when a trustworthy model-reported
  value is unavailable. Use a conservative fallback for unconfigured models and
  never silently exceed, truncate, or discard an active skill.
- [x] Enforce both a per-skill character limit and a combined active-instruction
  budget. Block sending with actionable guidance when the active set cannot fit.
- [x] Send no inactive skill bodies and avoid sending even the complete skill
  catalog to the model. Initial selection and catalog search should remain local
  and deterministic rather than relying on model-selected automatic activation.
- [x] Add optional skill categories such as language, domain, workflow, and
  output style. Warn about multiple active skills in a mutually exclusive
  category and show their deterministic precedence rather than guessing which
  instruction should win.
- [x] Define a bounded conversation-history policy so a long conversation does
  not eventually crowd out fixed policy and active skills. Make any omission or
  local summary visible instead of silently changing request semantics.

Budgeting uses one token per UTF-8 byte plus explicit framing, output, and
continuation reserves. Unconfigured profiles use an 8,192-token context window;
users must set the actual server context before larger requests. The active
instruction limit is 32,000 characters, with the existing 16,000-character
per-skill limit. Every tool continuation is checked again before transmission.
History includes at most 24 completed messages and starts with a user turn;
omissions are described in the conversation and instruction preview. Nothing
is summarized or truncated to fit. Multi-skill activation is an explicit,
default-off connection setting pending model quality validation. Default sets
are resolved and budgeted on selection and rechecked with every actual request.
Skill schema 2 adds optional categories. Ordered metadata migration preserves
version-1 bodies and hashes, including existing conversation revision pins.
Verification: 231 AI tests passed, including budget boundaries, no-write failure,
whole-turn history, migration, and the existing theme/layout coverage.

##### Step 11F: later tool-aware skills

**Status:** Completed. Versioned app-owned read-capability declarations and
registry dispatch, preserving all existing authorization and execution limits.

- [x] After prompt-only skills are reliable, allow a skill to reference only
  stable, app-owned capability identifiers registered by Nexecute. A skill file
  must never define a tool executor or arbitrary JSON-to-repository binding.
- [x] Generalize the existing read-tool catalog and coordinator into a registry
  whose definitions, validators, executors, limits, and authorization predicates
  remain application code.
- [x] Compute effective tool access as the intersection of the skill allow-list,
  confirmed model capability, explicit per-request user authorization, and
  installed application capability. A skill declaration is never authorization.
- [x] Preserve bounded reads, opaque record references, execution timeouts,
  continuation limits, cancellation, and persistence exclusion for every
  skill-assisted tool session.
- [x] Keep writes outside the skill runtime. Skills may opt into an existing
  app-owned proposal workflow only when its strict parser, editable review,
  explicit confirmation, and idempotent command path already exist.

Skill schema 3 adds a bounded `capabilities` list of `listTasks`,
`eventsForDateRange`, `searchNotes`, and `getNote`. The app-owned registry maps
these IDs to authorization predicates, bounded definitions, and typed executor
branches with strict argument validation. Active declarations form one request
allow-list; prompt-only supporting skills add no capabilities. That list is
intersected with installed registrations, confirmed model support, and explicit
request authorization, both when advertising tools and before each execution.
Skill-free chat retains its existing authorized read workflow. No skill can
register code or a write operation; dedicated proposal workflows remain fixed,
skill-free, and behind their existing editable review and confirmation path.
Ordered index migrations run 1 → 2 → 3 without changing pinned content hashes.
Verification: all 234 AI tests passed and analysis is clean, including capability
intersection, denied-call execution, codec/hash identity, and existing timeout,
cancellation, continuation, and opaque-reference tests.

##### Step 11G: verification and rollout

**Status:** Completed. Deterministic coverage, privacy checks, expanded quality
fixtures, and a version-pinned Ollama validation are complete. Multi-skill use
remains an explicit, default-off connection setting because the tested model did
not reliably follow compatible-skill composition or deterministic conflict
precedence.

- [x] Add domain, codec, migration, store-contract, and import/export tests for
  valid, body-only, malformed, duplicate, unsupported-version, path-traversal,
  and oversized skill files.
- [x] Test prompt precedence, exact wire serialization, multiple active skills,
  deterministic ordering, missing revisions, context-budget boundaries, and
  the exclusion of inactive skill bodies.
- [x] Add controller and widget coverage for management, activation, default
  activation, failed loading, conflict warnings, budget errors, all themes, and
  narrow phone layouts.
- [x] Verify that skill bodies, attached application data, tool transcripts,
  endpoint credentials, and provider reasoning do not enter unintended local or
  Firestore persistence paths.
- [x] Extend the quality suite with a representative long Finnish-language
  skill, conflicting style skills, adversarial imported instructions, chat-only
  models, and tool-capability fallback.
- [x] Validate the feature against the owner's real Ollama model with one large
  language skill and several smaller compatible skills before enabling multiple
  active skills by default.

Quality suite 1.3.0 contains 42 synthetic cases. The five new skill cases use a
11,670-character Finnish-language skill, a compatible three-skill set,
conflicting output-style skills, adversarial instructions, and a declared read
capability without request authorization. Skill-case reports intentionally omit
model output, imported instruction bodies, and provider reasoning.

Live validation on 2026-09-05 used `gemma4-12b:latest`, base-model digest
`072b601e219b7ce375653de33795659b9b6751ad9c64a2afa50c074942d558c5`,
through a temporary alias pinned to a 32,768-token runtime context. Two
repetitions passed the large Finnish-language, adversarial-instruction, and
unauthorized-tool fallback cases. Both repetitions failed exact-output checks
for the compatible multi-skill set and conflicting-style precedence, producing
6 passes and 4 quality failures with no transport or application failures.
These results keep multiple active skills default-off while leaving deliberate
per-connection opt-in available for further model testing.

Verification completed with clean static analysis, all 472 Flutter tests (with
the opt-in smoke test skipped), the 42-case quality-suite dry run, focused
privacy and narrow-layout checks, and a debug APK build. Tests confirm that a
rejected request performs no write, preserves the composer and next-request
skill selection, and reports that nothing was truncated.

Acceptance requires that users can accumulate a large local catalog without
increasing ordinary request size, import and activate the Finnish-language
example intact, see exactly which skills affect a request, and recover cleanly
from conflicts or context limits. Calendar, Tasks, Notes, and skill-free AI chat
must remain usable when skill storage or an imported file is unavailable.

#### Step 12: semantic-search design and prototype

- [ ] Decide whether every device builds its own local embedding index or
  whether versioned embeddings synchronize across devices.
- [ ] Define chunking, model-version, re-indexing, deletion, battery, storage,
  and privacy behavior before selecting a vector database.
- [ ] Support a local embedding model first and keep the embedding provider
  replaceable.
- [ ] Prototype semantic note search only after ordinary search, chat, and
  confirmed structured actions are reliable.

#### Step 13: native hosted-provider BYOK

- [ ] Add platform secure storage for native OpenAI and Anthropic credentials;
  keep only opaque credential references in connection profiles.
- [ ] Add an OpenAI Responses adapter and an Anthropic Messages adapter behind
  the existing normalized repository.
- [ ] Support multiple saved Local, OpenAI, and Anthropic profiles and let the
  user select the active profile without exposing its credential.
- [ ] Use trusted provider endpoint defaults and warn before sending a provider
  key to a customized hostname.
- [ ] Keep paid inference disabled until the user explicitly enables it and
  configures request/token limits and provider-side spending controls.
- [ ] Never request or store provider organization/admin keys merely to inspect
  authoritative billing information.
- [ ] Disable direct hosted-provider credentials on Flutter Web.

#### Step 14: optional user-owned gateway for web

- [ ] Provide a separately deployable personal gateway template rather than a
  central Nexecute provider key.
- [ ] Verify Firebase ID tokens and restrict the gateway to its configured user
  without granting general Firestore access.
- [ ] Store each user's provider keys in their own gateway's server-side secret
  storage.
- [ ] Stream OpenAI and Anthropic through the existing normalized protocol.
- [ ] Document a low-maintenance free-tier deployment path while clearly noting
  that third-party free tiers and availability are not guaranteed.

#### Later AI capabilities

- Answer planning questions such as "What do I have tomorrow?"
- Produce day plans and unfinished-checklist summaries.
- Add intelligent quick capture after structured-action validation is reliable.
- Add note-to-task extraction and other conversion workflows.
- Consider optional conversation export.

#### Connectivity and security

- Treat every local model server and remote provider as an external service with
  its own configuration, authentication, API contract, capabilities, and update
  lifecycle.
- Keep the Flutter web client independently hosted while allowing private model
  endpoints to remain restricted to the home network or Tailscale.
- Prefer a valid Tailscale HTTPS/MagicDNS address so an HTTPS-hosted browser
  client never needs to call a plain HTTP service.
- Configure only the minimum endpoint network origins required by Nexecute and
  verify browser CORS behavior during the web prototype.
- Require a user-owned gateway or a tailnet-hosted same-origin client for hosted
  BYOK use on the web; never place reusable provider keys in browser storage.
- Restrict tailnet access to only the required service ports and devices/users.
- Do not expose an unauthenticated local model-server port directly to the
  public internet.
- Keep native BYOK credentials in platform secure storage with clear extraction
  and device-compromise caveats. Never store them in Firestore or enable them
  in Flutter Web.
- Provide sensible connection timeouts, cancellation, and model warm-up
  feedback.

#### AI assistant acceptance criteria

- The selected AI-service configuration can be tested without starting a
  conversation.
- Responses stream into the interface and can be cancelled.
- Offline or unreachable-server states are understandable and recoverable.
- Application context is opt-in and visible to the user.
- No model-generated action changes user data without confirmation.
- No model provider receives Firebase credentials or unrestricted database
  access.
- Nexecute never supplies a shared provider key or pays for another user's AI
  usage.
- Hosted-provider keys are never stored in Firestore or Flutter Web and paid
  inference remains disabled until explicitly enabled.
- The app's Calendar, Tasks, and Notes remain usable without an AI endpoint.

### Permanent AI memory / user-owned knowledge base

**Status:** Planned

Give the assistant durable, user-owned knowledge that survives conversations,
application restarts, model changes, and device changes. A user should be able
to enter plain text such as:

- "Motorcycle oil change done 14.08.2026 at 21000 km."
- "Front axle: 65 Nm. Axle pinch bolts: 22 Nm."

The connected model should then be able to answer questions such as "When was
the motorcycle oil changed?" or "What is the torque for the front axle?" from
that stored knowledge.

Permanent memory does not mean changing, training, or fine-tuning the model.
Nexecute owns a durable knowledge store, retrieves the small set of records
relevant to the current question, and supplies those records to the selected
model. The stored user record remains the source of truth; an AI response is
only an interpretation of that record.

#### Recommended direction

- Store memory separately from ordinary Notes so casual notes do not silently
  become permanently available to AI. The memory interface may reuse note
  editor components or appear within the Notes area, but it should have its own
  domain model, repository, lifecycle, and AI-access controls.
- Keep the authoritative records under the authenticated user in Firestore so
  they synchronize across devices and retain the existing offline-cache
  behavior.
- Build a derived local search index on each device. The index and any future
  embeddings are disposable and must be rebuildable from the authoritative
  records.
- Start with deterministic lexical search. Add replaceable, local-first
  semantic embeddings later behind the same retrieval interface, coordinated
  with the existing semantic-search roadmap work.
- Support tool-capable and chat-only models. A tool-capable model may refine a
  bounded memory search, while Nexecute must prefetch relevant records for a
  model that cannot call tools.
- Never use a model provider's conversation memory or vector store as the only
  copy of user knowledge. Provider-managed data may be considered only as an
  explicitly enabled derived index in a later design.
- Do not use fine-tuning for user facts. It cannot provide reliable updates,
  deletion, citations, conflict handling, or portability between connection
  profiles.

#### Initial domain model

Organize entries into named spaces so otherwise ambiguous facts can be scoped
to a person, vehicle, home, project, or other subject. For example, "front
axle" must not silently match the wrong motorcycle when a user owns more than
one.

```text
MemorySpace
- id
- name
- createdAt
- updatedAt
- schemaVersion

MemoryEntry
- id
- spaceId
- title
- body
- kind (fact | serviceRecord | referenceDocument)
- occurredAt (nullable)
- tags
- status (active | archived | trashed)
- createdAt
- updatedAt
- schemaVersion
```

Version 1 remains text-first. `occurredAt` is optional metadata for facts such
as maintenance history; the exact user-entered `body` remains authoritative.
Structured specifications, canonical subject keys, imports, attachments, and
relationships between entries can be introduced only after the text workflow
is proven.

#### Retrieval and answer contract

1. The user asks a question while permanent memory is enabled.
2. Nexecute searches only the enabled memory spaces and ranks matching entries
   or document sections locally.
3. Nexecute sends a bounded set of relevant snippets with temporary opaque
   references to the selected model. It does not send the complete library.
4. The model answers from those snippets and identifies the references it used.
5. Nexecute maps the opaque references back to visible, tappable source
   entries without exposing Firestore document paths or application IDs.

Long entries must be divided into deterministic search chunks along headings,
paragraphs, lists, or table rows where practical. Chunks are derived artifacts,
not independent facts. Editing, archiving, trashing, or deleting an entry must
remove every stale chunk before it can appear in another answer.

Memory returned to a model is authoritative for user-specific facts but remains
untrusted as instructions. Pasted content must never override the system
prompt, request authorization, tool schemas, or application rules.

Answer behavior must follow these rules:

- Prefer applicable user memory over the model's general knowledge for
  user-specific facts.
- Show the source entries used for an answer.
- If memory contains conflicting values, show the conflict and relevant dates
  rather than silently choosing one.
- If no relevant record is found, say that the answer was not found in memory.
- Do not silently complete missing safety-critical values from general model
  knowledge.
- Never claim that a memory entry was created, changed, or deleted unless the
  application confirms that operation.

#### Authorization, privacy, and portability

- Permanent memory is disabled until the user explicitly enables it.
- Let users enable or disable individual memory spaces for AI access.
- Show in the Assistant composer when memory retrieval is active and allow it
  to be disabled for one message.
- Keep the selected connection and model visible before memory is transmitted.
- Preview the exact bounded snippets when practical and expose the sources
  used after generation.
- Continue executing Firestore reads inside the authenticated Nexecute client.
  Never give a model provider Firebase credentials, Firebase user tokens, a
  service account, unrestricted collection access, or raw document paths.
- Send only the fields and snippets needed for the current question. Keep
  unrelated entries, tags, internal metadata, and the complete memory library
  out of the provider request.
- Keep lexical indexes, embeddings, and vector databases local first. Define
  explicit consent, deletion, retention, cost, and re-indexing behavior before
  synchronizing derived indexes or sending them to another service.
- Keep the memory format provider-neutral so switching between Ollama, a
  private gateway, OpenAI, Anthropic, or another future adapter does not change
  or lose the user's records.
- Include permanent memory in the future documented export and restore format.

#### Delivery plan

##### Phase 1: contract and storage without AI

- [ ] Define memory terminology, size limits, source precedence, conflict
  behavior, space-level authorization, and the meaning of permanent deletion.
- [ ] Add provider-neutral `MemorySpace` and `MemoryEntry` domain types,
  repository interfaces, Firestore mappers, schema migrations, and
  user-specific security-rule coverage.
- [ ] Build memory-space and entry CRUD, archive/trash behavior, and a
  text-first editor without making an AI endpoint a dependency.
- [ ] Verify Firestore offline behavior and cross-device synchronization before
  connecting memory to the assistant.

##### Phase 2: deterministic local retrieval

- [ ] Define a provider-neutral `MemoryRetrievalService` returning bounded
  snippets and trusted application-local source mappings.
- [ ] Add deterministic chunking and ranked lexical matching over titles,
  bodies, tags, space names, and optional occurrence dates.
- [ ] Set explicit query, entry, chunk, result-count, and complete-payload
  limits before exposing retrieval to AI code.
- [ ] Ensure edits, moves, archive/trash operations, and deletions cannot leave
  stale index results.
- [ ] Verify exact fact lookup, longer torque/reference documents, ambiguous
  spaces, conflicting records, and missing results without contacting a model.

##### Phase 3: bounded Assistant integration

- [ ] Extend the provider-neutral application-context contract with versioned
  memory-search results and opaque source references.
- [ ] Add narrow `searchMemory` and `getMemoryEntry` read tools through the
  existing application read service and tool coordinator rather than granting
  a model direct storage access.
- [ ] Convert the user's durable memory preference into a fresh, bounded
  request authorization for each Assistant message.
- [ ] Prefetch relevant memory for chat-only models and let confirmed
  tool-capable models refine searches within the same authorized spaces and
  limits.
- [ ] Add memory-active, retrieval-preview, source, no-result, conflict, and
  failure states to the Assistant interface.
- [ ] Keep retrieved snippets, tool calls, and tool results out of synchronized
  conversation history; persist only ordinary user and final assistant
  messages under the existing conversation policy.

##### Phase 4: trust and quality verification

- [ ] Add deterministic Finnish and English cases for service history,
  tightening torques, paraphrased questions, long entries, ambiguous subjects,
  conflicting facts, missing facts, and irrelevant matches.
- [ ] Test prompt injection embedded in memory, malformed or excessive tool
  calls, unauthorized spaces, stale entries, and fabricated citations.
- [ ] Add wire-level assertions proving that disabled or unrelated memory,
  Firestore paths, credentials, application IDs, and complete-library dumps do
  not reach the provider.
- [ ] Verify the workflow with both a real chat-only model and a confirmed
  tool-capable model before enabling permanent retrieval by default for an
  opted-in user.

##### Phase 5: local semantic retrieval

- [ ] Select a replaceable local embedding provider only after the lexical
  retrieval contract and evaluation baseline are stable.
- [ ] Version embeddings by model, chunking contract, and source revision so
  incompatible or stale vectors are deterministically rebuilt.
- [ ] Define per-device storage, battery, background work, deletion, and full
  re-index behavior before selecting a vector database.
- [ ] Combine lexical and semantic candidates behind `MemoryRetrievalService`
  without changing the model-facing context contract.
- [ ] Measure semantic retrieval against the deterministic baseline and retain
  lexical fallback when an embedding model or index is unavailable.

##### Later memory capabilities

- [ ] Add an explicit "Remember this" flow that produces an editable proposal
  and requires confirmation before writing through the memory repository.
- [ ] Consider structured maintenance records and specifications only after
  text entries are reliable; preserve the original source text alongside any
  extracted fields.
- [ ] Add user-reviewed supersession or replacement of outdated facts rather
  than letting the model silently overwrite existing entries.
- [ ] Consider imports from Markdown, manuals, and other documents after text
  entry limits, chunking, provenance, and deletion semantics are established.
- [ ] Defer automatic fact extraction from conversations and background
  profiling until explicit capture, privacy, and correction workflows are
  proven.

#### Permanent-memory acceptance criteria

- A stored oil-change fact survives restart, offline use, and cross-device
  synchronization and answers with the recorded date and mileage.
- A question about front-axle torque returns the exact stored value and a
  visible source entry.
- The same memory library works when the active AI connection or model changes.
- A chat-only model and a tool-capable model can both use bounded memory.
- Disabling permanent memory or an individual space prevents its content from
  reaching the provider.
- Editing, archiving, trashing, or deleting an entry changes subsequent
  retrieval immediately and leaves no stale result.
- Conflicting entries are surfaced with their sources and dates rather than
  resolved by guessing.
- Missing information is reported as absent from memory, and safety-critical
  values are not invented.
- Memory content cannot override system instructions, authorization, tool
  limits, or application write confirmation.
- No provider receives Firebase credentials, raw document paths, unrestricted
  database access, unrelated records, or the complete memory library.
- Calendar, Tasks, Notes, memory CRUD, and ordinary search remain usable when
  every AI endpoint and embedding provider is unavailable.

### Today dashboard and universal quick capture

**Status:** Deferred

The Today dashboard is not currently expected to fit the owner's workflow.
Universal quick capture can be reconsidered independently later.

- Consider a focused Today view containing today's events, active or due
  tasks, and pinned or recent notes.
- Optionally add an AI-generated daily summary after the assistant integration is
  reliable.
- Add a universal quick-capture input that can create an Event, Task, or Note.
- Let the user choose the item type manually; AI classification must remain an
  optional convenience.

### Task enhancements

**Status:** Deferred

Task due dates and Today/Upcoming/Overdue groupings are intentionally deferred
because the current undated task workflow better matches the owner's needs.

- Add optional due dates before introducing more complex task organization.
- Add Today, Upcoming, and Overdue groupings.
- Add Android notifications and useful notification actions.
- Allow a task to be converted into or linked to a calendar time block.
- Consider priorities, subtasks, recurrence, and projects only after the basic
  due-date workflow is proven useful.

### Unified search

**Status:** Completed

- [x] ~~Search events, tasks, notes, tags, and checklist contents from one~~
  ~~dedicated screen.~~
- [x] ~~Begin with predictable text-based matching while preserving the~~
  ~~existing Notes-tab filter as a separate interaction.~~

Event search performs a debounced, one-shot read only while the Search screen
is in use, filters locally, and caps returned matches. It does not restore the
removed application-wide live event-history stream.

- Consider local embeddings and semantic search as a later enhancement.

### Linked items

**Status:** Candidate

- Support links between notes, tasks, and events without deleting the source
  item.
- Display relationships and backlinks such as "Created from note."

### Android-focused improvements

**Status:** Candidate

- Add a home-screen widget for today's tasks and events.
- Add launcher shortcuts for quick task, note, and event creation.
- Accept shared text from other Android applications as a new note.
- Add notification actions for completing or postponing tasks.
- Consider optional Android system-calendar integration.

### Calendar usability

**Status:** Completed

- [x] ~~Show ISO week numbers in the month view, with a persisted setting to~~
  ~~show or hide the week-number column.~~
- [x] ~~Lay out the week view as an hourly time grid and position timed events~~
  ~~according to their start time and duration. The full 24-hour timeline fits~~
  ~~the available height without vertical scrolling.~~

### Notes usability

**Status:** Completed

- [x] ~~Focus a newly added checklist item immediately so typing can continue~~
  ~~without another tap.~~
- [x] ~~Turn Notes into a lightweight personal knowledge base with a permanent~~
  ~~Quick Notes inbox, All Notes, and user-created flat folders.~~
- [x] ~~Allow notes to be assigned or moved to a folder while tags continue to~~
  ~~work across folders. Deleting a folder safely returns its notes to Quick~~
  ~~Notes.~~

### Export and data ownership

**Status:** Candidate

- Export notes as Markdown.
- Export events as ICS.
- Export and restore all application data as a documented JSON format.
- Add a clear account-and-data deletion workflow.

## Technical roadmap

These improvements should be considered before or alongside larger features.

### Firestore read scalability and local-cache plan

The current Firestore usage does not indicate that queries are being created
from ordinary widget `build` methods. Repository streams are owned by Provider,
and Calendar creates its stream outside `build`. The larger scaling risk is the
scope and lifetime of the queries: Notes and Tasks currently subscribe to their
complete collections, Calendar is mounted even when another primary tab is
visible, and a visited desktop Assistant remains subscribed to its conversation
list and current conversation while hidden.

Firestore's native persistent cache is already enabled by default on Android
and Apple platforms. It improves offline and warm-start behavior, but it is not
a substitute for bounded queries: each device has its own cache, and a listener
that has been disconnected long enough can be billed as a new query. Web
persistence must be enabled separately and only on a trusted-device basis.

The approximate current cold-session read shape is:

```text
all notes
+ all tasks
+ all note folders
+ visible-range events
+ all recurring event series
+ tags when first consumed
+ all AI conversation summaries when Assistant is opened
+ all messages in the latest conversation
```

This explains why repeated launches across several devices can produce read
bursts proportional to the user's stored document count without requiring a
listener leak. After a listener's initial result, ordinary real-time updates
normally read only changed matching documents; cold synchronization, broad
queries, duplicate subscriptions, and long-lived hidden screens are the main
targets. The Firestore 50,000 daily read figure is a no-cost allowance rather
than a technical database ceiling, but Nexecute should not make each session's
cost grow with the user's complete history.

#### Step 1: establish a reproducible read baseline

- [x] Add debug-only diagnostics for repository/query name, listener attach and
  detach, active-listener count, initial result size, cache/server metadata, and
  added, modified, and removed document counts. Never log document content,
  credentials, private URLs, or other user data. The operation catalog and
  controlled measurement procedure are recorded in
  `docs/firestore_read_baseline.md`.
- [ ] Measure fresh install, warm relaunch, relaunch after a long disconnect,
  navigation between every primary destination, first Assistant visit, repeated
  search terms, and synchronization between three devices.
- [ ] Keep Firebase Console collection browsing out of measurement windows
  because console activity can contribute reads.
- [ ] Record baselines for small realistic data and generated large fixtures so
  later changes can be compared against the same workload.

#### Step 2: remove unnecessary and duplicate subscriptions

- [ ] Instantiate only the selected primary tab at startup. Preserve necessary
  view state separately so Calendar and Tasks do not need live listeners merely
  to keep their UI positions available.
- [ ] Dispose or suspend expensive screen-owned listeners while their screen is
  inactive. In particular, a desktop Assistant that has been visited must not
  keep its conversation and message listeners active indefinitely while hidden.
- [ ] Give launcher-widget reconciliation a dedicated current-week event query
  instead of relying on the larger visible Calendar query being permanently
  mounted.
- [ ] Introduce a session-scoped application-data snapshot/cache so Assistant
  attachments and read tools reuse already-loaded Notes and Tasks rather than
  opening fresh repository subscriptions for each request.
- [ ] Reuse identical active queries through one owned subscription and replay
  their latest typed `DataState` to consumers.
- [ ] Avoid reading the complete event collection for every settled search term.
  At minimum, load it no more than once per search session, cache repeated
  queries, and require an intentional or sufficiently stable search input.

Target: launching into Notes performs no Task, Calendar, AI-conversation, or
AI-message reads, and hidden screens have no expensive active listeners.

#### Step 3: bound every collection that grows with history

- [ ] Replace `watchNotes()` as the universal complete-library stream with
  location-aware queries for Quick Notes, a folder, All Notes, and Archive.
  Filter by `trashed` and `folderId`, order by `updatedAt`, apply a fixed page
  size, and load further pages with cursors rather than offsets.
- [ ] Replace the combined active/completed Task stream with a bounded active
  Task listener. Load completed Tasks only when requested and paginate their
  history.
- [ ] Limit the live AI conversation-summary query to the newest page and add
  cursor pagination for older conversations.
- [ ] Limit an active conversation to its newest message page and load older
  messages when the user scrolls upward. Avoid listening to the same active
  conversation metadata through both the summary list and a second document
  listener where one source can safely be reused.
- [ ] Exclude recurring events from the ordinary overlap query on the server so
  an in-range recurring series is not read by both Calendar queries and then
  discarded client-side. Backfill or safely migrate legacy `isRecurring`
  values before depending on the filter.
- [ ] Add a bounded lifetime/status strategy for recurring series so obsolete
  series do not remain in the recurring query forever.
- [ ] Load exact folder and location counts on demand through cached aggregation
  queries, or remove exact always-live counts, rather than loading note bodies
  merely to count them.
- [ ] Add and deploy the composite indexes required by the bounded Note, Task,
  Calendar, and pagination queries before switching production code to them.

Target: a cold screen load is proportional to its page size and current working
set, not to all documents the user has created over the lifetime of the account.

#### Step 4: optional future local search/index layer

Only consider this step if measurements show that bounded Firestore queries and
native persistence are insufficient, or if complete offline full-text search
across thousands of records becomes a firm product requirement.

- [ ] Evaluate a small SQLite/Drift full-text index for Notes, Tasks, and Events;
  do not add another local database solely because Firestore has a free-tier
  allowance.
- [ ] If adopted, define an initial paginated bootstrap followed by incremental
  synchronization using stable per-user cursors.
- [ ] Introduce tombstones or an equivalent change log before relying on delta
  synchronization, so deletions made on another device cannot be missed.
- [ ] Specify conflict resolution, retry/outbox behavior, account switching,
  sign-out data removal, schema migration, corruption recovery, and a forced
  full-resynchronization path.
- [ ] Keep Firestore authoritative and ensure the local index never exposes one
  user's data to another authenticated account on a shared device.

This is intentionally optional future work. Do not build a second synchronization
engine unless the simpler query and lifecycle improvements have been measured
and found inadequate.

#### Step 5: verification and operating guardrails

- [ ] Add repository and widget tests proving that rebuilds do not attach new
  Firestore listeners, navigation releases inactive listeners, and Assistant
  read tools reuse session data.
- [ ] Add pagination contract tests covering stable ordering, equal timestamps,
  deletions between pages, empty pages, offline cache results, and authentication
  changes.
- [ ] Exercise an account with at least 10,000 historical documents and confirm
  that startup, navigation, memory use, and read counts remain bounded.
- [ ] Verify that writes still occur only for explicit user mutations. Preserve
  the intentional two-write AI-message operation (message plus conversation
  `updatedAt`) unless evidence shows that the ordering write is a material cost.
- [ ] Configure usage dashboards, budget alerts, and release comparison notes so
  regressions are detected before public or invited-user growth.

Acceptance criteria:

- Cold launch into Notes reads only the first relevant Note page and lightweight
  metadata needed by that screen.
- Hidden screens have no expensive active listeners.
- Opening Assistant reads at most one bounded conversation page and one bounded
  message page.
- Typing several search characters does not trigger several complete collection
  reads.
- Warm relaunches display cached state immediately and synchronize changes
  without presentation-level duplicate listeners.
- Read cost remains bounded as historical Notes, completed Tasks, Events, and AI
  conversations grow.

### High priority

- [x] ~~Split `FirestoreService` into injected repositories for events, notes,~~
  ~~tasks, tags, and the legacy count feature. Register the repository interfaces~~
  ~~with Provider and migrate callers away from constructing Firestore services~~
  ~~directly.~~
- [x] ~~Add an independent assistant repository when AI work begins. Its~~
  ~~interface must not depend on provider-specific response types.~~
- [x] ~~Query calendar events by a bounded visible range instead of maintaining~~
  ~~one live stream containing the user's complete event history. Month and week~~
  ~~views now include one adjacent `PageView` page in each direction as a swipe~~
  ~~buffer, preserve overlapping multi-day events, and use the deployed composite~~
  ~~index tracked in `firestore.indexes.json`.~~
- [x] ~~Represent loading, empty, authentication, and error states separately~~
  ~~rather than converting stream failures into empty lists. Authenticated~~
  ~~repository streams now publish typed `DataState` values, and calendar, tasks,~~
  ~~notes, tags, trash, count, and editor surfaces render those states explicitly.~~
- [x] ~~Initialize Firebase through one clearly owned application startup path.~~
- [x] ~~Add Firestore Emulator tests for repository behavior and security rules.~~
- [x] ~~Optimize Firestore read, write, and deletion costs across AI chats and~~
  ~~calendar events. AI conversation metadata stays lightweight while messages~~
  ~~use an offline-compatible subcollection, and chat initialization reuses one~~
  ~~conversation-list subscription. Unnecessary `get()` queries prior to~~
  ~~calendar event deletions have also been removed.~~

### Maintainability cleanup

- [x] ~~Split the large item editor and note-item widgets into smaller focused~~
  ~~components.~~
- [x] ~~Remove the unused legacy calendar implementation after confirming that the~~
  ~~current calendar contains all required behavior.~~
- [x] ~~Remove prototype code and unused dependencies, including unused state~~
  ~~providers and state-management packages.~~
- [x] ~~Inject Firestore-backed repositories rather than constructing services~~
  ~~directly inside widgets.~~
- [x] ~~Standardize on one state-management approach and remove unused alternatives.~~
- [x] ~~Move Firestore serialization concerns out of domain models where practical.~~
- [x] ~~Replace loosely typed update methods with typed parameters or command~~
  ~~objects.~~
- [x] ~~Introduce an explicit data schema version and migrations before models gain~~
  ~~substantially more fields.~~
- [x] ~~Require Flutter 3.44 or newer so Android builds include the upstream~~
  ~~virtual-keyboard modifier fix that prevents ordinary cursor taps from~~
  ~~becoming stuck range selections after Gboard Shift input.~~
- [x] ~~Align Android builds with the Flutter 3.47 template using Gradle 9.3,~~
  ~~Android Gradle Plugin 9.1, and Kotlin 2.4.~~
- [x] ~~Migrate the Android app and its plugins from the legacy Kotlin Gradle~~
  ~~Plugin to AGP 9's built-in Kotlin support.~~

### Quality and accessibility

Release distribution, signing documentation, and store-oriented hardening are
deferred while Nexecute remains a personal-only application. Functional
testing and accessibility checks remain relevant.

- Add end-to-end Android tests for authentication and the main creation flows.
- Check text scaling, screen-reader labels, touch-target sizes, and theme
  contrast across the primary pages.
- Replace remaining development-only messages, prints, placeholder screens,
  and inconsistent terminology.
- Update the project README with setup, Firebase, Android signing, and release
  build instructions.
