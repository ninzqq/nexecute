import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/presentation/assistant_particle_background.dart';
import 'package:nexecute/shared/app_particle_background.dart';
import 'package:nexecute/themes.dart';

void main() {
  testWidgets('keeps one particle field behind every application route', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final initialPainter = _painter(tester);
    expect(find.byKey(const Key('app-particle-layer')), findsOneWidget);
    expect(find.text('First page'), findsOneWidget);
    _expectTransparentScaffold(tester);

    await tester.tap(find.byKey(const Key('open-second-page')));
    await tester.pumpAndSettle();

    expect(find.text('Second page'), findsOneWidget);
    expect(find.byKey(const Key('app-particle-layer')), findsOneWidget);
    expect(_painter(tester).animation, same(initialPainter.animation));
    _expectTransparentScaffold(tester);
  });

  testWidgets('keeps dialogs and sheets readable above the shared field', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Dialog surface'), findsOneWidget);
    expect(find.byKey(const Key('app-particle-layer')), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.text('Dialog surface')),
      ).dialogTheme.backgroundColor,
      isNot(Colors.transparent),
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Sheet surface'), findsOneWidget);
    expect(find.byKey(const Key('app-particle-layer')), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.text('Sheet surface')),
      ).bottomSheetTheme.modalBackgroundColor,
      isNot(Colors.transparent),
    );
  });
}

Widget _app() => MaterialApp(
  theme: AppThemes.forPreset(AppThemePreset.midnight),
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: AppParticleBackground(child: child!),
      ),
  routes: {'/second': (_) => const _TestPage(title: 'Second page')},
  home: const _TestPage(title: 'First page'),
);

class _TestPage extends StatelessWidget {
  const _TestPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Wrap(
        spacing: 8,
        children: [
          FilledButton(
            key: const Key('open-second-page'),
            onPressed: () => Navigator.pushNamed(context, '/second'),
            child: const Text('Open page'),
          ),
          FilledButton(
            key: const Key('open-dialog'),
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Dialog surface'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                ),
            child: const Text('Open dialog'),
          ),
          FilledButton(
            key: const Key('open-sheet'),
            onPressed:
                () => showModalBottomSheet<void>(
                  context: context,
                  builder:
                      (_) => const SizedBox(
                        height: 160,
                        child: Center(child: Text('Sheet surface')),
                      ),
                ),
            child: const Text('Open sheet'),
          ),
        ],
      ),
    ),
  );
}

AssistantParticlePainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const Key('app-particle-paint')))
            .painter!
        as AssistantParticlePainter;

void _expectTransparentScaffold(WidgetTester tester) {
  expect(
    Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
    Colors.transparent,
  );
  expect(
    _painter(tester).backgroundColor,
    AppThemes.forPreset(AppThemePreset.midnight).scaffoldBackgroundColor,
  );
}
