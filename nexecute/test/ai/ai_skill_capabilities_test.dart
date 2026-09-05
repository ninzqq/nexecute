import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  final profile = AiConnectionProfile(
    id: 'p',
    name: 'P',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('http://localhost/v1'),
    modelId: 'm',
    contextWindowTokens: 32768,
    capabilityOverrides: const {AiCapability.tools: true},
  );
  AiSkill skill(Set<String> capabilities) => AiSkill(
    id: 'reader',
    name: 'Reader',
    description: 'Read only',
    instructions: 'Use authorized reads.',
    capabilities: capabilities,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  AiChatRequest request(
    AiConnectionProfile p,
    Set<String> capabilities,
    AiReadToolAuthorization? authorization,
  ) => AiChatRequest(
    connectionProfile: p,
    conversationId: 'c',
    messages: const [],
    resolvedSkills: [AiResolvedSkillInvocation.fromSkill(skill(capabilities))],
    readToolAuthorization: authorization,
  );

  test(
    'access intersects declarations, installed capabilities, model support, and authorization',
    () {
      final authorization = AiReadToolAuthorization(
        allowActiveTasks: true,
        allowNoteSearch: true,
      );
      expect(
        request(profile, {
          'listTasks',
        }, authorization).toolDefinitions.map((t) => t.name),
        ['listTasks'],
      );
      expect(request(profile, {'listTasks'}, null).toolDefinitions, isEmpty);
      expect(
        request(profile.copyWith(capabilityOverrides: {}), {
          'listTasks',
        }, authorization).toolDefinitions,
        isEmpty,
      );
      expect(request(profile, {}, authorization).toolDefinitions, isEmpty);
      expect(() => skill({'deleteNote'}), throwsFormatException);
      expect(
        AiReadCapabilityRegistry.registrations.keys.toSet(),
        aiSkillCapabilityIds,
      );
    },
  );

  test(
    'codec preserves capability revision identity and rejects arbitrary bindings',
    () {
      final value = skill({'searchNotes', 'getNote'});
      final decoded = AiSkillMarkdownCodec.decode(
        AiSkillMarkdownCodec.encode(value),
        sourceFileName: 'SKILL.md',
        importedAt: DateTime.utc(2026),
      );
      expect(decoded.capabilities, value.capabilities);
      expect(decoded.contentHash, value.contentHash);
      expect(
        value.copyWith(capabilities: {'getNote'}).contentHash,
        isNot(value.contentHash),
      );
      expect(() => value.capabilities.add('listTasks'), throwsUnsupportedError);
    },
  );

  test(
    'undeclared calls are rejected before repository reads, even with request authorization',
    () async {
      late FakeAiAssistantRepository repository;
      repository = FakeAiAssistantRepository(
        responseStreamBuilder:
            (_) => Stream.fromIterable(
              repository.startedRequests.length == 1
                  ? [
                    AiToolCallRequested(
                      id: 'call',
                      name: 'searchNotes',
                      arguments: const {'query': 'secret', 'limit': 1},
                    ),
                    const AiResponseCompleted(),
                  ]
                  : [
                    const AiTextDelta('Access unavailable'),
                    const AiResponseCompleted(),
                  ],
            ),
      );
      final reads = FakeAiApplicationContextReadService();
      final authorization = AiReadToolAuthorization(
        allowActiveTasks: true,
        allowNoteSearch: true,
      );
      final coordinator = AiReadToolCoordinator(
        assistantRepository: repository,
        readService: reads,
      );
      final handle = await coordinator.startResponse(
        request(profile, {'listTasks'}, authorization),
        scope: AiReadToolExecutionScope(authorization: authorization),
      );
      await handle.events.toList();
      expect(reads.noteSearchCount, 0);
      final result =
          repository.startedRequests.last.continuationMessages
              .whereType<AiToolResultMessage>()
              .single;
      expect(result.isError, isTrue);
      expect(result.result['code'], 'unauthorized');
      expect(
        repository.startedRequests.last.toolDefinitions.map((t) => t.name),
        ['listTasks'],
      );
    },
  );
}
