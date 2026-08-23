import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ui/calendar/month_view.dart';

void main() {
  test('shows every event when all markers fit in a month cell', () {
    expect(visibleMonthEventCount(eventCount: 3, availableHeight: 63), 3);
  });

  test('reserves room for the overflow count when events do not fit', () {
    expect(visibleMonthEventCount(eventCount: 4, availableHeight: 63), 2);
  });

  test('uses extra height for additional visible event markers', () {
    final compactCount = visibleMonthEventCount(
      eventCount: 4,
      availableHeight: 44,
    );
    final tallCount = visibleMonthEventCount(
      eventCount: 4,
      availableHeight: 82,
    );

    expect(compactCount, 1);
    expect(tallCount, 4);
  });
}
