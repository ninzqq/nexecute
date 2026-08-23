import 'package:test/test.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';

void main() {
  group('IsoWeekCalculator', () {
    final calculator = IsoWeekCalculator();

    test('Week starts on Monday', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14)); // Wednesday
      expect(week.start.weekday, DateTime.monday);
    });

    test('Week ends on Sunday', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14));
      expect(week.end.weekday, DateTime.sunday);
    });

    test('Week contains exactly 7 days', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14));
      expect(week.days.length, 7);
    });

    test('Days are consecutive', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14));

      for (int i = 0; i < 6; i++) {
        final current = week.days[i].date;
        final next = week.days[i + 1].date;
        expect(next.difference(current).inDays, 1);
      }
    });

    test('ISO week number is correct (middle of year)', () {
      final week = calculator.fromDate(DateTime(2024, 6, 12));
      expect(week.weekNumber, 24);
    });

    test('ISO week number is correct at year start', () {
      final week = calculator.fromDate(DateTime(2024, 1, 1));
      expect(week.weekNumber, 1);
    });

    test('ISO week number handles year boundary', () {
      final week = calculator.fromDate(DateTime(2023, 12, 31));
      expect(week.weekNumber, 52);
    });

    test('ISO year can differ from calendar year', () {
      final week = calculator.fromDate(DateTime(2021, 1, 1));
      expect(week.year, 2020);
    });

    test('Next week increments correctly', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14));
      final next = calculator.nextWeek(week);

      expect(next.weekNumber, week.weekNumber + 1);
      expect(next.start.difference(week.start).inDays, 7);
    });

    test('Previous week decrements correctly', () {
      final week = calculator.fromDate(DateTime(2024, 2, 14));
      final prev = calculator.previousWeek(week);

      expect(prev.weekNumber, week.weekNumber - 1);
      expect(week.start.difference(prev.start).inDays, 7);
    });

    test('June 10 2024 is Monday of week 24', () {
      final week = calculator.fromDate(DateTime(2024, 6, 10));
      expect(week.weekNumber, 24);
      expect(week.start, DateTime(2024, 6, 10));
    });

    test('next week advances across the autumn daylight-saving change', () {
      final week = calculator.fromDate(DateTime(2026, 10, 19));
      final next = calculator.nextWeek(week);

      expect(next.start, DateTime(2026, 10, 26));
      expect(next.end, DateTime(2026, 11, 1));
    });

    test('previous week advances across the spring daylight-saving change', () {
      final week = calculator.fromDate(DateTime(2026, 3, 30));
      final previous = calculator.previousWeek(week);

      expect(previous.start, DateTime(2026, 3, 23));
      expect(previous.end, DateTime(2026, 3, 29));
    });
  });
}
