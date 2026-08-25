import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/firebase_options.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/repositories.dart';
import 'package:nexecute/services/auth.dart';

const emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late AuthService authService;
  late String uid;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);

    final credential = await FirebaseAuth.instance.signInAnonymously();
    uid = credential.user!.uid;
    firestore = FirebaseFirestore.instance;
    authService = AuthService(firebaseAuth: FirebaseAuth.instance);
    await firestore.collection('users').doc(uid).set({'tags': <String>[]});
  });

  tearDownAll(() => FirebaseAuth.instance.signOut());

  testWidgets('repositories persist and update signed-in user data', (
    tester,
  ) async {
    final user = firestore.collection('users').doc(uid);
    final tags = FirestoreTagRepository(
      authService: authService,
      firestore: firestore,
    );
    final todos = FirestoreTodoRepository(
      authService: authService,
      firestore: firestore,
    );
    final notes = FirestoreNoteRepository(
      authService: authService,
      firestore: firestore,
    );
    final events = FirestoreEventRepository(
      authService: authService,
      firestore: firestore,
    );

    await tags.addTag('work');
    expect((await user.get()).data(), containsPair('tags', ['work']));

    await todos.addTodo('  Ship emulator tests  ');
    final addedTodo = (await user.collection('todos').get()).docs.single;
    final todo = TodoItem.fromFirestore(addedTodo);
    expect(todo.title, 'Ship emulator tests');

    await todos.updateTitle(todo, 'Run emulator tests');
    await todos.setCompleted(todo, true);
    final completedTodo = await addedTodo.reference.get();
    expect(completedTodo.data()!['title'], 'Run emulator tests');
    expect(completedTodo.data()!['isCompleted'], isTrue);
    expect(completedTodo.data()!['completedAt'], isA<Timestamp>());

    await notes.addNote(
      Quicxec(
        id: 'ignored-by-repository',
        text: 'First draft',
        title: 'Release notes',
        created: DateTime.utc(2026, 1, 1),
      ),
    );
    final addedNote = (await user.collection('quicxecs').get()).docs.single;
    final note = Quicxec.fromFirestore(addedNote);
    await notes.toggleTrashed(note);
    await notes.emptyTrash();
    expect((await user.collection('quicxecs').get()).docs, isEmpty);

    final start = DateTime.utc(2026, 1, 10, 9);
    final end = DateTime.utc(2026, 1, 10, 10);
    await events.addEvent(
      Event(
        id: 'ignored-by-repository',
        title: 'Planning',
        startTime: start,
        endTime: end,
      ),
    );
    final addedEvent = (await user.collection('events').get()).docs.single;
    final event = Event.fromFirestore(addedEvent);
    final range = CalendarQueryRange(
      startInclusive: DateTime.utc(2026, 1, 10),
      endExclusive: DateTime.utc(2026, 1, 11),
    );
    final state = await events
        .watchEvents(range)
        .firstWhere((state) => state is DataReady<List<Event>>);
    expect((state as DataReady<List<Event>>).value.single.id, event.id);

    await events.updateEvent(
      event,
      title: 'Updated planning',
      description: 'Agenda',
      startTime: start,
      endTime: end,
      isAllDay: false,
      tags: ['work'],
    );
    expect(
      (await addedEvent.reference.get()).data()!['title'],
      'Updated planning',
    );
    await events.deleteEvent(event);
    expect((await user.collection('events').get()).docs, isEmpty);
  });
}
