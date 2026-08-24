# Nexecute Roadmap

## Tasks / to-do list

**Status:** Completed

Add a deliberately simple, user-specific task list alongside Calendar and
Notes (Quicxecs).

### Version 1 scope

- Add a task with a required title.
- Edit an existing task's title.
- Mark a task as completed or active.
- Delete a task, with an Undo snackbar where practical.
- Keep completed tasks in the app.
- Hide completed tasks by default inside a collapsed `Completed (n)` section.
- Allow completed tasks to be expanded, viewed, and restored to the active
  list.
- Persist tasks under the authenticated user in Firestore.
- Support all application themes.

Not included in version 1: descriptions, tags, priorities, due dates,
subtasks, manual ordering, or task-to-event conversion.

### Navigation and appearance

- Replace the custom two-page bottom bar and center-notched Add button with a
  Material 3 `NavigationBar`.
- Use three labeled destinations: **Calendar**, **Tasks**, and **Notes**.
- Add a context-aware floating action button at the bottom-right:
  `+ Event`, `+ Task`, or `+ Note`.
- Show active tasks as a clean checkbox list rather than note-style cards.
- Show completed tasks with strikethrough text and reduced opacity.
- Preserve each page's state while moving between destinations.

### Data model

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

- Stream the current user's tasks.
- Add a task.
- Edit a task title.
- Set completed/active state.
- Delete a task.

### Implementation checklist

- [x] Refactor the app shell to the three-destination `NavigationBar`.
- [x] Add the context-aware floating action button.
- [x] Add the `TodoItem` model and Firestore serialization.
- [x] Add task stream and CRUD operations.
- [x] Register the task stream provider.
- [x] Build the active task list and empty state.
- [x] Build the collapsed completed-task section.
- [x] Add the task creation and editing sheet.
- [x] Add completion, restoration, deletion, and Undo interactions.
- [x] Verify Firestore security rules for the `todos` collection.
- [x] Add model, interaction, persistence, and navigation tests.
- [x] Verify the page under Cyberpunk, Midnight, Forest, and Neutral themes.

Firestore rules are tracked in `firestore.rules`. They restrict each
authenticated user to their own `users/{userId}` document and its nested
collections, including `todos`.

### Acceptance criteria

- Tasks persist separately for each authenticated user.
- Adding, editing, completing, restoring, and deleting tasks work.
- Completed tasks leave the active list and enter the collapsed completed
  section immediately.
- Navigation preserves Calendar, Tasks, and Notes page state.
- The floating action button always communicates what it will create.
- The Android build and relevant automated tests pass.

## Future roadmap

The application should continue developing as a focused personal productivity
tool built around Calendar, Tasks, and Notes. New functionality should connect
these areas without making the core workflows dependent on AI or a permanent
network connection.

### Local AI assistant / intelligent quick capture

**Status:** Proposed

Connect the app to a user-configurable Ollama server and provide an assistant
that can work across Calendar, Tasks, and Notes. The goal is an
action-oriented assistant rather than a standalone generic chatbot.

Example requests:

- "Remind me to renew my insurance next Friday."
- "Schedule gym on Monday, Wednesday, and Friday at 18:00."
- "Turn this note into three tasks."
- "Summarize my unfinished checklist."
- "What do I have planned tomorrow?"

#### Phase 1: basic Ollama chat

- Add Ollama server URL and model selection to Settings.
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

- Support a private LAN or VPN address for a home-hosted Ollama instance.
- Do not expose an unauthenticated Ollama port directly to the public internet.
- Prefer a private VPN such as Tailscale or an authenticated HTTPS reverse
  proxy for access outside the home network.
- Store endpoint credentials in Android secure storage, not Firestore or plain
  shared preferences.
- Provide sensible connection timeouts, cancellation, and model warm-up
  feedback.

#### AI assistant acceptance criteria

- Ollama configuration can be tested without starting a conversation.
- Responses stream into the interface and can be cancelled.
- Offline or unreachable-server states are understandable and recoverable.
- Application context is opt-in and visible to the user.
- No model-generated action changes user data without confirmation.
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

- Split `FirestoreService` into injected repositories for events, notes, tasks,
  and tags. Add an independent assistant repository for Ollama.
- Query calendar events by the visible date range instead of maintaining one
  live stream containing the user's complete event history.
- Represent loading, empty, authentication, and error states separately rather
  than converting stream failures into empty lists.
- Initialize Firebase through one clearly owned application startup path.
- Add Firestore Emulator tests for repository behavior and security rules.

### Maintainability cleanup

- Split the large item editor and note-item widgets into smaller focused
  components.
- Remove the unused legacy calendar implementation after confirming that the
  current calendar contains all required behavior.
- Remove prototype code and unused dependencies, including unused state
  providers and state-management packages.
- Standardize on one state-management approach and inject services rather than
  constructing them directly inside widgets.
- Move Firestore serialization concerns out of domain models where practical.
- Replace loosely typed update methods with typed parameters or command
  objects.
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
