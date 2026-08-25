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
