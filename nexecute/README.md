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

## Firestore data schema

Every user, event, note, and task document written by the app includes the
integer `schemaVersion` field. The current version is defined once in
`AppDataSchema`.

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
