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

Conversation metadata is stored at
`users/{userId}/aiConversations/{conversationId}` and each message at
`users/{userId}/aiConversations/{conversationId}/messages/{messageId}`. API
credentials and provider-internal reasoning are never written to these
documents. User messages are stored before generation; assistant messages are
stored once they complete, fail, or are stopped so partial output can sync
without writing every streamed token.

#### Step 5: local phase 1 — validate real chat 🚧

Validate the existing vertical slice against the owner's real Ollama server
before adding hosted providers or advanced application actions.

> **Why this remains unfinished:** The local chat implementation and its fake
> server tests exist, and the owner has exercised parts of the flow manually,
> but the complete checklist below has not been run and recorded systematically
> against the real Ollama server, multiple signed-in devices, home-network and
> Tailscale access, and the listed failure conditions. Automated development
> work must not contact the owner's real model endpoint unless the owner
> explicitly requests that specific test.

- [ ] Verify connection testing and model discovery against Ollama's
  OpenAI-compatible API.
- [ ] Verify streaming chat, Stop, Retry, and partial-response preservation
  against a real local model.
- [ ] Verify conversation restoration and Firestore synchronization between
  signed-in devices without storing endpoint credentials in Firestore.
- [ ] Verify access over the home network and over Tailscale.
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
  without persisting it to Firestore or sending it back to the model.
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

> **Why this remains unfinished:** Basic protocol diagnostics, capability
> overrides, response normalization, and timeout handling are implemented. The
> remaining work either needs platform secure-storage integration, evidence
> from real servers before exposing model-specific context/warm-up controls, or
> broader platform and network failure testing. Retry behavior also needs a
> deliberate policy because automatically repeating an ambiguous generation
> could duplicate work or incur provider usage later.

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

- [ ] Add platform secure credential storage for optional local/private
  endpoint tokens.
- [ ] Add explicit context-window and warm-up settings where the server and
  protocol support them reliably.
- [ ] Keep automatic retries away from ambiguous generation requests that may
  already have completed or incurred provider work.
- [ ] Add actionable diagnostics for DNS, TLS, CORS, mixed-content, local
  network, authentication, model-missing, and protocol-compatibility failures.

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

The version 1 suite contains 24 synthetic bilingual cases. The command-line
runner uses the production chat prompt, note-task prompt builder, endpoint
adapter, and strict proposal parser. Reports record the suite, exact model and
model version/tag/digest, generation settings, prompts, output, usage, and one
of four outcomes: passed, transport failure, application failure, or quality
failure. Generated reports remain local and ignored until reviewed and
deliberately selected as safe comparison baselines. The suite can be validated
without endpoint access, and real model runs remain opt-in.

#### Step 9: optional application context and narrow reads

- [ ] Let the user explicitly attach selected notes, active tasks, today's
  events, or another clearly defined date range to a conversation.
- [ ] Preview exactly which application data will be sent to the model.
- [ ] Represent attached context as small, typed objects and omit unnecessary
  fields.
- [ ] Cap records, date ranges, search results, and field lengths.
- [ ] Support useful read-only requests such as planning a day, summarizing a
  note, or finding unfinished checklist items.
- [ ] Never automatically send the user's complete Firestore data.

- [ ] Support bounded `listTasks`, `eventsForDateRange`, `searchNotes`, and
  `getNote` operations through Nexecute repositories.
- [ ] Return only bounded tool results to the model without exposing Firebase
  configuration or credentials.
- [ ] Enforce limits by date range, search query, result count, and
  user-selected context.

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

- [ ] Let the model propose a new task, note, or calendar event.
- [ ] Present proposed actions as preview cards with Create, Edit, and Discard
  options.
- [ ] Support note-to-task, task-to-event, and event-to-follow-up-task proposals.
- [ ] Treat all model output as untrusted and validate identifiers, dates, field
  lengths, allowed action types, and required values inside Nexecute.
- [ ] Require explicit user confirmation before creating, editing, completing,
  moving, or deleting application data.
- [ ] Keep model output separate from trusted application operations and execute
  confirmed writes through the existing repositories.

#### Step 11: semantic-search design and prototype

- [ ] Decide whether every device builds its own local embedding index or
  whether versioned embeddings synchronize across devices.
- [ ] Define chunking, model-version, re-indexing, deletion, battery, storage,
  and privacy behavior before selecting a vector database.
- [ ] Support a local embedding model first and keep the embedding provider
  replaceable.
- [ ] Prototype semantic note search only after ordinary search, chat, and
  confirmed structured actions are reliable.

#### Step 12: native hosted-provider BYOK

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

#### Step 13: optional user-owned gateway for web

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
