import 'package:flutter/material.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/ui/calendar/week_view.dart';

final calculator = IsoWeekCalculator();
final week = calculator.fromDate(DateTime.now());

class WeekCalendar extends StatelessWidget {
  const WeekCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WeekView(week: week));
  }
}
