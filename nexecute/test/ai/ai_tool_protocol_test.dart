import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  AiConnectionProfile profile({
    AiProtocol protocol = AiProtocol.openAiCompatibleChat,
    Map<AiCapability, bool> overrides = const {},
  }) => AiConnectionProfile(
    id: 'home',
    name: 'Home model',
    protocol: protocol,
    baseUrl: Uri.parse('https://ai.example.test/v1'),
    modelId: 'local-model',
    capabilityOverrides: overrides,
  );

  test(
    'advertises only explicitly confirmed and user-authorized read tools',
    () {
      final authorization = AiReadToolAuthorization(
        allowActiveTasks: true,
        allowNoteSearch: true,
        eventRange: AiEventContextRange(
          startInclusive: DateTime.utc(2026, 8, 30),
          endExclusive: DateTime.utc(2026, 9, 2),
        ),
        allowedNoteReferences: const {'note_b', 'note_a'},
      );

      expect(
        AiReadToolCatalog.definitionsFor(
          profile: profile(),
          authorization: authorization,
        ),
        isEmpty,
      );
      expect(
        AiReadToolCatalog.definitionsFor(
          profile: profile(protocol: AiProtocol.openAiResponses),
          authorization: authorization,
        ),
        isEmpty,
        reason: 'A protocol default is not an explicit confirmation.',
      );
      expect(
        AiReadToolCatalog.definitionsFor(
          profile: profile(overrides: const {AiCapability.tools: true}),
        ),
        isEmpty,
      );

      final definitions = AiReadToolCatalog.definitionsFor(
        profile: profile(overrides: const {AiCapability.tools: true}),
        authorization: authorization,
      );

      expect(definitions.map((definition) => definition.name), [
        AiReadToolNames.listTasks,
        AiReadToolNames.eventsForDateRange,
        AiReadToolNames.searchNotes,
        AiReadToolNames.getNote,
      ]);
      for (final definition in definitions) {
        expect(definition.parameters.toJson()['additionalProperties'], isFalse);
      }
      final searchSchema = definitions[2].parameters.toJson();
      expect(searchSchema['required'], containsAll(['query', 'limit']));
      expect(
        (searchSchema['properties'] as Map)['query'],
        containsPair('minLength', 2),
      );
      final noteSchema = definitions.last.parameters.toJson();
      expect(
        ((noteSchema['properties'] as Map)['noteReference'] as Map)['enum'],
        ['note_a', 'note_b'],
      );
      expect(() => definitions.clear(), throwsUnsupportedError);
    },
  );

  test('authorization rejects excessive references and event ranges', () {
    expect(
      () => AiReadToolAuthorization(
        allowedNoteReferences: const {'one', 'two', 'three', 'four'},
      ),
      throwsArgumentError,
    );
    expect(
      () => AiReadToolAuthorization(
        allowedNoteReferences: const {'not a reference'},
      ),
      throwsArgumentError,
    );
    expect(
      () => AiReadToolAuthorization(
        eventRange: AiEventContextRange(
          startInclusive: DateTime.utc(2026, 8, 1),
          endExclusive: DateTime.utc(2026, 9, 2),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('tool calls and continuation messages expose immutable snapshots', () {
    final sourceArguments = <String, Object?>{'limit': 5};
    final call = AiToolCall(
      id: 'call-1',
      name: AiReadToolNames.listTasks,
      arguments: sourceArguments,
    );
    final sourceCalls = <AiToolCall>[call];
    final assistant = AiAssistantToolCallMessage(calls: sourceCalls);
    final sourceResult = <String, Object?>{'items': <Object?>[]};
    final result = AiToolResultMessage(
      toolCallId: call.id,
      toolName: call.name,
      result: sourceResult,
    );

    sourceArguments['limit'] = 10;
    sourceCalls.clear();
    sourceResult['unexpected'] = true;

    expect(call.arguments, {'limit': 5});
    expect(assistant.calls, [same(call)]);
    expect(result.result, {'items': <Object?>[]});
    expect(() => call.arguments.clear(), throwsUnsupportedError);
    expect(() => assistant.calls.clear(), throwsUnsupportedError);
    expect(() => result.result.clear(), throwsUnsupportedError);
    expect(
      () => (result.result['items']! as List<Object?>).clear(),
      throwsUnsupportedError,
    );
    expect(
      () => AiToolCall(
        id: 'invalid',
        name: 'invalid',
        arguments: {'date': DateTime.utc(2026, 8, 30)},
      ),
      throwsArgumentError,
    );
  });
}
