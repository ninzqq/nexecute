import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/models/event.dart';

void main() {
  group('CalendarDisplayEvent.native', () {
    test('preserves the native identity, event, and capabilities', () {
      final event = _event(id: 'event-1');

      final displayEvent = CalendarDisplayEvent.native(event);

      expect(displayEvent.identity.source, CalendarEventSource.nexecute);
      expect(displayEvent.identity.sourceScopedId, 'event-1');
      expect(displayEvent.nativeEvent, same(event));
      expect(displayEvent.calendarName, 'Nexecute');
      expect(displayEvent.capabilities.canEdit, isTrue);
      expect(displayEvent.capabilities.canDelete, isTrue);
      expect(displayEvent.capabilities.canOpenExternally, isFalse);
    });

    test('distinguishes generated occurrences from their series and peers', () {
      final first = _event(
        id: 'series-1',
        start: DateTime.utc(2026, 8, 10, 9),
        recurrenceSeriesStart: DateTime.utc(2026, 8, 3, 9),
      );
      final second = _event(
        id: 'series-1',
        start: DateTime.utc(2026, 8, 17, 9),
        recurrenceSeriesStart: DateTime.utc(2026, 8, 3, 9),
      );

      final nativeIdentity =
          CalendarDisplayEvent.native(_event(id: 'series-1')).identity;
      final firstIdentity = CalendarDisplayEvent.native(first).identity;
      final secondIdentity = CalendarDisplayEvent.native(second).identity;

      expect(firstIdentity, isNot(nativeIdentity));
      expect(secondIdentity, isNot(firstIdentity));
      expect(
        firstIdentity.sourceScopedId,
        'series-1@${first.startTime.microsecondsSinceEpoch}',
      );
    });
  });

  test('external events retain metadata and are read-only', () {
    const source = CalendarEventSource('google', displayName: 'Google');
    final event = CalendarDisplayEvent(
      identity: const CalendarEventIdentity(
        source: source,
        sourceScopedId: 'external-1',
      ),
      title: 'External event',
      description: 'Imported description',
      startTime: DateTime.utc(2026, 8, 10, 9),
      endTime: DateTime.utc(2026, 8, 10, 10),
      isAllDay: false,
      calendarName: 'Work',
      calendarColorValue: 0xff123456,
      sourceTimeZone: 'Europe/Helsinki',
      externalUrl: Uri.parse('https://calendar.example/event/1'),
      capabilities: CalendarEventCapabilities.readOnly,
    );

    expect(event.source, source);
    expect(event.calendarName, 'Work');
    expect(event.calendarColorValue, 0xff123456);
    expect(event.sourceTimeZone, 'Europe/Helsinki');
    expect(event.externalUrl, Uri.parse('https://calendar.example/event/1'));
    expect(event.nativeEvent, isNull);
    expect(event.capabilities.canEdit, isFalse);
    expect(event.capabilities.canDelete, isFalse);
  });

  test('source-scoped identities do not collide across sources', () {
    const native = CalendarEventIdentity(
      source: CalendarEventSource.nexecute,
      sourceScopedId: 'shared-id',
    );
    const external = CalendarEventIdentity(
      source: CalendarEventSource('google', displayName: 'Google'),
      sourceScopedId: 'shared-id',
    );

    expect(native, isNot(external));
    expect({native, external}, hasLength(2));
    expect(native.toString(), 'nexecute:shared-id');
    expect(external.toString(), 'google:shared-id');
  });

  test('external events cannot expose native mutation capabilities', () {
    const source = CalendarEventSource('google', displayName: 'Google');

    expect(
      () => CalendarDisplayEvent(
        identity: const CalendarEventIdentity(
          source: source,
          sourceScopedId: 'external-1',
        ),
        title: 'External event',
        startTime: DateTime.utc(2026, 8, 10, 9),
        endTime: DateTime.utc(2026, 8, 10, 10),
        isAllDay: false,
        calendarName: 'Work',
        capabilities: CalendarEventCapabilities.native,
      ),
      throwsArgumentError,
    );
  });

  test('ordering remains total across external sources', () {
    CalendarDisplayEvent external(String sourceId) => CalendarDisplayEvent(
      identity: CalendarEventIdentity(
        source: CalendarEventSource(sourceId, displayName: sourceId),
        sourceScopedId: 'same-id',
      ),
      title: 'Same title',
      startTime: DateTime.utc(2026, 8, 10, 9),
      endTime: DateTime.utc(2026, 8, 10, 10),
      isAllDay: false,
      calendarName: sourceId,
      capabilities: CalendarEventCapabilities.readOnly,
    );
    final first = external('alpha');
    final second = external('beta');

    expect(compareCalendarDisplayEvents(first, second), lessThan(0));
    expect(compareCalendarDisplayEvents(second, first), greaterThan(0));
  });
}

Event _event({
  required String id,
  DateTime? start,
  DateTime? recurrenceSeriesStart,
}) {
  final startTime = start ?? DateTime.utc(2026, 8, 10, 9);
  return Event(
    id: id,
    title: 'Native event',
    description: 'Native description',
    startTime: startTime,
    endTime: startTime.add(const Duration(hours: 1)),
    recurrenceSeriesStartTime: recurrenceSeriesStart,
  );
}
