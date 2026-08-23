import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';

bool existingQuicxec(List<Quicxec> quicxecs, Quicxec? quicxec) {
  if (quicxec == null) {
    return false;
  }

  for (var q in quicxecs) {
    if (q.id == quicxec.id) {
      return true;
    }
  }
  return false;
}

bool existingEvent(List<Event> events, Event? event) {
  if (event == null) {
    return false;
  }

  for (var e in events) {
    if (e.id == event.id) {
      return true;
    }
  }
  return false;
}

String formatDate(DateTime dateTime) {
  return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
}

DateTime combineDateAndTime(DateTime date, DateTime time) {
  return date.isUtc
      ? DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      )
      : DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      );
}
