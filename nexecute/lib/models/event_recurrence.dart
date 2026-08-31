enum EventRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  bool get repeats => this != EventRecurrence.none;

  static EventRecurrence fromStorage(Object? value) {
    return EventRecurrence.values.firstWhere(
      (recurrence) => recurrence.name == value,
      orElse: () => EventRecurrence.none,
    );
  }
}
