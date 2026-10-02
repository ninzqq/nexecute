import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/home/widgets/google_calendar_settings_section.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_source.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

void main() {
  testWidgets('disconnected account can connect', (tester) async {
    final harness = await _Harness.disconnected();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.dispose();
    });

    await tester.pumpWidget(harness.widget);
    await tester.pump();

    expect(find.text('Not connected.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google-calendar-connect')));
    await tester.pump();

    expect(harness.authorization.connectCount, 1);
  });

  testWidgets('connected account shows account and actions', (tester) async {
    final harness = await _Harness.connected();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.dispose();
    });

    await tester.pumpWidget(harness.widget);
    await tester.pump();

    expect(find.textContaining('person@example.test'), findsOneWidget);
    expect(find.byKey(const Key('google-calendar-manage')), findsOneWidget);
    expect(find.byKey(const Key('google-calendar-refresh')), findsOneWidget);
    expect(find.byKey(const Key('google-calendar-disconnect')), findsOneWidget);
  });

  testWidgets('calendar selection is saved once after Save', (tester) async {
    final harness = await _Harness.connected();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.dispose();
    });

    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.tap(find.byKey(const Key('google-calendar-manage')));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    await tester.tap(find.text('Personal'));
    await tester.pump();
    expect(harness.store.saveCount, 0);

    await tester.tap(find.byKey(const Key('google-calendar-save-selection')));
    await tester.pumpAndSettle();

    expect(harness.store.saveCount, 1);
    expect(harness.store.lastSelection, {'work', 'personal'});
  });

  testWidgets('disconnect requires confirmation', (tester) async {
    final harness = await _Harness.connected();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.dispose();
    });

    await tester.pumpWidget(harness.widget);
    await tester.pump();
    await tester.tap(find.byKey(const Key('google-calendar-disconnect')));
    await tester.pumpAndSettle();

    expect(harness.authorization.disconnectCount, 0);
    expect(find.text('Disconnect Google Calendar?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('google-calendar-confirm-disconnect')),
    );
    await tester.pumpAndSettle();

    expect(harness.authorization.disconnectCount, 1);
    expect(find.text('Not connected.'), findsOneWidget);
  });

  testWidgets('calendar selection remains usable in compact landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _Harness.connected();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoogleCalendarSettingsSection(
              authorization: harness.authorization,
              source: harness.source,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('google-calendar-manage')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('google-calendar-save-selection')),
      findsOneWidget,
    );
  });
}

final class _Harness {
  _Harness(this.authorization, this.source, this.store);

  static Future<_Harness> disconnected() async {
    final authorization = _Authorization.disconnected();
    final store = _Store();
    final source = GoogleCalendarSource(
      authorization: authorization,
      api: _Api(const []),
      store: store,
    );
    return _Harness(authorization, source, store);
  }

  static Future<_Harness> connected() async {
    final authorization = _Authorization.connected();
    final store = _Store();
    final source = GoogleCalendarSource(
      authorization: authorization,
      api: _Api(const [
        GoogleCalendarInfo(
          id: 'work',
          name: 'Work',
          accessRole: 'owner',
          defaultSelected: true,
          colorValue: 0xff3367d6,
          isPrimary: true,
        ),
        GoogleCalendarInfo(
          id: 'personal',
          name: 'Personal',
          accessRole: 'owner',
          defaultSelected: false,
          colorValue: 0xff0b8043,
        ),
      ]),
      store: store,
    );
    await source.refreshCalendars();
    store.saveCount = 0;
    store.lastSelection = null;
    return _Harness(authorization, source, store);
  }

  final _Authorization authorization;
  final GoogleCalendarSource source;
  final _Store store;

  Widget get widget => MaterialApp(
    home: Scaffold(
      body: GoogleCalendarSettingsSection(
        authorization: authorization,
        source: source,
      ),
    ),
  );

  Future<void> dispose() async {
    await source.dispose();
    await authorization.dispose();
  }
}

final class _Authorization implements GoogleCalendarAuthorizationService {
  _Authorization.disconnected()
    : state = GoogleCalendarAuthorizationState.disconnected,
      cacheOwner = null;

  _Authorization.connected()
    : state = const GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.connected,
        account: GoogleCalendarAccountIdentity(
          id: 'private-account-id',
          email: 'person@example.test',
        ),
      ),
      cacheOwner = const GoogleCalendarCacheOwner(
        nexecuteUserId: 'private-user-id',
        googleAccountId: 'private-account-id',
      );

  final _controller =
      StreamController<GoogleCalendarAuthorizationState>.broadcast(sync: true);
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  GoogleCalendarAuthorizationState state;

  @override
  GoogleCalendarCacheOwner? cacheOwner;

  @override
  Stream<GoogleCalendarAuthorizationState> get states => _controller.stream;

  @override
  Future<void> connect() async {
    connectCount += 1;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    cacheOwner = null;
    state = GoogleCalendarAuthorizationState.disconnected;
    _controller.add(state);
  }

  @override
  Future<GoogleCalendarAccessToken> accessToken() async =>
      const GoogleCalendarAccessToken('test-token');

  @override
  Future<GoogleCalendarAccessToken> refreshAccessTokenAfterUnauthorized(
    GoogleCalendarAccessToken rejectedToken,
  ) async => const GoogleCalendarAccessToken('refreshed-test-token');

  @override
  Future<void> markAuthorizationExpired(
    GoogleCalendarAccessToken rejectedToken,
  ) async {}

  @override
  Future<void> dispose() => _controller.close();
}

final class _Api implements GoogleCalendarApiGateway {
  _Api(this.calendars);

  final List<GoogleCalendarInfo> calendars;

  @override
  Future<GoogleCalendarPage<GoogleCalendarInfo>> listCalendars({
    required String accessToken,
    String? pageToken,
  }) async => GoogleCalendarPage(items: calendars);

  @override
  Future<GoogleCalendarPage<GoogleCalendarRemoteEvent>> listEvents({
    required String accessToken,
    required String calendarId,
    required CalendarQueryRange range,
    String? pageToken,
  }) async => GoogleCalendarPage(items: const []);

  @override
  void close() {}
}

final class _Store implements GoogleCalendarLocalStore {
  GoogleCalendarLocalState state = GoogleCalendarLocalState.empty;
  int saveCount = 0;
  Set<String>? lastSelection;

  @override
  Future<GoogleCalendarLocalState> load(GoogleCalendarCacheOwner owner) async =>
      state;

  @override
  Future<GoogleCalendarLocalState> saveMetadata(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarSelectionMetadata metadata, {
    Set<String> removeCalendarIds = const {},
  }) async {
    saveCount += 1;
    lastSelection = Set.of(metadata.selectedCalendarIds);
    state = GoogleCalendarLocalState(metadata: metadata, ranges: const []);
    return state;
  }

  @override
  Future<GoogleCalendarLocalState> replaceRanges(
    GoogleCalendarCacheOwner owner,
    List<GoogleCalendarCachedRange> replacements,
  ) async => state;

  @override
  Future<GoogleCalendarLocalState> removeCalendars(
    GoogleCalendarCacheOwner owner,
    Set<String> calendarIds,
  ) async => state;

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) async {
    state = GoogleCalendarLocalState.empty;
  }

  @override
  Future<void> dispose() async {}
}
