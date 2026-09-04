import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef FirestoreReadDiagnosticSink =
    void Function(FirestoreReadDiagnostic event);

enum FirestoreReadDiagnosticKind {
  listenerAttached,
  listenerSnapshot,
  listenerFailed,
  listenerDetached,
  oneShotStarted,
  oneShotCompleted,
  oneShotFailed,
}

@immutable
class FirestoreReadDiagnostic {
  const FirestoreReadDiagnostic({
    required this.kind,
    required this.operation,
    this.activeForOperation,
    this.activeTotal,
    this.source,
    this.documentCount,
    this.addedCount,
    this.modifiedCount,
    this.removedCount,
    this.hasPendingWrites,
    this.elapsedMilliseconds,
    this.errorType,
  });

  final FirestoreReadDiagnosticKind kind;
  final String operation;
  final int? activeForOperation;
  final int? activeTotal;
  final String? source;
  final int? documentCount;
  final int? addedCount;
  final int? modifiedCount;
  final int? removedCount;
  final bool? hasPendingWrites;
  final int? elapsedMilliseconds;
  final String? errorType;

  Map<String, Object> toJson() => {
    'event': kind.name,
    'operation': operation,
    if (activeForOperation != null) 'activeForOperation': activeForOperation!,
    if (activeTotal != null) 'activeTotal': activeTotal!,
    if (source != null) 'source': source!,
    if (documentCount != null) 'documentCount': documentCount!,
    if (addedCount != null) 'addedCount': addedCount!,
    if (modifiedCount != null) 'modifiedCount': modifiedCount!,
    if (removedCount != null) 'removedCount': removedCount!,
    if (hasPendingWrites != null) 'hasPendingWrites': hasPendingWrites!,
    if (elapsedMilliseconds != null)
      'elapsedMilliseconds': elapsedMilliseconds!,
    if (errorType != null) 'errorType': errorType!,
  };
}

/// Emits privacy-safe diagnostics about Firestore reads without logging query
/// values, document IDs, document contents, user IDs, or search text.
///
/// The default instance is disabled. [debug] enables diagnostics only in debug
/// builds, so production query behavior and logging remain unchanged.
class FirestoreReadDiagnostics {
  FirestoreReadDiagnostics._({
    required this.isEnabled,
    required FirestoreReadDiagnosticSink sink,
  }) : _sink = sink;

  factory FirestoreReadDiagnostics.debug({FirestoreReadDiagnosticSink? sink}) =>
      FirestoreReadDiagnostics._(
        isEnabled: kDebugMode,
        sink: sink ?? _logDiagnostic,
      );

  @visibleForTesting
  factory FirestoreReadDiagnostics.testing({
    required FirestoreReadDiagnosticSink sink,
  }) => FirestoreReadDiagnostics._(isEnabled: true, sink: sink);

  static final FirestoreReadDiagnostics disabled = FirestoreReadDiagnostics._(
    isEnabled: false,
    sink: (_) {},
  );

  final bool isEnabled;
  final FirestoreReadDiagnosticSink _sink;
  final Map<String, int> _activeListeners = {};
  int _activeListenerTotal = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuery({
    required String operation,
    required Query<Map<String, dynamic>> query,
  }) {
    final snapshots = query.snapshots(includeMetadataChanges: isEnabled);
    if (!isEnabled) return snapshots;
    return _observeQuery(operation, snapshots);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDocument({
    required String operation,
    required DocumentReference<Map<String, dynamic>> document,
  }) {
    final snapshots = document.snapshots(includeMetadataChanges: isEnabled);
    if (!isEnabled) return snapshots;
    return _observeDocument(operation, snapshots);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getQuery({
    required String operation,
    required Query<Map<String, dynamic>> query,
    GetOptions? options,
  }) async {
    if (!isEnabled) return options == null ? query.get() : query.get(options);

    final stopwatch = Stopwatch()..start();
    _emit(
      FirestoreReadDiagnostic(
        kind: FirestoreReadDiagnosticKind.oneShotStarted,
        operation: operation,
      ),
    );
    try {
      final snapshot =
          await (options == null ? query.get() : query.get(options));
      stopwatch.stop();
      _emit(
        FirestoreReadDiagnostic(
          kind: FirestoreReadDiagnosticKind.oneShotCompleted,
          operation: operation,
          source: _source(snapshot.metadata.isFromCache),
          documentCount: snapshot.docs.length,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        ),
      );
      return snapshot;
    } catch (error, stackTrace) {
      stopwatch.stop();
      _emit(
        FirestoreReadDiagnostic(
          kind: FirestoreReadDiagnosticKind.oneShotFailed,
          operation: operation,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          errorType: error.runtimeType.toString(),
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String operation,
    required DocumentReference<Map<String, dynamic>> document,
    GetOptions? options,
  }) async {
    if (!isEnabled) {
      return options == null ? document.get() : document.get(options);
    }

    final stopwatch = Stopwatch()..start();
    _emit(
      FirestoreReadDiagnostic(
        kind: FirestoreReadDiagnosticKind.oneShotStarted,
        operation: operation,
      ),
    );
    try {
      final snapshot =
          await (options == null ? document.get() : document.get(options));
      stopwatch.stop();
      _emit(
        FirestoreReadDiagnostic(
          kind: FirestoreReadDiagnosticKind.oneShotCompleted,
          operation: operation,
          source: _source(snapshot.metadata.isFromCache),
          documentCount: snapshot.exists ? 1 : 0,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        ),
      );
      return snapshot;
    } catch (error, stackTrace) {
      stopwatch.stop();
      _emit(
        FirestoreReadDiagnostic(
          kind: FirestoreReadDiagnosticKind.oneShotFailed,
          operation: operation,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          errorType: error.runtimeType.toString(),
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _observeQuery(
    String operation,
    Stream<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
    List<_DocumentData>? lastEmittedData;
    var isDetached = false;

    void detach() {
      if (isDetached) return;
      isDetached = true;
      _detach(operation);
    }

    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onListen: () {
        _attach(operation);
        subscription = snapshots.listen(
          (snapshot) {
            final changes = _changeCounts(snapshot.docChanges);
            _emit(
              FirestoreReadDiagnostic(
                kind: FirestoreReadDiagnosticKind.listenerSnapshot,
                operation: operation,
                source: _source(snapshot.metadata.isFromCache),
                documentCount: snapshot.docs.length,
                addedCount: changes.added,
                modifiedCount: changes.modified,
                removedCount: changes.removed,
                hasPendingWrites: snapshot.metadata.hasPendingWrites,
              ),
            );

            final currentData = [
              for (final document in snapshot.docs)
                _DocumentData(document.id, document.data()),
            ];
            if (lastEmittedData == null ||
                !_documentListsEqual(lastEmittedData!, currentData)) {
              lastEmittedData = currentData;
              controller.add(snapshot);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            _emit(
              FirestoreReadDiagnostic(
                kind: FirestoreReadDiagnosticKind.listenerFailed,
                operation: operation,
                errorType: error.runtimeType.toString(),
              ),
            );
            controller.addError(error, stackTrace);
          },
          onDone: () {
            detach();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
        detach();
      },
    );
    return controller.stream;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _observeDocument(
    String operation,
    Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  ) {
    late final StreamController<DocumentSnapshot<Map<String, dynamic>>>
    controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    _DocumentData? lastEmittedData;
    var hasEmitted = false;
    var isDetached = false;

    void detach() {
      if (isDetached) return;
      isDetached = true;
      _detach(operation);
    }

    controller = StreamController<DocumentSnapshot<Map<String, dynamic>>>(
      onListen: () {
        _attach(operation);
        subscription = snapshots.listen(
          (snapshot) {
            _emit(
              FirestoreReadDiagnostic(
                kind: FirestoreReadDiagnosticKind.listenerSnapshot,
                operation: operation,
                source: _source(snapshot.metadata.isFromCache),
                documentCount: snapshot.exists ? 1 : 0,
                hasPendingWrites: snapshot.metadata.hasPendingWrites,
              ),
            );

            final currentData =
                snapshot.exists
                    ? _DocumentData(snapshot.id, snapshot.data()!)
                    : null;
            if (!hasEmitted ||
                !_optionalDocumentDataEqual(lastEmittedData, currentData)) {
              hasEmitted = true;
              lastEmittedData = currentData;
              controller.add(snapshot);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            _emit(
              FirestoreReadDiagnostic(
                kind: FirestoreReadDiagnosticKind.listenerFailed,
                operation: operation,
                errorType: error.runtimeType.toString(),
              ),
            );
            controller.addError(error, stackTrace);
          },
          onDone: () {
            detach();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
        detach();
      },
    );
    return controller.stream;
  }

  void _attach(String operation) {
    final activeForOperation = (_activeListeners[operation] ?? 0) + 1;
    _activeListeners[operation] = activeForOperation;
    _activeListenerTotal += 1;
    _emit(
      FirestoreReadDiagnostic(
        kind: FirestoreReadDiagnosticKind.listenerAttached,
        operation: operation,
        activeForOperation: activeForOperation,
        activeTotal: _activeListenerTotal,
      ),
    );
  }

  void _detach(String operation) {
    final previous = _activeListeners[operation] ?? 1;
    final activeForOperation = previous > 0 ? previous - 1 : 0;
    if (activeForOperation == 0) {
      _activeListeners.remove(operation);
    } else {
      _activeListeners[operation] = activeForOperation;
    }
    if (_activeListenerTotal > 0) _activeListenerTotal -= 1;
    _emit(
      FirestoreReadDiagnostic(
        kind: FirestoreReadDiagnosticKind.listenerDetached,
        operation: operation,
        activeForOperation: activeForOperation,
        activeTotal: _activeListenerTotal,
      ),
    );
  }

  void _emit(FirestoreReadDiagnostic event) => _sink(event);

  static void _logDiagnostic(FirestoreReadDiagnostic event) {
    developer.log(jsonEncode(event.toJson()), name: 'nexecute.firestore.reads');
  }
}

String _source(bool isFromCache) => isFromCache ? 'cache' : 'server';

({int added, int modified, int removed}) _changeCounts(
  List<DocumentChange<Map<String, dynamic>>> changes,
) {
  var added = 0;
  var modified = 0;
  var removed = 0;
  for (final change in changes) {
    switch (change.type) {
      case DocumentChangeType.added:
        added += 1;
      case DocumentChangeType.modified:
        modified += 1;
      case DocumentChangeType.removed:
        removed += 1;
    }
  }
  return (added: added, modified: modified, removed: removed);
}

class _DocumentData {
  const _DocumentData(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

bool _documentListsEqual(
  List<_DocumentData> first,
  List<_DocumentData> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!_documentDataEqual(first[index], second[index])) return false;
  }
  return true;
}

bool _optionalDocumentDataEqual(_DocumentData? first, _DocumentData? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return false;
  return _documentDataEqual(first, second);
}

bool _documentDataEqual(_DocumentData first, _DocumentData second) =>
    first.id == second.id && _deepEqual(first.data, second.data);

bool _deepEqual(Object? first, Object? second) {
  if (identical(first, second)) return true;
  if (first is Timestamp && second is Timestamp) {
    return first.seconds == second.seconds &&
        first.nanoseconds == second.nanoseconds;
  }
  if (first is GeoPoint && second is GeoPoint) {
    return first.latitude == second.latitude &&
        first.longitude == second.longitude;
  }
  if (first is DocumentReference && second is DocumentReference) {
    return first.path == second.path;
  }
  if (first is Map && second is Map) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) ||
          !_deepEqual(entry.value, second[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (first is Iterable && second is Iterable) {
    final firstIterator = first.iterator;
    final secondIterator = second.iterator;
    while (true) {
      final firstHasNext = firstIterator.moveNext();
      final secondHasNext = secondIterator.moveNext();
      if (firstHasNext != secondHasNext) return false;
      if (!firstHasNext) return true;
      if (!_deepEqual(firstIterator.current, secondIterator.current)) {
        return false;
      }
    }
  }
  return first == second;
}
