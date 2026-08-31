import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';

class FakeAiAssistantRepository implements AiAssistantRepository {
  FakeAiAssistantRepository({
    this.connectionResult = const AiConnectionResult.connected(),
    this.models = const [],
    this.responseEvents = const [AiResponseCompleted()],
    this.responseStreamBuilder,
    this.startResponseError,
    this.listModelsError,
  });

  AiConnectionResult connectionResult;
  List<AiModelInfo> models;
  List<AiStreamEvent> responseEvents;
  Stream<AiStreamEvent> Function(AiChatRequest request)? responseStreamBuilder;
  Object? startResponseError;
  Object? listModelsError;
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
    if (listModelsError case final error?) throw error;
    return List.unmodifiable(models);
  }

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    startedRequests.add(request);
    if (startResponseError case final error?) throw error;
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

class FakeAiCredentialStore implements AiCredentialStore {
  FakeAiCredentialStore({
    this.isAvailable = true,
    Map<String, String> credentials = const {},
  }) : credentials = Map.of(credentials);

  @override
  final bool isAvailable;
  final Map<String, String> credentials;
  final List<String> savedCredentials = [];
  final List<String> readReferences = [];
  final List<String> deletedReferences = [];
  int _nextReference = 1;

  @override
  Future<String> saveCredential(String credential) async {
    if (!isAvailable) {
      throw const AiCredentialStoreException('Credential store unavailable.');
    }
    final reference = 'secure-storage:fake-${_nextReference++}';
    credentials[reference] = credential;
    savedCredentials.add(credential);
    return reference;
  }

  @override
  Future<String?> readCredential(String reference) async {
    if (!isAvailable) {
      throw const AiCredentialStoreException('Credential store unavailable.');
    }
    readReferences.add(reference);
    return credentials[reference];
  }

  @override
  Future<void> deleteCredential(String reference) async {
    if (!isAvailable) {
      throw const AiCredentialStoreException('Credential store unavailable.');
    }
    credentials.remove(reference);
    deletedReferences.add(reference);
  }
}

class FakeAiConversationStore extends InMemoryAiConversationStore {
  FakeAiConversationStore({super.conversations});

  int watchConversationsCallCount = 0;

  @override
  Stream<List<AiConversation>> watchConversations() {
    watchConversationsCallCount += 1;
    return super.watchConversations();
  }
}

class FakeAiApplicationContextReadService
    implements AiApplicationContextReadService {
  FakeAiApplicationContextReadService({DateTime? generatedAt})
    : generatedAt = generatedAt ?? DateTime.utc(2026, 8, 29);

  final DateTime generatedAt;
  AiApplicationContextEnvelope? tasksContext;
  AiApplicationContextEnvelope? eventsContext;
  AiNoteSearchContextResult? noteSearchResult;
  AiApplicationContextEnvelope? noteContext;
  int taskReadCount = 0;
  int eventReadCount = 0;
  int noteSearchCount = 0;
  int noteReadCount = 0;

  AiApplicationContextEnvelope get _empty => AiApplicationContextEnvelope(
    generatedAt: generatedAt,
    attachments: const [],
  );

  @override
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  }) async {
    taskReadCount++;
    return tasksContext ?? _empty;
  }

  @override
  Future<AiApplicationContextEnvelope> eventsForDateRange({
    required AiApplicationReadScope scope,
    required CalendarQueryRange range,
    int limit = AiApplicationContextLimits.maxEvents,
  }) async {
    eventReadCount++;
    return eventsContext ?? _empty;
  }

  @override
  Future<AiApplicationContextEnvelope> getNote({
    required AiApplicationReadScope scope,
    required String noteId,
  }) async {
    noteReadCount++;
    return noteContext ?? _empty;
  }

  @override
  Future<AiNoteSearchContextResult> searchNotes({
    required AiApplicationReadScope scope,
    required String query,
    int limit = AiApplicationContextReadLimits.maxSearchResults,
  }) async {
    noteSearchCount++;
    return noteSearchResult ??
        AiNoteSearchContextResult(context: _empty, sourceNoteIds: const []);
  }
}
