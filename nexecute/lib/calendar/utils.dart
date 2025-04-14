import 'dart:collection';
import 'dart:async';
import 'package:nexecute/models/event.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nexecute/services/firestore.dart';

/// Example events.
///
/// Using a [LinkedHashMap] is highly recommended if you decide to use a map.
final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
);

StreamSubscription? _eventsSubscription;

void initializeEventStream(FirestoreService firestoreService) {
  _eventsSubscription?.cancel(); // Peruuta vanha stream jos sellainen on
  
  _eventsSubscription = firestoreService.streamEvents().listen((events) {
    kEvents.clear(); // Tyhjennä nykyinen kokoelma
    
    for (var event in events) {
      final date = DateTime.utc(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      
      if (kEvents[date] == null) {
        kEvents[date] = [];
      }
      kEvents[date]!.add(event);
    }
  });
}

// Muista peruuttaa subscription kun et enää tarvitse sitä
void disposeEventStream() {
  _eventsSubscription?.cancel();
  _eventsSubscription = null;
}

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

final kToday = DateTime.now();
final kFirstDay = DateTime(2025, 1, 1);
final kLastDay = DateTime(2050, 12, 31);
