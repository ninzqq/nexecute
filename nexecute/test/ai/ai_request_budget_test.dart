import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/ai/application/ai_request_budget.dart';

void main() {
  final profile = AiConnectionProfile(
    id: 'p',
    name: 'P',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('http://localhost/v1'),
    modelId: 'm',
    allowMultipleSkills: true,
  );
  AiChatRequest request({
    int? window,
    String text = 'Moi',
    List<AiResolvedSkillInvocation> skills = const [],
  }) => AiChatRequest(
    connectionProfile: profile.copyWith(contextWindowTokens: window),
    conversationId: 'c',
    messages: [
      AiChatMessage(
        id: 'u',
        role: AiMessageRole.user,
        content: text,
        createdAt: DateTime.utc(2026),
      ),
    ],
    resolvedSkills: skills,
    systemInstruction: const AiPromptComposer().compose(
      profilePreferences: profile.systemPrompt,
      resolvedSkills: skills,
    ),
  );
  test('exact conservative boundary accepts equality and rejects one less', () {
    final required = AiRequestBudget.estimate(request(text: 'ää😀'));
    expect(
      () => AiRequestBudget.validate(request(window: required, text: 'ää😀')),
      returnsNormally,
    );
    expect(
      () =>
          AiRequestBudget.validate(request(window: required - 1, text: 'ää😀')),
      throwsA(isA<AiRequestBudgetException>()),
    );
    expect(
      AiRequestBudget.estimate(request(text: 'ää😀')) -
          AiRequestBudget.estimate(request(text: 'a')),
      7,
    );
  });
  test(
    'whole-turn history remains bounded without mutating saved messages',
    () {
      final messages = List.generate(
        40,
        (i) => AiChatMessage(
          id: '$i',
          role: i.isEven ? AiMessageRole.user : AiMessageRole.assistant,
          content: '$i',
          createdAt: DateTime.utc(2026),
        ),
      );
      final retained = AiRequestBudget.history(messages);
      expect(retained.length, 24);
      expect(retained.first.id, '16');
      expect(messages.length, 40);
      expect(
        AiRequestBudget.history([
          ...messages,
          AiChatMessage(
            id: '40',
            role: AiMessageRole.user,
            content: 'next',
            createdAt: DateTime.utc(2026),
          ),
        ]).first.id,
        '18',
      );
    },
  );
  test(
    'large skills are preserved and combined instructions have a hard cap',
    () {
      AiResolvedSkillInvocation skill(String id, int count) =>
          AiResolvedSkillInvocation.fromSkill(
            AiSkill(
              id: id,
              name: id,
              description: 'Test',
              instructions: 'ä' * count,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      final skills = [skill('a', 16000), skill('b', 16000)];
      expect(
        () => AiRequestBudget.validate(request(window: 131072, skills: skills)),
        returnsNormally,
      );
      expect(
        () => AiRequestBudget.validate(
          request(window: 131072, skills: [...skills, skill('c', 1)]),
        ),
        throwsA(isA<AiRequestBudgetException>()),
      );
      expect(skills.first.instructions.runes.length, 16000);
    },
  );
}
