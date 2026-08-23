import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:test/test.dart';

void main() {
  group('combineDateAndTime', () {
    test('does not roll a late selected date into the following day', () {
      final selectedDate = DateTime(2026, 8, 27);
      final selectedTime = DateTime(2026, 8, 23, 23, 45, 12);

      final result = combineDateAndTime(selectedDate, selectedTime);

      expect(result, DateTime(2026, 8, 27, 23, 45, 12));
    });

    test('preserves the existing end time when its date changes', () {
      final selectedDate = DateTime(2026, 9, 10);
      final existingEndTime = DateTime(2026, 8, 24, 0, 30, 15, 250, 125);

      final result = combineDateAndTime(selectedDate, existingEndTime);

      expect(result, DateTime(2026, 9, 10, 0, 30, 15, 250, 125));
    });
  });
}
