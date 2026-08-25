import 'package:nexecute/models/data_state.dart';
import 'package:rxdart/rxdart.dart';

Stream<DataState<T>> authenticatedDataStream<T, Identity>({
  required Stream<Identity?> authentication,
  required Stream<T> Function(Identity identity) load,
  required bool Function(T value) isEmpty,
}) {
  return authentication
      .switchMap<DataState<T>>((identity) {
        if (identity == null) {
          return Stream.value(DataUnauthenticated<T>());
        }

        return load(identity)
            .map<DataState<T>>(
              (value) =>
                  isEmpty(value) ? DataEmpty<T>(value) : DataReady<T>(value),
            )
            .onErrorReturnWith(
              (error, stackTrace) => DataFailure<T>(error, stackTrace),
            )
            .startWith(DataLoading<T>());
      })
      .onErrorReturnWith(
        (error, stackTrace) => DataFailure<T>(error, stackTrace),
      )
      .startWith(DataLoading<T>())
      .distinct(
        (previous, next) =>
            previous is DataLoading<T> && next is DataLoading<T>,
      );
}
