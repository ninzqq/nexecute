import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/home/screens/settingsscreen.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/models/calendar_settings_controller.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

import 'support/fake_ai_dependencies.dart';

void main() {
  testWidgets('bottom sheet content stays above the system bottom inset', (
    tester,
  ) async {
    const systemBottomInset = 48.0;

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: systemBottomInset),
          viewPadding: EdgeInsets.only(bottom: systemBottomInset),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(
            child: BottomSheetSafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(key: Key('bottom-sheet-content'), height: 20),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getBottomRight(find.byKey(const Key('bottom-sheet-content'))).dy,
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
          systemBottomInset,
    );
  });

  testWidgets('settings body protects its bottom edge', (tester) async {
    final profileStore = FakeAiConnectionProfileStore();
    addTearDown(profileStore.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeController()),
          ChangeNotifierProvider(create: (_) => CalendarSettingsController()),
          Provider<AiConnectionProfileStore>.value(value: profileStore),
          Provider<AiCredentialStore>.value(value: FakeAiCredentialStore()),
          Provider<AiAssistantRepository>.value(
            value: FakeAiAssistantRepository(),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.body, isA<SafeArea>());
    final safeArea = scaffold.body! as SafeArea;
    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
  });
}
