import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';
import 'package:path/path.dart' as path;

typedef GoogleCalendarStoreDirectoryProvider = Future<Directory> Function();
typedef GoogleCalendarStoreClock = DateTime Function();

final class FileSystemGoogleCalendarLocalStore
    implements GoogleCalendarLocalStore {
  FileSystemGoogleCalendarLocalStore({
    required GoogleCalendarStoreDirectoryProvider directoryProvider,
    GoogleCalendarStoreClock? clock,
  }) : _directoryProvider = directoryProvider,
       _clock = clock ?? DateTime.now;

  static const _schemaVersion = 1;
  static const _stateFileName = 'state.v1.json';
  static const _maxFileBytes = 16 * 1024 * 1024;
  static const _maxStringLength = 64 * 1024;
  static const _maxIdentifierLength = 1024;
  static const _maxUrlLength = 8192;
  static const _maxCalendars = 1000;
  static const _maxSelectedCalendars = 24;
  static const _maxDecodedRanges = 1000;
  static const _maxDecodedEvents = 20000;
  static const _maxRanges = 24;
  static const _maxEvents = 5000;
  static const _maxAge = Duration(days: 30);

  final GoogleCalendarStoreDirectoryProvider _directoryProvider;
  final GoogleCalendarStoreClock _clock;
  Future<void> _operationTail = Future<void>.value();
  var _temporaryCounter = 0;
  var _disposed = false;
  Future<void>? _disposeOperation;

  @override
  Future<GoogleCalendarLocalState> load(GoogleCalendarCacheOwner owner) =>
      _schedule(() => _readAndPrune(owner));

  @override
  Future<GoogleCalendarLocalState> saveMetadata(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarSelectionMetadata metadata, {
    Set<String> removeCalendarIds = const {},
  }) => _schedule(() async {
    final current = await _readAndPrune(owner);
    return _write(
      owner,
      GoogleCalendarLocalState(
        metadata: metadata,
        ranges: [
          for (final range in current.ranges)
            if (!removeCalendarIds.contains(range.calendarId)) range,
        ],
      ),
    );
  });

  @override
  Future<GoogleCalendarLocalState> replaceRanges(
    GoogleCalendarCacheOwner owner,
    List<GoogleCalendarCachedRange> replacements,
  ) => _schedule(() async {
    final replacementEventCount = replacements.fold<int>(
      0,
      (count, range) => count + range.events.length,
    );
    if (replacements.length > _maxRanges ||
        replacementEventCount > _maxEvents) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.ioFailure,
        'The refreshed calendar range exceeds the local cache limit.',
      );
    }
    final current = await _readAndPrune(owner);
    final ranges = <String, GoogleCalendarCachedRange>{
      for (final range in current.ranges) _rangeKey(range): range,
    };
    for (final replacement in replacements) {
      ranges[_rangeKey(replacement)] = replacement;
    }
    return _write(
      owner,
      GoogleCalendarLocalState(
        metadata: current.metadata,
        ranges: ranges.values.toList(),
      ),
    );
  });

  @override
  Future<GoogleCalendarLocalState> removeCalendars(
    GoogleCalendarCacheOwner owner,
    Set<String> calendarIds,
  ) => _schedule(() async {
    if (calendarIds.isEmpty) return _readAndPrune(owner);
    final current = await _readAndPrune(owner);
    final metadata = current.metadata;
    final nextMetadata =
        metadata == null
            ? null
            : GoogleCalendarSelectionMetadata(
              calendars:
                  metadata.calendars
                      .where((calendar) => !calendarIds.contains(calendar.id))
                      .toList(),
              selectedCalendarIds: metadata.selectedCalendarIds.difference(
                calendarIds,
              ),
              selectionEstablished: metadata.selectionEstablished,
              updatedAt: metadata.updatedAt,
            );
    final retainedRanges = <GoogleCalendarCachedRange>[];
    for (final range in current.ranges) {
      if (calendarIds.contains(range.calendarId)) continue;
      retainedRanges.add(
        GoogleCalendarCachedRange(
          calendarId: range.calendarId,
          range: range.range,
          fetchedAt: range.fetchedAt,
          events:
              range.events
                  .where((event) => !calendarIds.contains(event.calendarId))
                  .toList(),
        ),
      );
    }
    return _write(
      owner,
      GoogleCalendarLocalState(metadata: nextMetadata, ranges: retainedRanges),
    );
  });

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) =>
      _schedule(() async {
        try {
          final directory = await _ownerDirectory(owner);
          final type = await FileSystemEntity.type(
            directory.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.notFound) return;
          if (type == FileSystemEntityType.link) {
            await Link(directory.path).delete();
            return;
          }
          if (type != FileSystemEntityType.directory) {
            throw const GoogleCalendarLocalStoreException(
              GoogleCalendarLocalStoreError.corruptData,
              'The local calendar cache is invalid.',
            );
          }
          await directory.delete(recursive: true);
        } on GoogleCalendarLocalStoreException {
          rethrow;
        } on FileSystemException {
          throw const GoogleCalendarLocalStoreException(
            GoogleCalendarLocalStoreError.ioFailure,
            'The local calendar cache could not be cleared.',
          );
        } catch (_) {
          throw const GoogleCalendarLocalStoreException(
            GoogleCalendarLocalStoreError.unavailable,
            'The local calendar cache is unavailable.',
          );
        }
      });

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _operationTail;
  }

  Future<T> _schedule<T>(Future<T> Function() operation) {
    if (_disposed) {
      return Future<T>.error(
        const GoogleCalendarLocalStoreException(
          GoogleCalendarLocalStoreError.disposed,
          'The local calendar cache has been disposed.',
        ),
      );
    }
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<GoogleCalendarLocalState> _readAndPrune(
    GoogleCalendarCacheOwner owner,
  ) async {
    try {
      final directory = await _ownerDirectory(owner);
      final directoryType = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (directoryType == FileSystemEntityType.notFound) {
        return GoogleCalendarLocalState.empty;
      }
      if (directoryType != FileSystemEntityType.directory) {
        throw const GoogleCalendarLocalStoreException(
          GoogleCalendarLocalStoreError.corruptData,
          'The local calendar cache directory is invalid.',
        );
      }
      final file = File(path.join(directory.path, _stateFileName));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return GoogleCalendarLocalState.empty;
      }
      if (type != FileSystemEntityType.file) {
        throw const GoogleCalendarLocalStoreException(
          GoogleCalendarLocalStoreError.corruptData,
          'The local calendar cache is invalid.',
        );
      }
      final length = await file.length();
      if (length > _maxFileBytes) {
        throw const GoogleCalendarLocalStoreException(
          GoogleCalendarLocalStoreError.corruptData,
          'The local calendar cache exceeds its size limit.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        throw const GoogleCalendarLocalStoreException(
          GoogleCalendarLocalStoreError.corruptData,
          'The local calendar cache exceeds its size limit.',
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      final state = _decodeState(decoded);
      final pruned = _prune(state);
      if (pruned.changed) await _writeStateFile(directory, pruned.state);
      return pruned.state;
    } on GoogleCalendarLocalStoreException {
      rethrow;
    } on FormatException {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.corruptData,
        'The local calendar cache contains invalid data.',
      );
    } on FileSystemException {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.ioFailure,
        'The local calendar cache could not be read.',
      );
    } on TypeError {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.corruptData,
        'The local calendar cache contains invalid data.',
      );
    } catch (_) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.unavailable,
        'The local calendar cache is unavailable.',
      );
    }
  }

  Future<GoogleCalendarLocalState> _write(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarLocalState state,
  ) async {
    try {
      final directory = await _ownerDirectory(owner);
      final committed = _prune(state).state;
      await _writeStateFile(directory, committed);
      return committed;
    } on GoogleCalendarLocalStoreException {
      rethrow;
    } on FileSystemException {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.ioFailure,
        'The local calendar cache could not be saved.',
      );
    } on FormatException {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.corruptData,
        'The local calendar cache contains invalid data.',
      );
    } catch (_) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.unavailable,
        'The local calendar cache is unavailable.',
      );
    }
  }

  Future<void> _writeStateFile(
    Directory directory,
    GoogleCalendarLocalState state,
  ) async {
    await _ensureOwnerDirectory(directory);
    final bytes = utf8.encode(jsonEncode(_encodeState(state)));
    if (bytes.length > _maxFileBytes) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.ioFailure,
        'The local calendar cache exceeds its size limit.',
      );
    }
    final destination = File(path.join(directory.path, _stateFileName));
    final temporary = File(
      '${destination.path}.tmp.$pid.${_temporaryCounter++}.'
      '${Random.secure().nextInt(1 << 32)}',
    );
    try {
      await temporary.create(exclusive: true);
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<Directory> _ownerDirectory(GoogleCalendarCacheOwner owner) async {
    final root = await _directoryProvider();
    final normalizedRoot = Directory(path.normalize(path.absolute(root.path)));
    final rootType = await FileSystemEntity.type(
      normalizedRoot.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.link ||
        (rootType != FileSystemEntityType.notFound &&
            rootType != FileSystemEntityType.directory)) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.corruptData,
        'The local calendar cache root is invalid.',
      );
    }
    final canonicalOwner = jsonEncode(<String>[
      owner.nexecuteUserId,
      owner.googleAccountId,
    ]);
    final digest = sha256.convert(utf8.encode(canonicalOwner)).toString();
    return Directory(path.join(normalizedRoot.path, digest));
  }

  Future<void> _ensureOwnerDirectory(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory)) {
      throw const GoogleCalendarLocalStoreException(
        GoogleCalendarLocalStoreError.corruptData,
        'The local calendar cache directory is invalid.',
      );
    }
    if (type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
    }
  }

  _PrunedState _prune(GoogleCalendarLocalState state) {
    final now = _clock();
    final cutoff = now.subtract(_maxAge);
    final futureLimit = now.add(const Duration(minutes: 5));
    final ranges =
        state.ranges
            .where(
              (range) =>
                  !range.fetchedAt.isBefore(cutoff) &&
                  !range.fetchedAt.isAfter(futureLimit),
            )
            .toList()
          ..sort(_compareRanges);
    var eventCount = ranges.fold<int>(
      0,
      (sum, range) => sum + range.events.length,
    );
    while (ranges.length > _maxRanges || eventCount > _maxEvents) {
      eventCount -= ranges.removeAt(0).events.length;
    }
    ranges.sort((a, b) => _rangeKey(a).compareTo(_rangeKey(b)));
    final changed =
        ranges.length != state.ranges.length ||
        !_sameRangeOrder(ranges, state.ranges);
    return _PrunedState(
      GoogleCalendarLocalState(metadata: state.metadata, ranges: ranges),
      changed,
    );
  }

  static int _compareRanges(
    GoogleCalendarCachedRange a,
    GoogleCalendarCachedRange b,
  ) {
    final fetchedComparison = a.fetchedAt.compareTo(b.fetchedAt);
    return fetchedComparison != 0
        ? fetchedComparison
        : _rangeKey(a).compareTo(_rangeKey(b));
  }

  static bool _sameRangeOrder(
    List<GoogleCalendarCachedRange> a,
    List<GoogleCalendarCachedRange> b,
  ) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!identical(a[index], b[index])) return false;
    }
    return true;
  }

  static String _rangeKey(GoogleCalendarCachedRange range) =>
      '${range.calendarId.length}:${range.calendarId}|'
      '${range.range.startInclusive.toIso8601String()}|'
      '${range.range.endExclusive.toIso8601String()}';

  Map<String, Object?> _encodeState(GoogleCalendarLocalState state) => {
    'version': _schemaVersion,
    'metadata':
        state.metadata == null ? null : _encodeMetadata(state.metadata!),
    'ranges': state.ranges.map(_encodeRange).toList(),
  };

  Map<String, Object?> _encodeMetadata(GoogleCalendarSelectionMetadata value) {
    if (value.calendars.length > _maxCalendars ||
        value.selectedCalendarIds.length > _maxSelectedCalendars) {
      throw const FormatException();
    }
    final calendarIds = value.calendars.map((calendar) => calendar.id).toSet();
    if (calendarIds.length != value.calendars.length ||
        !calendarIds.containsAll(value.selectedCalendarIds)) {
      throw const FormatException();
    }
    return {
      'calendars':
          value.calendars
              .map(
                (calendar) => {
                  'id': _checkedString(calendar.id, identifier: true),
                  'name': _checkedString(calendar.name),
                  'accessRole': _checkedString(calendar.accessRole),
                  'defaultSelected': calendar.defaultSelected,
                  'colorValue': calendar.colorValue,
                  'timeZone': _checkedNullableString(calendar.timeZone),
                  'isPrimary': calendar.isPrimary,
                },
              )
              .toList(),
      'selectedCalendarIds':
          (value.selectedCalendarIds.toList()..sort())
              .map((id) => _checkedString(id, identifier: true))
              .toList(),
      'selectionEstablished': value.selectionEstablished,
      'updatedAt': value.updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> _encodeRange(GoogleCalendarCachedRange value) {
    if (!value.range.endExclusive.isAfter(value.range.startInclusive) ||
        value.events.any(
          (event) =>
              event.calendarId != value.calendarId ||
              event.endTime.isBefore(event.startTime) ||
              (!event.isAllDay && !event.endTime.isAfter(event.startTime)) ||
              (event.externalUrl != null &&
                  (event.externalUrl!.scheme != 'https' ||
                      event.externalUrl!.host.isEmpty)),
        ) ||
        value.events.map((event) => event.sourceScopedId).toSet().length !=
            value.events.length) {
      throw const FormatException();
    }
    return {
      'calendarId': _checkedString(value.calendarId, identifier: true),
      'start': value.range.startInclusive.toIso8601String(),
      'end': value.range.endExclusive.toIso8601String(),
      'fetchedAt': value.fetchedAt.toIso8601String(),
      'events':
          value.events
              .map(
                (event) => {
                  'sourceScopedId': _checkedString(
                    event.sourceScopedId,
                    identifier: true,
                  ),
                  'calendarId': _checkedString(
                    event.calendarId,
                    identifier: true,
                  ),
                  'title': _checkedString(event.title),
                  'description': _checkedString(event.description),
                  'startTime': event.startTime.toIso8601String(),
                  'endTime': event.endTime.toIso8601String(),
                  'isAllDay': event.isAllDay,
                  'calendarName': _checkedString(event.calendarName),
                  'calendarColorValue': event.calendarColorValue,
                  'sourceTimeZone': _checkedNullableString(
                    event.sourceTimeZone,
                  ),
                  'externalUrl':
                      event.externalUrl == null
                          ? null
                          : _checkedString(
                            event.externalUrl.toString(),
                            url: true,
                          ),
                },
              )
              .toList(),
    };
  }

  GoogleCalendarLocalState _decodeState(Object? value) {
    final map = _map(value);
    _exactKeys(map, const {'version', 'metadata', 'ranges'});
    if (_integer(map['version']) != _schemaVersion) {
      throw const FormatException();
    }
    final rangesJson = _list(map['ranges'], maximum: _maxDecodedRanges);
    var eventCount = 0;
    final ranges = <GoogleCalendarCachedRange>[];
    final rangeKeys = <String>{};
    for (final rangeJson in rangesJson) {
      final range = _decodeRange(rangeJson);
      if (!rangeKeys.add(_rangeKey(range))) throw const FormatException();
      eventCount += range.events.length;
      if (eventCount > _maxDecodedEvents) throw const FormatException();
      ranges.add(range);
    }
    return GoogleCalendarLocalState(
      metadata:
          map['metadata'] == null ? null : _decodeMetadata(map['metadata']),
      ranges: ranges,
    );
  }

  GoogleCalendarSelectionMetadata _decodeMetadata(Object? value) {
    final map = _map(value);
    _exactKeys(map, const {
      'calendars',
      'selectedCalendarIds',
      'selectionEstablished',
      'updatedAt',
    });
    final calendars =
        _list(
          map['calendars'],
          maximum: _maxCalendars,
        ).map(_decodeCalendar).toList();
    final selectedValues =
        _list(
          map['selectedCalendarIds'],
          maximum: _maxSelectedCalendars,
        ).map((value) => _string(value, identifier: true)).toList();
    final selected = selectedValues.toSet();
    final calendarIds = calendars.map((calendar) => calendar.id).toSet();
    if (selected.length != selectedValues.length ||
        calendarIds.length != calendars.length ||
        !calendarIds.containsAll(selected)) {
      throw const FormatException();
    }
    final updatedAt = _date(map['updatedAt']);
    if (updatedAt.isAfter(_clock().add(const Duration(minutes: 5)))) {
      throw const FormatException();
    }
    return GoogleCalendarSelectionMetadata(
      calendars: calendars,
      selectedCalendarIds: selected,
      selectionEstablished: _boolean(map['selectionEstablished']),
      updatedAt: updatedAt,
    );
  }

  GoogleCalendarInfo _decodeCalendar(Object? value) {
    final map = _map(value);
    _exactKeys(map, const {
      'id',
      'name',
      'accessRole',
      'defaultSelected',
      'colorValue',
      'timeZone',
      'isPrimary',
    });
    return GoogleCalendarInfo(
      id: _string(map['id'], identifier: true),
      name: _string(map['name']),
      accessRole: _string(map['accessRole']),
      defaultSelected: _boolean(map['defaultSelected']),
      colorValue: _nullableInteger(map['colorValue']),
      timeZone: _nullableString(map['timeZone']),
      isPrimary: _boolean(map['isPrimary']),
    );
  }

  GoogleCalendarCachedRange _decodeRange(Object? value) {
    final map = _map(value);
    _exactKeys(map, const {
      'calendarId',
      'start',
      'end',
      'fetchedAt',
      'events',
    });
    final calendarId = _string(map['calendarId'], identifier: true);
    final start = _date(map['start']);
    final end = _date(map['end']);
    if (!end.isAfter(start)) throw const FormatException();
    final events =
        _list(
          map['events'],
          maximum: _maxDecodedEvents,
        ).map(_decodeEvent).toList();
    if (events.any((event) => event.calendarId != calendarId) ||
        events.map((event) => event.sourceScopedId).toSet().length !=
            events.length) {
      throw const FormatException();
    }
    return GoogleCalendarCachedRange(
      calendarId: calendarId,
      range: CalendarQueryRange(startInclusive: start, endExclusive: end),
      fetchedAt: _date(map['fetchedAt']),
      events: events,
    );
  }

  GoogleCalendarCachedEvent _decodeEvent(Object? value) {
    final map = _map(value);
    _exactKeys(map, const {
      'sourceScopedId',
      'calendarId',
      'title',
      'description',
      'startTime',
      'endTime',
      'isAllDay',
      'calendarName',
      'calendarColorValue',
      'sourceTimeZone',
      'externalUrl',
    });
    final externalUrl = _nullableString(map['externalUrl'], url: true);
    final parsedUrl = externalUrl == null ? null : Uri.tryParse(externalUrl);
    if (externalUrl != null &&
        (parsedUrl == null ||
            parsedUrl.scheme != 'https' ||
            parsedUrl.host.isEmpty)) {
      throw const FormatException();
    }
    final startTime = _date(map['startTime']);
    final endTime = _date(map['endTime']);
    final isAllDay = _boolean(map['isAllDay']);
    if (endTime.isBefore(startTime) ||
        (!isAllDay && !endTime.isAfter(startTime))) {
      throw const FormatException();
    }
    return GoogleCalendarCachedEvent(
      sourceScopedId: _string(map['sourceScopedId'], identifier: true),
      calendarId: _string(map['calendarId'], identifier: true),
      title: _string(map['title']),
      description: _string(map['description']),
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      calendarName: _string(map['calendarName']),
      calendarColorValue: _nullableInteger(map['calendarColorValue']),
      sourceTimeZone: _nullableString(map['sourceTimeZone']),
      externalUrl: parsedUrl,
    );
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }

  static List<Object?> _list(Object? value, {required int maximum}) {
    if (value is! List || value.length > maximum) throw const FormatException();
    return value.cast<Object?>();
  }

  static void _exactKeys(Map<String, Object?> map, Set<String> keys) {
    if (map.length != keys.length || !map.keys.every(keys.contains)) {
      throw const FormatException();
    }
  }

  static String _checkedString(
    String value, {
    bool identifier = false,
    bool url = false,
  }) {
    final maximum =
        identifier
            ? _maxIdentifierLength
            : (url ? _maxUrlLength : _maxStringLength);
    if (value.length > maximum || (identifier && value.isEmpty)) {
      throw const FormatException();
    }
    return value;
  }

  static String? _checkedNullableString(String? value) =>
      value == null ? null : _checkedString(value);

  static String _string(
    Object? value, {
    bool identifier = false,
    bool url = false,
  }) {
    if (value is! String) throw const FormatException();
    return _checkedString(value, identifier: identifier, url: url);
  }

  static String? _nullableString(Object? value, {bool url = false}) =>
      value == null ? null : _string(value, url: url);

  static bool _boolean(Object? value) {
    if (value is! bool) throw const FormatException();
    return value;
  }

  static int _integer(Object? value) {
    if (value is! int) throw const FormatException();
    return value;
  }

  static int? _nullableInteger(Object? value) =>
      value == null ? null : _integer(value);

  static DateTime _date(Object? value) {
    final text = _string(value, identifier: true);
    final parsed = DateTime.parse(text);
    if (parsed.toIso8601String() != text) throw const FormatException();
    return parsed;
  }
}

final class _PrunedState {
  const _PrunedState(this.state, this.changed);

  final GoogleCalendarLocalState state;
  final bool changed;
}
