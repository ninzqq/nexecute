// Firestore's public snapshot types are annotated as sealed but intentionally
// expose abstract interfaces. These narrow fakes let this test exercise the
// diagnostics wrapper without contacting Firebase.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/services/firestore_read_diagnostics.dart';

void main() {
  group('FirestoreReadDiagnostics', () {
    test(
      'tracks listener lifecycle and suppresses metadata-only output',
      () async {
        final source = StreamController<QuerySnapshot<Map<String, dynamic>>>();
        final events = <FirestoreReadDiagnostic>[];
        final diagnostics = FirestoreReadDiagnostics.testing(sink: events.add);
        final query = _FakeQuery(snapshotStream: source.stream);
        final received = <QuerySnapshot<Map<String, dynamic>>>[];

        final subscription = diagnostics
            .watchQuery(operation: 'notes.all', query: query)
            .listen(received.add);
        await _flushEvents();

        source.add(
          _querySnapshot(
            fromCache: true,
            documents: const {
              'note-1': {'title': 'First'},
            },
            changes: const [DocumentChangeType.added],
          ),
        );
        await _flushEvents();
        source.add(
          _querySnapshot(
            fromCache: false,
            documents: const {
              'note-1': {'title': 'First'},
            },
          ),
        );
        await _flushEvents();
        source.add(
          _querySnapshot(
            fromCache: false,
            documents: const {
              'note-1': {'title': 'Updated'},
            },
            changes: const [DocumentChangeType.modified],
          ),
        );
        await _flushEvents();

        await subscription.cancel();
        await source.close();

        expect(query.invocation.includeMetadataChanges, isTrue);
        expect(received, hasLength(2));
        expect(events.map((event) => event.kind), [
          FirestoreReadDiagnosticKind.listenerAttached,
          FirestoreReadDiagnosticKind.listenerSnapshot,
          FirestoreReadDiagnosticKind.listenerSnapshot,
          FirestoreReadDiagnosticKind.listenerSnapshot,
          FirestoreReadDiagnosticKind.listenerDetached,
        ]);
        expect(events.first.activeForOperation, 1);
        expect(events.first.activeTotal, 1);
        expect(events[1].source, 'cache');
        expect(events[1].documentCount, 1);
        expect(events[1].addedCount, 1);
        expect(events[2].source, 'server');
        expect(events[2].addedCount, 0);
        expect(events.last.activeForOperation, 0);
        expect(events.last.activeTotal, 0);
      },
    );

    test('tracks duplicate active listeners by operation', () async {
      final firstSource =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final secondSource =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      final events = <FirestoreReadDiagnostic>[];
      final diagnostics = FirestoreReadDiagnostics.testing(sink: events.add);

      final first = diagnostics
          .watchQuery(
            operation: 'todos.all',
            query: _FakeQuery(snapshotStream: firstSource.stream),
          )
          .listen((_) {});
      final second = diagnostics
          .watchQuery(
            operation: 'todos.all',
            query: _FakeQuery(snapshotStream: secondSource.stream),
          )
          .listen((_) {});
      await _flushEvents();

      final attached = events.where(
        (event) => event.kind == FirestoreReadDiagnosticKind.listenerAttached,
      );
      expect(attached.map((event) => event.activeForOperation), [1, 2]);
      expect(attached.map((event) => event.activeTotal), [1, 2]);

      await first.cancel();
      await second.cancel();
      await firstSource.close();
      await secondSource.close();

      final detached = events.where(
        (event) => event.kind == FirestoreReadDiagnosticKind.listenerDetached,
      );
      expect(detached.map((event) => event.activeForOperation), [1, 0]);
      expect(detached.map((event) => event.activeTotal), [1, 0]);
    });

    test(
      'tracks document listeners without forwarding metadata-only output',
      () async {
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final events = <FirestoreReadDiagnostic>[];
        final diagnostics = FirestoreReadDiagnostics.testing(sink: events.add);
        final document = _FakeDocumentReference(snapshotStream: source.stream);
        final received = <DocumentSnapshot<Map<String, dynamic>>>[];

        final subscription = diagnostics
            .watchDocument(operation: 'tags.userDocument', document: document)
            .listen(received.add);
        await _flushEvents();

        source.add(
          _FakeDocumentSnapshot(
            id: 'private-id',
            value: const {
              'tags': ['first'],
            },
            metadata: _FakeSnapshotMetadata(fromCache: true),
          ),
        );
        await _flushEvents();
        source.add(
          _FakeDocumentSnapshot(
            id: 'private-id',
            value: const {
              'tags': ['first'],
            },
            metadata: _FakeSnapshotMetadata(fromCache: false),
          ),
        );
        await _flushEvents();
        source.add(
          _FakeDocumentSnapshot(
            id: 'private-id',
            value: const {
              'tags': ['first', 'second'],
            },
            metadata: _FakeSnapshotMetadata(fromCache: false),
          ),
        );
        await _flushEvents();

        await subscription.cancel();
        await source.close();

        expect(document.invocation.includeMetadataChanges, isTrue);
        expect(received, hasLength(2));
        final snapshots = events.where(
          (event) => event.kind == FirestoreReadDiagnosticKind.listenerSnapshot,
        );
        expect(snapshots.map((event) => event.source), [
          'cache',
          'server',
          'server',
        ]);
        expect(snapshots.every((event) => event.documentCount == 1), isTrue);
        expect(
          events.expand((event) => event.toJson().keys),
          isNot(contains('documentId')),
        );
      },
    );

    test('tracks successful and failed one-shot query reads', () async {
      final events = <FirestoreReadDiagnostic>[];
      final diagnostics = FirestoreReadDiagnostics.testing(sink: events.add);
      final snapshot = _querySnapshot(
        fromCache: false,
        documents: const {
          'event-1': {'title': 'First'},
          'event-2': {'title': 'Second'},
        },
      );

      final result = await diagnostics.getQuery(
        operation: 'events.searchAll',
        query: _FakeQuery(result: snapshot),
      );
      expect(result, same(snapshot));
      expect(events[0].kind, FirestoreReadDiagnosticKind.oneShotStarted);
      expect(events[1].kind, FirestoreReadDiagnosticKind.oneShotCompleted);
      expect(events[1].source, 'server');
      expect(events[1].documentCount, 2);

      await expectLater(
        diagnostics.getQuery(
          operation: 'events.searchAll',
          query: _FakeQuery(error: StateError('unavailable')),
        ),
        throwsStateError,
      );
      expect(events[2].kind, FirestoreReadDiagnosticKind.oneShotStarted);
      expect(events[3].kind, FirestoreReadDiagnosticKind.oneShotFailed);
      expect(events[3].errorType, 'StateError');
    });

    test('serialized events contain metrics but no data-bearing fields', () {
      const event = FirestoreReadDiagnostic(
        kind: FirestoreReadDiagnosticKind.listenerSnapshot,
        operation: 'ai.messages',
        source: 'server',
        documentCount: 12,
        addedCount: 1,
        modifiedCount: 0,
        removedCount: 0,
      );

      expect(event.toJson(), {
        'event': 'listenerSnapshot',
        'operation': 'ai.messages',
        'source': 'server',
        'documentCount': 12,
        'addedCount': 1,
        'modifiedCount': 0,
        'removedCount': 0,
      });
    });
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

QuerySnapshot<Map<String, dynamic>> _querySnapshot({
  required bool fromCache,
  required Map<String, Map<String, dynamic>> documents,
  List<DocumentChangeType> changes = const [],
}) {
  final docs = [
    for (final entry in documents.entries)
      _FakeQueryDocumentSnapshot(id: entry.key, value: entry.value),
  ];
  return _FakeQuerySnapshot(
    docs: docs,
    changes: [
      for (var index = 0; index < changes.length; index++)
        _FakeDocumentChange(
          type: changes[index],
          document: docs[index.clamp(0, docs.length - 1)],
        ),
    ],
    metadata: _FakeSnapshotMetadata(fromCache: fromCache),
  );
}

class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery({this.snapshotStream, this.result, this.error});

  final Stream<QuerySnapshot<Map<String, dynamic>>>? snapshotStream;
  final QuerySnapshot<Map<String, dynamic>>? result;
  final Object? error;
  final invocation = _SnapshotInvocation();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    invocation.includeMetadataChanges = includeMetadataChanges;
    return snapshotStream ?? const Stream.empty();
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (error case final error?) return Future.error(error);
    return Future.value(result!);
  }
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot({
    required this.docs,
    required List<DocumentChange<Map<String, dynamic>>> changes,
    required this.metadata,
  }) : _changes = changes;

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final List<DocumentChange<Map<String, dynamic>>> _changes;
  @override
  final SnapshotMetadata metadata;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => _changes;

  @override
  int get size => docs.length;
}

class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference({required this.snapshotStream});

  final Stream<DocumentSnapshot<Map<String, dynamic>>> snapshotStream;
  final invocation = _SnapshotInvocation();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    invocation.includeMetadataChanges = includeMetadataChanges;
    return snapshotStream;
  }
}

class _SnapshotInvocation {
  bool? includeMetadataChanges;
}

class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot({
    required this.id,
    required this.value,
    required this.metadata,
  });

  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  final SnapshotMetadata metadata;

  @override
  bool get exists => value != null;

  @override
  Map<String, dynamic>? data() => value;
}

class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot({required this.id, required this.value});

  @override
  final String id;
  final Map<String, dynamic> value;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => value;
}

class _FakeDocumentChange extends Fake
    implements DocumentChange<Map<String, dynamic>> {
  _FakeDocumentChange({required this.type, required this.document});

  @override
  final DocumentChangeType type;
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  DocumentSnapshot<Map<String, dynamic>> get doc => document;
}

class _FakeSnapshotMetadata extends Fake implements SnapshotMetadata {
  _FakeSnapshotMetadata({required this.fromCache});

  final bool fromCache;

  @override
  bool get isFromCache => fromCache;

  @override
  bool get hasPendingWrites => false;
}
