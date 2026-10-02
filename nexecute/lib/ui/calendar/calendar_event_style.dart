import 'package:flutter/material.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/themes.dart';

Color calendarEventAccent(BuildContext context, CalendarDisplayEvent event) {
  final value = event.calendarColorValue;
  return value == null ? context.appPalette.primary : Color(value);
}

Color calendarEventBackground(
  BuildContext context,
  CalendarDisplayEvent event,
) {
  final accent = calendarEventAccent(context, event);
  return Color.alphaBlend(
    accent.withValues(alpha: event.isStale ? 0.10 : 0.18),
    context.appPalette.surfaceRaised,
  );
}

String calendarEventAccessibilityLabel(
  CalendarDisplayEvent event,
  String schedule,
) {
  final details = <String>[
    event.title,
    schedule,
    event.calendarName,
    if (event.source != CalendarEventSource.nexecute) 'Read-only',
    if (event.isStale) 'Saved copy',
  ];
  return details.join(', ');
}
