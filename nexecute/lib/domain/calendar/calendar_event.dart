class CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? note;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.note,
  });
}
