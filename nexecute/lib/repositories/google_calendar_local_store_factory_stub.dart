import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

GoogleCalendarLocalStore createGoogleCalendarLocalStore() =>
    _UnavailableGoogleCalendarLocalStore();

final class _UnavailableGoogleCalendarLocalStore
    implements GoogleCalendarLocalStore {
  @override
  Future<GoogleCalendarLocalState> load(GoogleCalendarCacheOwner owner) async =>
      GoogleCalendarLocalState.empty;

  @override
  Future<GoogleCalendarLocalState> saveMetadata(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarSelectionMetadata metadata, {
    Set<String> removeCalendarIds = const {},
  }) async => GoogleCalendarLocalState(metadata: metadata, ranges: const []);

  @override
  Future<GoogleCalendarLocalState> replaceRanges(
    GoogleCalendarCacheOwner owner,
    List<GoogleCalendarCachedRange> replacements,
  ) async => GoogleCalendarLocalState(ranges: replacements);

  @override
  Future<GoogleCalendarLocalState> removeCalendars(
    GoogleCalendarCacheOwner owner,
    Set<String> calendarIds,
  ) async => GoogleCalendarLocalState.empty;

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) async {}

  @override
  Future<void> dispose() async {}
}
