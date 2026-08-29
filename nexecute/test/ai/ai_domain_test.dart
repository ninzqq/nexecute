import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('connection profile keeps credentials behind an opaque reference', () {
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home model',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
      authenticationMode: AiAuthenticationMode.bearerToken,
      credentialReference: 'secure-storage:home',
      reasoningEffort: AiReasoningEffort.low,
      maxOutputTokens: 2048,
      connectionTimeout: const Duration(seconds: 60),
      responseIdleTimeout: const Duration(seconds: 30),
      systemPrompt: 'Use short answers.',
      capabilityOverrides: const {AiCapability.tools: false},
    );

    expect(profile.isValid, isTrue);
    expect(profile.credentialReference, 'secure-storage:home');
    expect(profile.capabilityOverrides[AiCapability.tools], isFalse);
    expect(
      profile.capabilityState(AiCapability.streaming),
      AiCapabilityState.protocolDefault,
    );
    expect(
      profile.capabilityState(AiCapability.reasoning),
      AiCapabilityState.unconfirmed,
    );
    expect(
      profile.capabilityState(AiCapability.tools),
      AiCapabilityState.confirmedUnsupported,
    );
    expect(profile.supports(AiCapability.streaming), isTrue);
    expect(profile.supports(AiCapability.reasoning), isFalse);
    expect(profile.reasoningEffort, AiReasoningEffort.low);
    expect(profile.maxOutputTokens, 2048);
    expect(profile.connectionTimeout, const Duration(seconds: 60));
    expect(profile.responseIdleTimeout, const Duration(seconds: 30));
    expect(profile.systemPrompt, 'Use short answers.');
    expect(profile.copyWith(clearCredentialReference: true).isValid, isFalse);
    expect(
      profile.copyWith(baseUrl: Uri.parse('ftp://ai.example.test')).isValid,
      isFalse,
    );
    expect(profile.copyWith(maxOutputTokens: 0).isValid, isFalse);
    expect(profile.copyWith(connectionTimeout: Duration.zero).isValid, isFalse);
    expect(
      profile
          .copyWith(
            systemPrompt:
                List.filled(aiMaxSystemPromptCharacters + 1, 'x').join(),
          )
          .isValid,
      isFalse,
    );
  });

  test('conversation and request expose immutable message snapshots', () {
    final sourceMessages = <AiChatMessage>[
      AiChatMessage(
        id: 'message-1',
        role: AiMessageRole.user,
        content: 'Hello',
        createdAt: DateTime(2026, 8, 29),
      ),
    ];
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home model',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final conversation = AiConversation(
      id: 'conversation-1',
      title: 'First chat',
      connectionProfileId: profile.id,
      modelId: profile.modelId,
      createdAt: DateTime(2026, 8, 29),
      updatedAt: DateTime(2026, 8, 29),
      messages: sourceMessages,
    );
    final request = AiChatRequest(
      connectionProfile: profile,
      conversationId: conversation.id,
      messages: sourceMessages,
    );

    sourceMessages.add(
      AiChatMessage(
        id: 'message-2',
        role: AiMessageRole.assistant,
        content: 'Hi',
        createdAt: DateTime(2026, 8, 29),
      ),
    );

    expect(conversation.messages, hasLength(1));
    expect(request.messages, hasLength(1));
    expect(() => conversation.messages.clear(), throwsUnsupportedError);
    expect(() => request.messages.clear(), throwsUnsupportedError);
  });

  test('protocol-neutral events carry text, tools, usage, and failures', () {
    const delta = AiTextDelta('Hello');
    const reasoning = AiReasoningDelta('Consider the request');
    final toolCall = AiToolCallRequested(
      id: 'call-1',
      name: 'listTasks',
      arguments: const {'limit': 5},
    );
    const completed = AiResponseCompleted(
      finishReason: 'stop',
      usage: AiTokenUsage(inputTokens: 10, outputTokens: 4, totalTokens: 14),
    );
    final error = StateError('offline');
    final failed = AiResponseFailed(
      error: error,
      message: 'Endpoint unavailable',
      code: 'unreachable',
      retryable: true,
    );

    expect(delta.text, 'Hello');
    expect(reasoning.text, 'Consider the request');
    expect(toolCall.arguments['limit'], 5);
    expect(() => toolCall.arguments.clear(), throwsUnsupportedError);
    expect(completed.usage?.totalTokens, 14);
    expect(failed.error, same(error));
    expect(failed.retryable, isTrue);
  });
}
