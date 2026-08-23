# Nexecute Roadmap

## Tasks / to-do list

**Status:** Implemented — Firebase security-rule verification pending

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
- [ ] Verify Firestore security rules for the `todos` collection.
- [x] Add model, interaction, persistence, and navigation tests.
- [x] Verify the page under Cyberpunk, Midnight, Forest, and Neutral themes.

The repository does not currently contain a Firestore rules file. Verify in
the Firebase console that an authenticated user can access only their own
`users/{userId}/todos/{todoId}` documents.

### Acceptance criteria

- Tasks persist separately for each authenticated user.
- Adding, editing, completing, restoring, and deleting tasks work.
- Completed tasks leave the active list and enter the collapsed completed
  section immediately.
- Navigation preserves Calendar, Tasks, and Notes page state.
- The floating action button always communicates what it will create.
- The Android build and relevant automated tests pass.
