import 'dart:convert';
import 'dart:io';

import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/repositories/file_system_google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late FileSystemGoogleCalendarLocalStore store;
  final now = DateTime.utc(2026, 10, 1, 12);
  const owner = GoogleCalendarCacheOwner(
    nexecuteUserId: 'firebase-user-secret',
    googleAccountId: 'google-account-secret',
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('google-calendar-store-');
    store = FileSystemGoogleCalendarLocalStore(
      directoryProvider: () async => root,
      clock: () => now,
    );
  });

  tearDown(() async {
    await store.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('metadata and selected calendars round trip', () async {
    await store.saveMetadata(
      owner,
      GoogleCalendarSelectionMetadata(
        calendars: const [
          GoogleCalendarInfo(
            id: 'calendar-1',
            name: 'Team',
            accessRole: 'owner',
            defaultSelected: true,
            colorValue: 0xff123456,
            timeZone: 'Europe/Helsinki',
            isPrimary: true,
          ),
        ],
        selectedCalendarIds: const {'calendar-1'},
        selectionEstablished: true,
        updatedAt: now,
      ),
    );

    final loaded = await store.load(owner);

    expect(loaded.metadata!.calendars.single.id, 'calendar-1');
    expect(loaded.metadata!.calendars.single.name, 'Team');
    expect(loaded.metadata!.calendars.single.colorValue, 0xff123456);
    expect(loaded.metadata!.selectedCalendarIds, {'calendar-1'});
    expect(loaded.metadata!.selectionEstablished, isTrue);
    expect(loaded.metadata!.updatedAt, now);
  });

  test('owner paths are hashed and accounts are isolated', () async {
    const otherOwner = GoogleCalendarCacheOwner(
      nexecuteUserId: 'firebase-user-secret',
      googleAccountId: 'other-google-account',
    );
    await store.replaceRanges(owner, [_range('calendar-1', 1)]);
    await store.replaceRanges(otherOwner, [_range('calendar-2', 2)]);

    expect((await store.load(owner)).ranges.single.calendarId, 'calendar-1');
    expect(
      (await store.load(otherOwner)).ranges.single.calendarId,
      'calendar-2',
    );
    final ownerDirectories =
        await root
            .list()
            .where((entity) => entity is Directory)
            .cast<Directory>()
            .toList();
    expect(ownerDirectories, hasLength(2));
    for (final directory in ownerDirectories) {
      final name = path.basename(directory.path);
      expect(name, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(directory.path, isNot(contains(owner.nexecuteUserId)));
      expect(directory.path, isNot(contains(owner.googleAccountId)));
    }
  });

  test(
    'persisted schema excludes owner identifiers and token fields',
    () async {
      await store.saveMetadata(
        owner,
        GoogleCalendarSelectionMetadata(
          calendars: const [
            GoogleCalendarInfo(
              id: 'calendar-1',
              name: 'Team',
              accessRole: 'reader',
              defaultSelected: true,
            ),
          ],
          selectedCalendarIds: const {'calendar-1'},
          selectionEstablished: true,
          updatedAt: now,
        ),
      );
      await store.replaceRanges(owner, [_range('calendar-1', 1)]);

      final ownerDirectory =
          await root
              .list()
              .where((entity) => entity is Directory)
              .cast<Directory>()
              .single;
      final persisted =
          await File(
            path.join(ownerDirectory.path, 'state.v1.json'),
          ).readAsString();

      expect(persisted, isNot(contains(owner.nexecuteUserId)));
      expect(persisted, isNot(contains(owner.googleAccountId)));
      expect(persisted.toLowerCase(), isNot(contains('accesstoken')));
      expect(persisted.toLowerCase(), isNot(contains('refreshtoken')));
    },
  );

  test('replaces only an exact calendar and range key', () async {
    final original = _range('calendar-1', 1, title: 'old');
    final failedCalendar = _range('calendar-2', 1, title: 'preserved');
    final otherRange = _range('calendar-1', 2, title: 'other range');
    await store.replaceRanges(owner, [original, failedCalendar, otherRange]);

    await store.replaceRanges(owner, [_range('calendar-1', 1, title: 'new')]);

    final loaded = await store.load(owner);
    expect(loaded.ranges, hasLength(3));
    expect(_eventTitle(loaded, 'calendar-1', 1), 'new');
    expect(_eventTitle(loaded, 'calendar-1', 2), 'other range');
    expect(_eventTitle(loaded, 'calendar-2', 1), 'preserved');
  });

  test(
    'authoritative replacement retains non-identical range coverage',
    () async {
      final broadRange = GoogleCalendarCachedRange(
        calendarId: 'calendar-1',
        range: CalendarQueryRange(
          startInclusive: DateTime.utc(2026, 9, 1),
          endExclusive: DateTime.utc(2026, 9, 10),
        ),
        fetchedAt: now.subtract(const Duration(days: 1)),
        events: _range('calendar-1', 1, title: 'cancelled').events,
      );
      await store.replaceRanges(owner, [broadRange]);
      final replacement = GoogleCalendarCachedRange(
        calendarId: 'calendar-1',
        range: CalendarQueryRange(
          startInclusive: DateTime.utc(2026, 9, 2),
          endExclusive: DateTime.utc(2026, 9, 4),
        ),
        fetchedAt: now,
        events: const [],
      );

      final committed = await store.replaceRanges(owner, [replacement]);

      expect(committed.ranges, hasLength(2));
      expect(
        committed.ranges
            .singleWhere((value) => value.range == replacement.range)
            .events,
        isEmpty,
      );
      expect((await store.load(owner)).ranges, hasLength(2));
    },
  );

  test(
    'metadata selection and deselected range purge commit together',
    () async {
      await store.replaceRanges(owner, [
        _range('remove', 1),
        _range('keep', 2),
      ]);
      final metadata = GoogleCalendarSelectionMetadata(
        calendars: const [
          GoogleCalendarInfo(
            id: 'remove',
            name: 'Disabled',
            accessRole: 'reader',
            defaultSelected: true,
          ),
          GoogleCalendarInfo(
            id: 'keep',
            name: 'Enabled',
            accessRole: 'reader',
            defaultSelected: true,
          ),
        ],
        selectedCalendarIds: const {'keep'},
        selectionEstablished: true,
        updatedAt: now,
      );

      final committed = await store.saveMetadata(
        owner,
        metadata,
        removeCalendarIds: const {'remove'},
      );

      expect(committed.metadata!.calendars, hasLength(2));
      expect(committed.metadata!.selectedCalendarIds, {'keep'});
      expect(committed.ranges.map((range) => range.calendarId), ['keep']);
    },
  );

  test('removeCalendars removes metadata, selection, and all ranges', () async {
    await store.saveMetadata(
      owner,
      GoogleCalendarSelectionMetadata(
        calendars: const [
          GoogleCalendarInfo(
            id: 'remove',
            name: 'Remove',
            accessRole: 'reader',
            defaultSelected: false,
          ),
          GoogleCalendarInfo(
            id: 'keep',
            name: 'Keep',
            accessRole: 'reader',
            defaultSelected: true,
          ),
        ],
        selectedCalendarIds: const {'remove', 'keep'},
        selectionEstablished: true,
        updatedAt: now,
      ),
    );
    await store.replaceRanges(owner, [_range('remove', 1), _range('keep', 1)]);

    await store.removeCalendars(owner, const {'remove'});

    final loaded = await store.load(owner);
    expect(loaded.metadata!.calendars.map((value) => value.id), ['keep']);
    expect(loaded.metadata!.selectedCalendarIds, {'keep'});
    expect(loaded.ranges.map((value) => value.calendarId), ['keep']);
  });

  test('prunes expired ranges and deterministically keeps newest 24', () async {
    final ranges = <GoogleCalendarCachedRange>[
      _range('expired', 0, fetchedAt: now.subtract(const Duration(days: 31))),
      for (var index = 0; index < 26; index++)
        _range(
          'calendar-${index.toString().padLeft(2, '0')}',
          index,
          fetchedAt: now.subtract(Duration(hours: index)),
        ),
    ];

    for (final range in ranges) {
      await store.replaceRanges(owner, [range]);
    }
    final loaded = await store.load(owner);

    expect(loaded.ranges, hasLength(24));
    expect(
      loaded.ranges.any((range) => range.calendarId == 'expired'),
      isFalse,
    );
    final calendarIds = loaded.ranges.map((range) => range.calendarId);
    expect(calendarIds, isNot(contains('calendar-24')));
    expect(calendarIds, isNot(contains('calendar-25')));
  });

  test('evicts oldest ranges to keep at most 5000 events', () async {
    await store.replaceRanges(owner, [
      _rangeWithEventCount(
        'older',
        1,
        2501,
        fetchedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    await store.replaceRanges(owner, [
      _rangeWithEventCount('newer', 2, 2500, fetchedAt: now),
    ]);

    final loaded = await store.load(owner);

    expect(loaded.ranges, hasLength(1));
    expect(loaded.ranges.single.calendarId, 'newer');
    expect(loaded.ranges.single.events, hasLength(2500));
  });

  test(
    'rejects an oversized refresh without replacing existing data',
    () async {
      await store.replaceRanges(owner, [_range('existing', 1)]);

      await expectLater(
        store.replaceRanges(owner, [
          _rangeWithEventCount('too-large', 2, 5001, fetchedAt: now),
        ]),
        throwsA(
          isA<GoogleCalendarLocalStoreException>().having(
            (error) => error.error,
            'error',
            GoogleCalendarLocalStoreError.ioFailure,
          ),
        ),
      );

      final loaded = await store.load(owner);
      expect(loaded.ranges.single.calendarId, 'existing');
    },
  );

  test('rejects oversized metadata without replacing existing data', () async {
    await store.replaceRanges(owner, [_range('existing', 1)]);
    final calendars = List.generate(
      1001,
      (index) => GoogleCalendarInfo(
        id: 'calendar-$index',
        name: 'Calendar $index',
        accessRole: 'reader',
        defaultSelected: false,
      ),
    );

    await expectLater(
      store.saveMetadata(
        owner,
        GoogleCalendarSelectionMetadata(
          calendars: calendars,
          selectedCalendarIds: const {},
          selectionEstablished: true,
          updatedAt: now,
        ),
      ),
      throwsA(
        isA<GoogleCalendarLocalStoreException>().having(
          (error) => error.error,
          'error',
          GoogleCalendarLocalStoreError.corruptData,
        ),
      ),
    );

    final loaded = await store.load(owner);
    expect(loaded.metadata, isNull);
    expect(loaded.ranges.single.calendarId, 'existing');
  });

  test('clearForAccount deletes only that hashed owner directory', () async {
    const otherOwner = GoogleCalendarCacheOwner(
      nexecuteUserId: 'another-user',
      googleAccountId: 'another-account',
    );
    await store.replaceRanges(owner, [_range('remove', 1)]);
    await store.replaceRanges(otherOwner, [_range('keep', 1)]);

    await store.clearForAccount(owner);

    expect((await store.load(owner)).ranges, isEmpty);
    expect((await store.load(otherOwner)).ranges.single.calendarId, 'keep');
  });

  test('corruption errors do not expose stored payload or owner IDs', () async {
    await store.replaceRanges(owner, [_range('private-calendar-id', 1)]);
    final ownerDirectory =
        await root
            .list()
            .where((entity) => entity is Directory)
            .cast<Directory>()
            .single;
    final stateFile = File(path.join(ownerDirectory.path, 'state.v1.json'));
    await stateFile.writeAsString(
      jsonEncode({'secret': 'private-calendar-id'}),
      flush: true,
    );

    Object? error;
    try {
      await store.load(owner);
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<GoogleCalendarLocalStoreException>());
    expect(error.toString(), isNot(contains('private-calendar-id')));
    expect(error.toString(), isNot(contains(owner.nexecuteUserId)));
    expect(error.toString(), isNot(contains(owner.googleAccountId)));
  });

  test('rejects a symlinked owner directory without following it', () async {
    await store.replaceRanges(owner, [_range('calendar-1', 1)]);
    final ownerDirectory =
        await root
            .list()
            .where((entity) => entity is Directory)
            .cast<Directory>()
            .single;
    final external = await Directory.systemTemp.createTemp(
      'google-calendar-external-',
    );
    addTearDown(() async {
      if (await external.exists()) await external.delete(recursive: true);
    });
    await ownerDirectory.delete(recursive: true);
    await Link(ownerDirectory.path).create(external.path);

    await expectLater(
      store.load(owner),
      throwsA(
        isA<GoogleCalendarLocalStoreException>().having(
          (error) => error.error,
          'error',
          GoogleCalendarLocalStoreError.corruptData,
        ),
      ),
    );
  });

  test('reopens committed metadata and ranges from disk', () async {
    await store.saveMetadata(
      owner,
      GoogleCalendarSelectionMetadata(
        calendars: const [
          GoogleCalendarInfo(
            id: 'calendar-1',
            name: 'Calendar',
            accessRole: 'reader',
            defaultSelected: true,
          ),
        ],
        selectedCalendarIds: const {'calendar-1'},
        selectionEstablished: true,
        updatedAt: now,
      ),
    );
    await store.replaceRanges(owner, [_range('calendar-1', 1)]);
    final reopened = FileSystemGoogleCalendarLocalStore(
      directoryProvider: () async => root,
      clock: () => now,
    );
    addTearDown(reopened.dispose);

    final loaded = await reopened.load(owner);

    expect(loaded.metadata!.selectedCalendarIds, {'calendar-1'});
    expect(loaded.ranges.single.events.single.title, 'Event');
  });
}

GoogleCalendarCachedRange _range(
  String calendarId,
  int day, {
  String title = 'Event',
  DateTime? fetchedAt,
}) {
  final start = DateTime.utc(2026, 9, day + 1);
  return GoogleCalendarCachedRange(
    calendarId: calendarId,
    range: CalendarQueryRange(
      startInclusive: start,
      endExclusive: start.add(const Duration(days: 1)),
    ),
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 10, 1, 12),
    events: [
      GoogleCalendarCachedEvent(
        sourceScopedId: '$calendarId-event-$day',
        calendarId: calendarId,
        title: title,
        description: 'Description',
        startTime: start.add(const Duration(hours: 9)),
        endTime: start.add(const Duration(hours: 10)),
        isAllDay: false,
        calendarName: 'Calendar',
        calendarColorValue: 0xffabcdef,
        sourceTimeZone: 'UTC',
        externalUrl: Uri.parse('https://example.test/event/$day'),
      ),
    ],
  );
}

GoogleCalendarCachedRange _rangeWithEventCount(
  String calendarId,
  int day,
  int eventCount, {
  required DateTime fetchedAt,
}) {
  final base = _range(calendarId, day, fetchedAt: fetchedAt);
  return GoogleCalendarCachedRange(
    calendarId: base.calendarId,
    range: base.range,
    fetchedAt: base.fetchedAt,
    events: List.generate(
      eventCount,
      (index) => GoogleCalendarCachedEvent(
        sourceScopedId: '$calendarId-event-$index',
        calendarId: calendarId,
        title: 'Event $index',
        description: '',
        startTime: base.range.startInclusive,
        endTime: base.range.startInclusive.add(const Duration(minutes: 1)),
        isAllDay: false,
        calendarName: 'Calendar',
      ),
    ),
  );
}

String _eventTitle(
  GoogleCalendarLocalState state,
  String calendarId,
  int day,
) =>
    state.ranges
        .singleWhere(
          (range) =>
              range.calendarId == calendarId &&
              range.range.startInclusive.day == day + 1,
        )
        .events
        .single
        .title;
