# nexecute

## Firestore Emulator tests

Install the Java runtime and Firebase Emulator Suite dependencies, then start
the Auth and Firestore emulators:

```sh
firebase emulators:start --only auth,firestore
```

In a second terminal, install and run the rules tests:

```sh
npm --prefix emulator_tests install
npm --prefix emulator_tests test
```

The repository integration test runs on an Android emulator and connects to
the host machine through `10.0.2.2` by default:

```sh
flutter test integration_test/firestore_repository_emulator_test.dart \
  -d <android-emulator-id>
```

Use `--dart-define=FIREBASE_EMULATOR_HOST=<host>` when the test device reaches
the emulator through a different address.

The Android reminder scheduler has a separate device integration test. Grant
the test installation notification and exact-alarm permissions, then run:

```sh
flutter test integration_test/event_reminder_scheduler_android_test.dart \
  -d <android-emulator-id>
```

## Android calendar reminders

Calendar events can store an optional reminder from the event editor. Android
schedules it as an exact local notification and asks for notification and
Alarms & reminders access when the first reminder is enabled. Updating an event
replaces its pending notification; disabling the reminder or deleting the event
cancels it. Android restores pending reminders after a reboot or application
update.

The reminder preference is stored in Firestore, but the pending Android alarm
belongs to the device where the event was created or edited.

## Local AI quality evaluation

The versioned Finnish and English suite for chat and Note → proposed tasks can
be validated without contacting a server:

```sh
dart run tool/run_ai_quality_evaluation.dart --dry-run
```

See [the evaluation guide](docs/ai_quality_evaluation.md) for live model runs,
model/version comparison reports, and the failure taxonomy.

## Firestore data schema

Every user, event, note, note-folder, and task document written by the app includes the
integer `schemaVersion` field. The current version is defined once in
`AppDataSchema`.

Notes use a nullable `folderId`. A missing, null, or no-longer-valid folder ID
places the note in Quick Notes, which is the knowledge-base inbox. User folders
are stored under `users/{uid}/noteFolders`; deleting one unfiles its notes
before removing the folder document. Notes also store `updatedAt` so knowledge-
base views have stable recent-first ordering.

Documents without a version are version 0. Each Firestore document mapper
applies its ordered migrations before constructing a domain model. New writes
and partial updates stamp the current version, so legacy documents are upgraded
when edited without requiring a risky one-time rewrite of every user's data.
Documents from a newer unsupported schema fail explicitly instead of being read
with potentially lossy defaults.

When changing the stored shape:

1. Increment `AppDataSchema.currentVersion`.
2. Register the next migration in every document mapper, using a no-op for
   unchanged document shapes.
3. Update mapper and emulator tests for both legacy reads and current writes.
