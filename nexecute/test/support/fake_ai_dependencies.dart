import 'package:nexecute/ai/ai.dart';

class FakeAiAssistantRepository implements AiAssistantRepository {
  FakeAiAssistantRepository({
    this.connectionResult = const AiConnectionResult.connected(),
    this.models = const [],
    this.responseEvents = const [AiResponseCompleted()],
    this.responseStreamBuilder,
  });

  AiConnectionResult connectionResult;
  List<AiModelInfo> models;
  List<AiStreamEvent> responseEvents;
  Stream<AiStreamEvent> Function(AiChatRequest request)? responseStreamBuilder;
  final testedProfiles = <AiConnectionProfile>[];
  final listedProfiles = <AiConnectionProfile>[];
  final startedRequests = <AiChatRequest>[];
  int cancellationCount = 0;

  @override
  Future<AiConnectionResult> testConnection(AiConnectionProfile profile) async {
    testedProfiles.add(profile);
    return connectionResult;
  }

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) async {
    listedProfiles.add(profile);
    return List.unmodifiable(models);
  }

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    startedRequests.add(request);
    return StreamAiResponseHandle(
      events:
          responseStreamBuilder?.call(request) ??
          Stream.fromIterable(responseEvents),
      onCancel: () async => cancellationCount += 1,
    );
  }
}

class FakeAiConnectionProfileStore extends InMemoryAiConnectionProfileStore {
  FakeAiConnectionProfileStore({super.profiles, super.activeProfileId});
}

class FakeAiConversationStore extends InMemoryAiConversationStore {
  FakeAiConversationStore({super.conversations});
}
