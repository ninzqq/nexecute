import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/event_recurrence_field.dart';
import 'package:nexecute/models/event_recurrence.dart';

void main() {
  testWidgets('offers daily, weekly, monthly, and yearly recurrence', (
    tester,
  ) async {
    EventRecurrence? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventRecurrenceField(
            recurrence: EventRecurrence.none,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();

    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    expect(selected, EventRecurrence.yearly);
  });
}
