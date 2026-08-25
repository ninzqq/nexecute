import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';

void main() {
  test('emits loading then unauthenticated without loading data', () async {
    var loadCalled = false;

    final states =
        await authenticatedDataStream<List<String>, String>(
          authentication: Stream.value(null),
          isEmpty: (items) => items.isEmpty,
          load: (_) {
            loadCalled = true;
            return Stream.value(const []);
          },
        ).toList();

    expect(states, [
      isA<DataLoading<List<String>>>(),
      isA<DataUnauthenticated<List<String>>>(),
    ]);
    expect(loadCalled, isFalse);
  });

  test('distinguishes empty data from populated data', () async {
    final emptyStates =
        await authenticatedDataStream<List<String>, String>(
          authentication: Stream.value('user-1'),
          isEmpty: (items) => items.isEmpty,
          load: (_) => Stream.value(const []),
        ).toList();
    final readyStates =
        await authenticatedDataStream<List<String>, String>(
          authentication: Stream.value('user-1'),
          isEmpty: (items) => items.isEmpty,
          load: (_) => Stream.value(const ['note']),
        ).toList();

    expect(emptyStates.last, isA<DataEmpty<List<String>>>());
    expect(readyStates.last, isA<DataReady<List<String>>>());
  });

  test('preserves data stream errors as failures', () async {
    final error = StateError('Firestore unavailable');

    final states =
        await authenticatedDataStream<List<String>, String>(
          authentication: Stream.value('user-1'),
          isEmpty: (items) => items.isEmpty,
          load: (_) => Stream.error(error),
        ).toList();

    expect(states.last, isA<DataFailure<List<String>>>());
    expect((states.last as DataFailure<List<String>>).error, same(error));
    expect(states.whereType<DataEmpty<List<String>>>(), isEmpty);
  });

  test('preserves authentication stream errors as failures', () async {
    final error = StateError('Authentication unavailable');

    final states =
        await authenticatedDataStream<List<String>, String>(
          authentication: Stream.error(error),
          isEmpty: (items) => items.isEmpty,
          load: (_) => Stream.value(const []),
        ).toList();

    expect(states.last, isA<DataFailure<List<String>>>());
    expect((states.last as DataFailure<List<String>>).error, same(error));
  });
}
