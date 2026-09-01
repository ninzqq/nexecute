import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/loginscreen/loginscreen.dart';
import 'package:nexecute/main.dart' as application;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS startup reaches authentication or the main shell', (
    tester,
  ) async {
    final app = await application.initializeNexecute();
    await tester.pumpWidget(app);

    Object? startupException;
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      startupException ??= tester.takeException();
      if (find.byType(LoginScreen).evaluate().isNotEmpty ||
          find.byType(HomeScreen).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(startupException, isNull);
    expect(
      find.byType(LoginScreen).evaluate().isNotEmpty ||
          find.byType(HomeScreen).evaluate().isNotEmpty,
      isTrue,
    );
  });
}
