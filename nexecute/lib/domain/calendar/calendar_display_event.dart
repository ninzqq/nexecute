import 'package:nexecute/models/event.dart';

final class CalendarEventSource {
  const CalendarEventSource(this.id, {required this.displayName});

  static const nexecute = CalendarEventSource(
    'nexecute',
    displayName: 'Nexecute',
  );

  final String id;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CalendarEventSource && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class CalendarEventIdentity {
  const CalendarEventIdentity({
    required this.source,
    required this.sourceScopedId,
  });

  final CalendarEventSource source;
  final String sourceScopedId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventIdentity &&
          other.source == source &&
          other.sourceScopedId == sourceScopedId;

  @override
  int get hashCode => Object.hash(source, sourceScopedId);

  @override
  String toString() => '${source.id}:$sourceScopedId';
}

final class CalendarEventCapabilities {
  const CalendarEventCapabilities({
    required this.canEdit,
    required this.canDelete,
    required this.canOpenExternally,
  });

  static const native = CalendarEventCapabilities(
    canEdit: true,
    canDelete: true,
    canOpenExternally: false,
  );

  static const readOnly = CalendarEventCapabilities(
    canEdit: false,
    canDelete: false,
    canOpenExternally: false,
  );

  final bool canEdit;
  final bool canDelete;
  final bool canOpenExternally;
}

final class CalendarDisplayEvent {
  CalendarDisplayEvent({
    required this.identity,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.calendarName,
    required this.capabilities,
    this.description = '',
    this.calendarColorValue,
    this.sourceTimeZone,
    this.externalUrl,
    this.isStale = false,
    this.nativeEvent,
  }) {
    if (nativeEvent != null &&
        identity.source != CalendarEventSource.nexecute) {
      throw ArgumentError.value(
        identity.source.id,
        'identity',
        'Native events must use the Nexecute source',
      );
    }
    if (nativeEvent == null &&
        (capabilities.canEdit || capabilities.canDelete)) {
      throw ArgumentError.value(
        capabilities,
        'capabilities',
        'External events cannot expose native mutation capabilities',
      );
    }
  }

  factory CalendarDisplayEvent.native(Event event) {
    final occurrenceSuffix =
        event.isGeneratedOccurrence
            ? '@${event.startTime.toUtc().microsecondsSinceEpoch}'
            : '';
    return CalendarDisplayEvent(
      identity: CalendarEventIdentity(
        source: CalendarEventSource.nexecute,
        sourceScopedId: '${event.id}$occurrenceSuffix',
      ),
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      isAllDay: event.isAllDay,
      calendarName: CalendarEventSource.nexecute.displayName,
      capabilities: CalendarEventCapabilities.native,
      nativeEvent: event,
    );
  }

  final CalendarEventIdentity identity;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String calendarName;
  final int? calendarColorValue;
  final String? sourceTimeZone;
  final Uri? externalUrl;
  final bool isStale;
  final CalendarEventCapabilities capabilities;
  final Event? nativeEvent;

  CalendarEventSource get source => identity.source;

  bool get canMutateNatively =>
      source == CalendarEventSource.nexecute &&
      nativeEvent != null &&
      capabilities.canEdit &&
      capabilities.canDelete;
}

int compareCalendarDisplayEvents(
  CalendarDisplayEvent first,
  CalendarDisplayEvent second,
) {
  var comparison = first.startTime.compareTo(second.startTime);
  if (comparison != 0) return comparison;
  if (first.isAllDay != second.isAllDay) return first.isAllDay ? -1 : 1;
  comparison = first.endTime.compareTo(second.endTime);
  if (comparison != 0) return comparison;
  if (first.source == CalendarEventSource.nexecute &&
      second.source != CalendarEventSource.nexecute) {
    return -1;
  }
  if (second.source == CalendarEventSource.nexecute &&
      first.source != CalendarEventSource.nexecute) {
    return 1;
  }
  comparison = first.source.id.compareTo(second.source.id);
  if (comparison != 0) return comparison;
  comparison = first.title.toLowerCase().compareTo(second.title.toLowerCase());
  if (comparison != 0) return comparison;
  return first.identity.sourceScopedId.compareTo(
    second.identity.sourceScopedId,
  );
}
