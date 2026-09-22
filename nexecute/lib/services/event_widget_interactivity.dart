import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/firebase_options.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/event_widget_service.dart';

final class MonthWidgetNavigationRequest {
  const MonthWidgetNavigationRequest({
    required this.widgetId,
    required this.anchor,
  });

  final int widgetId;
  final DateTime anchor;

  static MonthWidgetNavigationRequest? tryParse(Uri? uri) {
    if (uri?.host != 'month-widget') return null;

    final widgetId = int.tryParse(uri!.queryParameters['widgetId'] ?? '');
    final year = int.tryParse(uri.queryParameters['year'] ?? '');
    final month = int.tryParse(uri.queryParameters['month'] ?? '');
    if (widgetId == null || widgetId < 0 || year == null || month == null) {
      return null;
    }
    if (year < 1 || year > 9999 || month < 1 || month > 12) return null;

    return MonthWidgetNavigationRequest(
      widgetId: widgetId,
      anchor: DateTime(year, month),
    );
  }
}

Future<void> registerEventWidgetInteractivity() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await HomeWidget.registerInteractivityCallback(
      eventWidgetInteractivityCallback,
    );
  } catch (_) {
    // Widget support must never prevent the main application from starting.
  }
}

@pragma('vm:entry-point')
Future<void> eventWidgetInteractivityCallback(Uri? uri) async {
  final request = MonthWidgetNavigationRequest.tryParse(uri);
  if (request == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final updater = EventWidgetService();
  try {
    final month = GregorianMonthCalculator().fromDate(request.anchor);
    final state = await FirestoreEventRepository(authService: AuthService())
        .watchEvents(monthGridQueryRange(month))
        .firstWhere((state) => state is! DataLoading<List<Event>>)
        .timeout(const Duration(seconds: 30));

    switch (state) {
      case DataReady<List<Event>>(:final value) ||
          DataEmpty<List<Event>>(:final value):
        await updater.updateMonthPage(
          value,
          anchor: request.anchor,
          widgetId: request.widgetId,
        );
      case DataUnauthenticated<List<Event>>():
        await updater.updateMonthPageStatus(
          widgetId: request.widgetId,
          message: 'Sign in to browse events',
        );
      case DataFailure<List<Event>>():
        await updater.updateMonthPageStatus(
          widgetId: request.widgetId,
          message: 'Could not load month',
        );
      case DataLoading<List<Event>>():
        break;
    }
  } catch (_) {
    await updater.updateMonthPageStatus(
      widgetId: request.widgetId,
      message: 'Could not load month',
    );
  }
}
