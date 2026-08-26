import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  testWidgets(
    'switches between three destinations and updates the add action',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => HomeTabIndex()),
            ChangeNotifierProvider(create: (_) => SelectedDay()),
            Provider<EventRepository>.value(value: FakeEventRepository()),
            Provider<DataState<List<TodoItem>>>.value(
              value: const DataEmpty([]),
            ),
            Provider<DataState<List<Quicxec>>>.value(
              value: const DataEmpty([]),
            ),
            Provider<DataState<models.Tags>>.value(
              value: DataEmpty(models.Tags()),
            ),
          ],
          child: MaterialApp(
            theme: AppThemes.forPreset(AppThemePreset.midnight),
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byTooltip('New note'), findsOneWidget);
      expect(find.text('New note'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(tester.getSize(find.byType(NavigationBar)).height, 64);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New task'), findsOneWidget);
      expect(find.text('New task'), findsNothing);
      expect(find.text('0 tasks open'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New event'), findsOneWidget);
      expect(find.text('New event'), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      expect(find.byKey(const Key('calendar-toolbar')), findsOneWidget);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Nexecute'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tapAt(const Offset(790, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New event'));
      await tester.pumpAndSettle();

      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    },
  );
}
