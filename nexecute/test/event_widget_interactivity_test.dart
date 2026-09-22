import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/services/event_widget_interactivity.dart';

void main() {
  test('parses an arbitrary month navigation request', () {
    final request = MonthWidgetNavigationRequest.tryParse(
      Uri.parse('nexecute://month-widget?widgetId=42&year=2036&month=1'),
    );

    expect(request?.widgetId, 42);
    expect(request?.anchor, DateTime(2036, 1));
  });

  test('rejects malformed month navigation requests', () {
    expect(
      MonthWidgetNavigationRequest.tryParse(
        Uri.parse('nexecute://month-widget?widgetId=42&year=2036&month=13'),
      ),
      isNull,
    );
    expect(
      MonthWidgetNavigationRequest.tryParse(
        Uri.parse('nexecute://another-action?widgetId=42&year=2036&month=1'),
      ),
      isNull,
    );
  });
}
