sealed class DataState<T> {
  const DataState();

  T? get valueOrNull => switch (this) {
    DataReady<T>(:final value) => value,
    DataEmpty<T>(:final value) => value,
    _ => null,
  };
}

final class DataLoading<T> extends DataState<T> {
  const DataLoading();
}

final class DataReady<T> extends DataState<T> {
  const DataReady(this.value);

  final T value;
}

final class DataEmpty<T> extends DataState<T> {
  const DataEmpty(this.value);

  final T value;
}

final class DataUnauthenticated<T> extends DataState<T> {
  const DataUnauthenticated();
}

final class DataFailure<T> extends DataState<T> {
  const DataFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}
