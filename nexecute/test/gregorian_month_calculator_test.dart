import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('GregorianMonthCalculator', () {
    final calculator = GregorianMonthCalculator();

    test('builds complete Monday-to-Sunday weeks', () {
      final month = calculator.fromDate(DateTime(2024, 2, 14));

      expect(month.start, DateTime(2024, 2, 1));
      expect(month.end, DateTime(2024, 2, 29));
      expect(month.days.first.date.weekday, DateTime.monday);
      expect(month.days.last.date.weekday, DateTime.sunday);
      expect(month.days.length, month.weeks.length * 7);
    });

    test('includes leading and trailing days needed by the grid', () {
      final month = calculator.fromDate(DateTime(2024, 2));

      expect(month.days.first.date, DateTime(2024, 1, 29));
      expect(month.days.last.date, DateTime(2024, 3, 3));
    });

    test('moves across year boundaries', () {
      final december = calculator.fromDate(DateTime(2024, 12));
      final january = calculator.nextMonth(december);
      final previous = calculator.previousMonth(january);

      expect(january.year, 2025);
      expect(january.month, DateTime.january);
      expect(previous.year, 2024);
      expect(previous.month, DateTime.december);
    });

    test('contains only dates in its calendar month', () {
      final month = calculator.fromDate(DateTime(2024, 2));

      expect(month.contains(DateTime(2024, 2, 1)), isTrue);
      expect(month.contains(DateTime(2024, 1, 31)), isFalse);
      expect(month.contains(DateTime(2025, 2, 1)), isFalse);
    });
  });
}
