import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';

void main() {
  group('monthQueryRange', () {
    test('buffers the visible month with one page in each direction', () {
      final calculator = GregorianMonthCalculator();
      final month = calculator.fromDate(DateTime(2026, 8, 15));
      final previousMonth = calculator.previousMonth(month);
      final nextMonth = calculator.nextMonth(month);

      final range = monthQueryRange(month, calculator);

      expect(range.startInclusive, previousMonth.weeks.first.start);
      expect(range.endExclusive, _nextDay(nextMonth.weeks.last.end));
    });
  });

  group('weekQueryRange', () {
    test('buffers the visible week with one page in each direction', () {
      final calculator = IsoWeekCalculator();
      final week = calculator.fromDate(DateTime(2026, 8, 25));
      final previousWeek = calculator.previousWeek(week);
      final nextWeek = calculator.nextWeek(week);

      final range = weekQueryRange(week, calculator);

      expect(range.startInclusive, previousWeek.start);
      expect(range.endExclusive, _nextDay(nextWeek.end));
    });
  });

  group('CalendarQueryRange.overlaps', () {
    final range = CalendarQueryRange(
      startInclusive: DateTime(2026, 8, 10),
      endExclusive: DateTime(2026, 8, 20),
    );

    test('includes events ending on the first visible day', () {
      expect(
        range.overlaps(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 10)),
        isTrue,
      );
    });

    test('excludes events starting at the exclusive upper boundary', () {
      expect(
        range.overlaps(
          start: DateTime(2026, 8, 20),
          end: DateTime(2026, 8, 21),
        ),
        isFalse,
      );
    });

    test('excludes events ending before the first visible day', () {
      expect(
        range.overlaps(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 9, 23, 59),
        ),
        isFalse,
      );
    });
  });
}

DateTime _nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
