import 'package:nexecute/models/event_recurrence.dart';

extension EventRecurrenceLabels on EventRecurrence {
  String get editorLabel => switch (this) {
    EventRecurrence.none => 'Does not repeat',
    EventRecurrence.daily => 'Daily',
    EventRecurrence.weekly => 'Weekly',
    EventRecurrence.monthly => 'Monthly',
    EventRecurrence.yearly => 'Yearly',
  };

  String get detailsLabel => switch (this) {
    EventRecurrence.none => 'Does not repeat',
    EventRecurrence.daily => 'Repeats daily',
    EventRecurrence.weekly => 'Repeats weekly',
    EventRecurrence.monthly => 'Repeats monthly',
    EventRecurrence.yearly => 'Repeats yearly',
  };
}
