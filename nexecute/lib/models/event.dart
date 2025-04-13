class Event {
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;

  const Event({
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
  });

  @override
  String toString() {
    return 'Event(title: $title, description: $description, startTime: $startTime, endTime: $endTime, isAllDay: $isAllDay)';
  }
}
