import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/shared/app_particle_background.dart';
import 'package:provider/provider.dart';

import '../test/support/fake_ai_dependencies.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profiles representative animated Assistant interactions', (
    tester,
  ) async {
    final response = StreamController<AiStreamEvent>();
    final profile = AiConnectionProfile(
      id: 'performance',
      name: 'Performance model',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'fixture',
    );
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final conversations = FakeAiConversationStore();
    final repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) => response.stream,
    );
    addTearDown(profiles.dispose);
    addTearDown(conversations.dispose);

    await tester.pumpWidget(
      _performanceApp(
        repository: repository,
        profiles: profiles,
        conversations: conversations,
      ),
    );
    await _pumpFrames(tester, 30);
    expect(find.byKey(const Key('app-particle-layer')), findsOneWidget);

    await binding.watchPerformance(() async {
      final composer = find.byKey(const Key('assistant-composer'));
      await tester.tap(composer);
      await _pumpFrames(tester, 30);

      for (var index = 1; index <= 30; index++) {
        await tester.enterText(composer, 'Performance message $index');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pump();

      for (var index = 0; index < 120; index++) {
        response.add(
          AiTextDelta(
            'Streaming response segment $index adds enough content to '
            'exercise layout and scrolling. ',
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      response.add(const AiResponseCompleted());
      await _pumpFrames(tester, 15);

      final conversation = find.byType(Scrollable).first;
      for (var index = 0; index < 8; index++) {
        await tester.drag(conversation, const Offset(0, -240));
        await _pumpFrames(tester, 5);
      }

      final originalSize = tester.view.physicalSize;
      final ratio = tester.view.devicePixelRatio;
      for (final logicalSize in const [
        Size(600, 900),
        Size(1000, 700),
        Size(800, 800),
      ]) {
        tester.view.physicalSize = logicalSize * ratio;
        await _pumpFrames(tester, 12);
      }
      tester.view.physicalSize = originalSize;
      await _pumpFrames(tester, 12);
    }, reportKey: 'assistant_particles');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(response.close());

    final metrics = binding.reportData!['assistant_particles']!;
    final summary = metrics as Map<String, dynamic>;
    final compactSummary = {
      for (final key in const [
        'frame_count',
        'average_frame_build_time_millis',
        '90th_percentile_frame_build_time_millis',
        '99th_percentile_frame_build_time_millis',
        'missed_frame_build_budget_count',
        'average_frame_rasterizer_time_millis',
        '90th_percentile_frame_rasterizer_time_millis',
        '99th_percentile_frame_rasterizer_time_millis',
        'missed_frame_rasterizer_budget_count',
        'new_gen_gc_count',
        'old_gen_gc_count',
      ])
        key: summary[key],
    };
    debugPrint('ASSISTANT_PARTICLE_PERFORMANCE ${jsonEncode(compactSummary)}');

    expect(summary['frame_count'] as int, greaterThan(100));
    expect(
      summary['90th_percentile_frame_build_time_millis'] as double,
      lessThan(16),
    );
    expect(
      summary['90th_percentile_frame_rasterizer_time_millis'] as double,
      lessThan(16),
    );
  });
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _performanceApp({
  required AiAssistantRepository repository,
  required AiConnectionProfileStore profiles,
  required AiConversationStore conversations,
}) => MultiProvider(
  providers: [
    Provider<AiAssistantRepository>.value(value: repository),
    Provider<AiConnectionProfileStore>.value(value: profiles),
    Provider<AiConversationStore>.value(value: conversations),
    Provider<AiApplicationContextReadService>(
      create: (_) => FakeAiApplicationContextReadService(),
    ),
  ],
  child: MaterialApp(
    theme: AppThemes.forPreset(AppThemePreset.cyberpunkMega),
    builder: (context, child) => AppParticleBackground(child: child!),
    home: const AssistantPage(),
  ),
);
