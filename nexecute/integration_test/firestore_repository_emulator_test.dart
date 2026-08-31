import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/firebase_options.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/repositories.dart';
import 'package:nexecute/repositories/firestore/event_document_mapper.dart';
import 'package:nexecute/repositories/firestore/note_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/repositories/firestore/todo_document_mapper.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/ai/ai.dart';

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

    await FirebaseAuth.instance.signOut();
    final credential = await FirebaseAuth.instance.signInAnonymously();
    uid = credential.user!.uid;
    firestore = FirebaseFirestore.instance;
    authService = AuthService(firebaseAuth: FirebaseAuth.instance);
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
    final noteFolders = FirestoreNoteFolderRepository(
      authService: authService,
      firestore: firestore,
    );
    final events = FirestoreEventRepository(
      authService: authService,
      firestore: firestore,
    );
    final aiConversations = FirestoreAiConversationStore(
      authService: authService,
      firestore: firestore,
    );

    await tags.addTag('work');
    expect((await user.get()).data(), containsPair('tags', ['work']));
    expect(
      (await user.get()).data(),
      containsPair(AppDataSchema.versionField, AppDataSchema.currentVersion),
    );

    await todos.addTodo('  Ship emulator tests  ');
    final addedTodo = (await user.collection('todos').get()).docs.single;
    final todo = TodoDocumentMapper.fromDocument(addedTodo);
    expect(todo.title, 'Ship emulator tests');
    expect(
      addedTodo.data(),
      containsPair(AppDataSchema.versionField, AppDataSchema.currentVersion),
    );

    await todos.updateTitle(todo, 'Run emulator tests');
    await todos.setCompleted(todo, true);
    final completedTodo = await addedTodo.reference.get();
    expect(completedTodo.data()!['title'], 'Run emulator tests');
    expect(completedTodo.data()!['isCompleted'], isTrue);
    expect(completedTodo.data()!['completedAt'], isA<Timestamp>());

    await noteFolders.addFolder('Projects');
    final addedFolder =
        (await user.collection('noteFolders').get()).docs.single;
    expect(addedFolder.data()['name'], 'Projects');
    expect(
      addedFolder.data(),
      containsPair(AppDataSchema.versionField, AppDataSchema.currentVersion),
    );

    await notes.addNote(
      Quicxec(
        id: 'ignored-by-repository',
        text: 'First draft',
        title: 'Release notes',
        created: DateTime.utc(2026, 1, 1),
        folderId: addedFolder.id,
      ),
    );
    final addedNote = (await user.collection('quicxecs').get()).docs.single;
    final note = NoteDocumentMapper.fromDocument(addedNote);
    expect(note.folderId, addedFolder.id);
    expect(
      addedNote.data(),
      containsPair(AppDataSchema.versionField, AppDataSchema.currentVersion),
    );
    final sourceNoteBeforeTaskCreation = Map<String, dynamic>.from(
      addedNote.data(),
    );
    final aiTodoCommand = CreateTodosCommand(
      creationId: 'proposal-1',
      sourceNoteId: addedNote.id,
      titles: const ['Buy coffee', 'Call Sam'],
      createdAt: DateTime.utc(2026, 8, 29, 12),
    );
    await todos.createTodos(aiTodoCommand);
    await todos.createTodos(aiTodoCommand);
    final todoDocuments = await user.collection('todos').get();
    expect(todoDocuments.docs, hasLength(3));
    for (var index = 0; index < aiTodoCommand.titles.length; index++) {
      final document =
          await user
              .collection('todos')
              .doc(aiTodoCommand.todoIdAt(index))
              .get();
      expect(
        document.data(),
        containsPair('title', aiTodoCommand.titles[index]),
      );
      expect(document.data(), containsPair('creationId', 'proposal-1'));
      expect(document.data(), containsPair('sourceNoteId', addedNote.id));
      expect(
        document.data(),
        containsPair('creationSource', 'aiNoteTaskProposal'),
      );
    }
    expect(
      (await addedNote.reference.get()).data(),
      sourceNoteBeforeTaskCreation,
    );
    final aiEventCommand = CreateEventCommand(
      creationId: 'event-proposal-1',
      sourceNoteId: addedNote.id,
      title: 'Dentist',
      description: 'Check-up',
      startTime: DateTime(2026, 9, 3, 14),
      endTime: DateTime(2026, 9, 3, 15),
      isAllDay: false,
      tags: const ['Personal'],
      reminder: EventReminder.fifteenMinutesBefore,
      createdAt: DateTime.utc(2026, 8, 30, 12),
    );
    await events.createEvent(aiEventCommand);
    await events.createEvent(aiEventCommand);
    final aiEventDocuments = await user.collection('events').get();
    expect(aiEventDocuments.docs, hasLength(1));
    final aiEventDocument =
        await user.collection('events').doc(aiEventCommand.eventId).get();
    expect(aiEventDocument.data(), containsPair('title', 'Dentist'));
    expect(
      aiEventDocument.data(),
      containsPair('creationId', 'event-proposal-1'),
    );
    expect(aiEventDocument.data(), containsPair('sourceNoteId', addedNote.id));
    expect(
      aiEventDocument.data(),
      containsPair('creationSource', 'aiNoteEventProposal'),
    );
    expect(aiEventDocument.data(), containsPair('reminderMinutesBefore', 15));
    expect(
      (await addedNote.reference.get()).data(),
      sourceNoteBeforeTaskCreation,
    );
    await events.deleteEvent(aiEventCommand.toEvent());
    expect((await user.collection('events').get()).docs, isEmpty);

    await noteFolders.deleteFolder(addedFolder.id);
    expect((await user.collection('noteFolders').get()).docs, isEmpty);
    final unfiledNote = NoteDocumentMapper.fromDocument(
      await addedNote.reference.get(),
    );
    expect(unfiledNote.folderId, isNull);

    await notes.toggleTrashed(unfiledNote);
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
    final event = EventDocumentMapper.fromDocument(addedEvent);
    expect(
      addedEvent.data(),
      containsPair(AppDataSchema.versionField, AppDataSchema.currentVersion),
    );
    final range = CalendarQueryRange(
      startInclusive: DateTime.utc(2026, 1, 10),
      endExclusive: DateTime.utc(2026, 1, 11),
    );
    final state = await events
        .watchEvents(range)
        .firstWhere((state) => state is DataReady<List<Event>>);
    expect((state as DataReady<List<Event>>).value.single.id, event.id);

    await events.updateEvent(
      UpdateEventCommand(
        eventId: event.id,
        title: 'Updated planning',
        description: 'Agenda',
        startTime: start,
        endTime: end,
        isAllDay: false,
        tags: ['work'],
        reminder: EventReminder.fifteenMinutesBefore,
        recurrence: EventRecurrence.yearly,
      ),
    );
    expect(
      (await addedEvent.reference.get()).data()!['title'],
      'Updated planning',
    );
    expect(
      (await addedEvent.reference.get()).data()!['reminderMinutesBefore'],
      15,
    );
    expect((await addedEvent.reference.get()).data()!['recurrence'], 'yearly');
    expect((await addedEvent.reference.get()).data()!['isRecurring'], isTrue);
    final nextYearRange = CalendarQueryRange(
      startInclusive: DateTime.utc(2027, 1, 10),
      endExclusive: DateTime.utc(2027, 1, 11),
    );
    final nextYearState = await events
        .watchEvents(nextYearRange)
        .firstWhere((state) => state is DataReady<List<Event>>);
    final nextYearOccurrence =
        (nextYearState as DataReady<List<Event>>).value.single;
    expect(nextYearOccurrence.startTime, DateTime.utc(2027, 1, 10, 9));
    expect(nextYearOccurrence.seriesStartTime, start);
    final eventSearchResults = await events.searchEvents('agenda WORK');
    expect(eventSearchResults.single.id, event.id);
    expect(await events.searchEvents('not present'), isEmpty);
    await events.deleteEvent(event);
    expect((await user.collection('events').get()).docs, isEmpty);

    final conversation = AiConversation(
      id: 'ai-conversation',
      title: 'Synced chat',
      connectionProfileId: 'home',
      modelId: 'local-model',
      createdAt: DateTime.utc(2026, 1, 10, 12),
      updatedAt: DateTime.utc(2026, 1, 10, 12),
    );
    await aiConversations.saveConversation(conversation);
    await aiConversations.saveMessage(
      conversation.id,
      AiChatMessage(
        id: 'message-1',
        role: AiMessageRole.user,
        content: 'Hello from another device',
        createdAt: DateTime.utc(2026, 1, 10, 12, 1),
      ),
    );
    final restored = await aiConversations.getConversation(conversation.id);
    expect(restored!.messages.single.content, 'Hello from another device');
    await aiConversations.saveConversation(
      restored.copyWith(
        title: 'Renamed synced chat',
        updatedAt: DateTime.utc(2026, 1, 10, 12, 2),
      ),
    );
    final messageDocuments =
        await user
            .collection('aiConversations')
            .doc(conversation.id)
            .collection('messages')
            .get();
    expect(messageDocuments.docs, hasLength(1));
    expect(
      messageDocuments.docs.single.data()['content'],
      'Hello from another device',
    );
    await aiConversations.deleteConversation(conversation.id);
    expect(
      (await user.collection('aiConversations').doc(conversation.id).get())
          .exists,
      isFalse,
    );
    expect(
      (await user
              .collection('aiConversations')
              .doc(conversation.id)
              .collection('messages')
              .get())
          .docs,
      isEmpty,
    );

    final largeConversation = conversation.copyWith(
      id: 'large-ai-conversation',
      title: 'Large synced chat',
    );
    await aiConversations.saveConversation(largeConversation);
    final largeConversationReference = user
        .collection('aiConversations')
        .doc(largeConversation.id);
    for (var offset = 0; offset < 401; offset += 400) {
      final batch = firestore.batch();
      final end = offset == 0 ? 400 : 401;
      for (var index = offset; index < end; index++) {
        batch.set(
          largeConversationReference
              .collection('messages')
              .doc('message-$index'),
          {'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 10, 13))},
        );
      }
      await batch.commit();
    }
    await aiConversations.deleteConversation(largeConversation.id);
    expect((await largeConversationReference.get()).exists, isFalse);
    expect(
      (await largeConversationReference.collection('messages').get()).docs,
      isEmpty,
    );
  });
}
