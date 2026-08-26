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

## Future roadmap

The application should continue developing as a focused personal productivity
tool built around Calendar, Tasks, and Notes. New functionality should connect
these areas without making the core workflows dependent on AI or a permanent
network connection.

### Cross-platform laptop access

**Status:** Proposed

Provide access to the same Firestore-backed Calendar, Tasks, Notes, and Tags
from laptop-sized devices without creating a second synchronization system.
All clients should continue using the same authenticated, user-specific
Firestore data.

#### Recommended rollout

1. Refactor application startup and services so they are not Android-only.
2. Add an adaptive application shell shared by all platforms.
3. Configure Firebase and Google authentication for Flutter Web.
4. Deploy a private first web release and verify all core workflows.
5. Add installable PWA behavior and desktop keyboard shortcuts.
6. Enable macOS as a native target later, reusing the adaptive interface.
7. Defer native Linux until its Firebase data and authentication approach can
   be supported without fragile third-party dependencies.

#### Web application

- Use Flutter Web as the first laptop client so macOS, Linux, and Windows can
  use the same release.
- Treat the web build as a static client; it does not require a continuously
  running custom application server when deployed to managed static hosting.
- Prefer Firebase Hosting for the main client so Calendar, Tasks, and Notes
  remain available even when the home AI PC is offline.
- Configure the web Firebase application, authorized authentication domains,
  Google sign-in flow, branding, icons, and PWA manifest.
- Keep Firebase Authentication and Firestore security rules as the authority
  for access to user data.
- Optionally host the static web build privately through the home PC and
  Tailscale if a tailnet-only application is preferred later. This makes the
  home PC an availability dependency and is not the initial recommendation.

#### macOS application

- Consider macOS as the second laptop target when native integration becomes
  valuable.
- Reuse the responsive Flutter widgets and repositories rather than creating a
  separate desktop application.
- Configure the macOS Firebase application, Google sign-in, entitlements,
  signing, packaging, and release process.
- Use the native target for capabilities such as direct local-network access,
  richer notifications, menu-bar actions, file integration, and global
  shortcuts.
- Decide later whether personal builds are installed manually or require an
  application update mechanism.

#### Linux application

- Continue supporting Linux laptops through the web client initially.
- Do not depend on a native Linux release until the official Firebase plugin
  support needed by Nexecute is sufficient or the data layer has a deliberate
  REST/backend implementation.

#### Adaptive desktop interface

- Preserve bottom navigation on compact phone layouts.
- Use a `NavigationRail` or persistent sidebar on medium and wide layouts.
- Allow the calendar and selected-day agenda/details to appear side by side.
- Increase the Notes masonry-grid column count based on available width.
- Consider list-and-detail layouts for Tasks and Notes.
- Add keyboard shortcuts for creation, search, navigation, save, and close.
- Add appropriate hover states, right-click menus, focus traversal, and desktop
  spacing.
- Support freely resizable windows instead of assuming phone dimensions.

#### Cross-platform acceptance criteria

- The same Google account sees the same data on Android and the laptop client.
- Core Calendar, Tasks, and Notes workflows work at phone and desktop widths.
- Navigation adapts without maintaining separate feature implementations.
- The web client remains useful when the home AI server is unreachable.
- Authentication and Firestore rules protect data on every target.

### Local AI assistant / intelligent quick capture

**Status:** Proposed

Connect the app to the self-hosted AI services on the dedicated home PC and
provide an assistant that can work across Calendar, Tasks, and Notes. The PC
runs Ollama and the ready-made Odysseus AI workspace created by PewDiePie;
Nexecute does not own or control Odysseus's FastAPI implementation. Odysseus is
not part of the initial integration: the existing installation primarily
confirms that secure remote access to the AI PC already works through
Tailscale. The goal is an action-oriented assistant rather than a standalone
generic chatbot.

Example requests:

- "Remind me to renew my insurance next Friday."
- "Schedule gym on Monday, Wednesday, and Friday at 18:00."
- "Turn this note into three tasks."
- "Summarize my unfinished checklist."
- "What do I have planned tomorrow?"

#### Phase 1: basic AI chat

- Integrate directly with Ollama through the existing private Tailscale route.
- Keep Odysseus independent unless a future feature specifically benefits from
  its agents, memory, documents, or research workflow.
- Do not depend on Odysseus's internal routes or patch its FastAPI application
  as part of Nexecute.
- Add the Ollama service URL and available model selection to Settings.
- Add a connection test and clear online, connecting, and unavailable states.
- Provide a full-screen conversation view with streaming responses.
- Allow an in-progress response to be stopped and a failed response retried.
- Store conversation history locally by default.
- Keep the rest of the app fully usable when the Ollama server is unavailable.
- Initially expose the assistant through the app bar or drawer rather than
  adding a fourth bottom-navigation destination.

#### Phase 2: optional application context

- Let the user explicitly attach selected notes, active tasks, today's events,
  or another clearly defined date range to a conversation.
- Clearly show which application data will be sent to the model.
- Support useful read-only actions such as planning a day, summarizing a note,
  or finding unfinished checklist items.
- Avoid automatically sending the user's complete Firestore data to the model.

#### Firebase data and AI tool boundary

- Do not give Ollama Firebase credentials, Firebase user tokens, a service
  account, or unrestricted Firestore access.
- Let the authenticated Nexecute client continue reading and writing Firestore
  through its repositories and the existing user-specific security rules.
- Convert only the relevant records into small, explicit JSON context objects
  before sending them to Ollama. Exclude fields that are unnecessary for the
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
- Keep a possible server-side AI adapter as a later scalability option, not an
  MVP requirement. Do not place a Firebase Admin service account on the AI PC
  for the initial implementation.

#### Phase 3: structured, confirmed actions

- Let the model propose a new task, note, or calendar event.
- Present proposed actions as preview cards with Create, Edit, and Discard
  options.
- Support note-to-task, task-to-event, and event-to-follow-up-task proposals.
- Require explicit user confirmation before creating, editing, completing,
  moving, or deleting application data.
- Keep model output separate from trusted application operations and validate
  every structured action before executing it.

#### Connectivity and security

- Use the existing dedicated home AI PC, which runs Ollama and the ready-made
  Odysseus workspace and is reachable through the home network and Tailscale.
- Treat Ollama and Odysseus as externally maintained services with their own
  configuration, authentication, API contracts, and update lifecycle.
- Keep the Flutter web client independently hosted while exposing Ollama
  privately through Tailscale.
- Prefer a valid Tailscale HTTPS/MagicDNS address so an HTTPS-hosted browser
  client never needs to call a plain HTTP service.
- Configure only the minimum Ollama network origins required by Nexecute and
  verify browser CORS behavior during the web prototype.
- If a stable and secure direct web integration is not available, choose
  between a separate Nexecute-owned adapter or a tailnet-hosted same-origin web
  client as an explicit architecture decision.
- Restrict tailnet access to only the required service ports and devices/users.
- Do not expose an unauthenticated Ollama port directly to the public internet.
- Store native-client endpoint credentials in platform secure storage, not
  Firestore or plain shared preferences. Do not embed a reusable API secret in
  the web client. Rely on tailnet access for direct Ollama requests; if a
  Nexecute-owned adapter is introduced later, authenticate it with the
  signed-in user's verified Firebase identity.
- Provide sensible connection timeouts, cancellation, and model warm-up
  feedback.
- Treat all AI services as optional: Calendar, Tasks, Notes, authentication,
  and Firestore synchronization must not depend on the home PC being online.

#### AI assistant acceptance criteria

- The selected AI-service configuration can be tested without starting a
  conversation.
- Responses stream into the interface and can be cancelled.
- Offline or unreachable-server states are understandable and recoverable.
- Application context is opt-in and visible to the user.
- No model-generated action changes user data without confirmation.
- Ollama never receives Firebase credentials or unrestricted database access.
- The app's Calendar, Tasks, and Notes remain usable without Ollama.

### Today dashboard and universal quick capture

**Status:** Candidate

- Consider a focused Today view containing today's events, active or due
  tasks, and pinned or recent notes.
- Optionally add an AI-generated daily summary after the Ollama integration is
  reliable.
- Add a universal quick-capture input that can create an Event, Task, or Note.
- Let the user choose the item type manually; AI classification must remain an
  optional convenience.

### Task enhancements

**Status:** Candidate

- Add optional due dates before introducing more complex task organization.
- Add Today, Upcoming, and Overdue groupings.
- Add Android notifications and useful notification actions.
- Allow a task to be converted into or linked to a calendar time block.
- Consider priorities, subtasks, recurrence, and projects only after the basic
  due-date workflow is proven useful.

### Unified search and linked items

**Status:** Candidate

- Search events, tasks, notes, tags, and checklist contents from one place.
- Begin with predictable text and filter-based search.
- Consider local Ollama embeddings and semantic search as a later enhancement.
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

### Export and data ownership

**Status:** Candidate

- Export notes as Markdown.
- Export events as ICS.
- Export and restore all application data as a documented JSON format.
- Add a clear account-and-data deletion workflow.

## Technical roadmap

These improvements should be considered before or alongside larger features.

### High priority

- [x] ~~Split `FirestoreService` into injected repositories for events, notes,~~
  ~~tasks, tags, and the legacy count feature. Register the repository interfaces~~
  ~~with Provider and migrate callers away from constructing Firestore services~~
  ~~directly.~~
- Add an independent assistant repository when AI work begins. Its interface
  must not depend on Odysseus or Ollama-specific response types.
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
- Introduce an explicit data schema version and migrations before models gain
  substantially more fields.

### Quality and accessibility

- Add end-to-end Android tests for authentication and the main creation flows.
- Check text scaling, screen-reader labels, touch-target sizes, and theme
  contrast across the primary pages.
- Replace remaining development-only messages, prints, placeholder screens,
  and inconsistent terminology.
- Update the project README with setup, Firebase, Android signing, and release
  build instructions.
