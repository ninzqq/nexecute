import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';

class FakeAiAssistantRepository implements AiAssistantRepository {
  FakeAiAssistantRepository({
    this.connectionResult = const AiConnectionResult.connected(),
    this.models = const [],
    this.responseEvents = const [AiResponseCompleted()],
    this.responseStreamBuilder,
    this.startResponseError,
  });

  AiConnectionResult connectionResult;
  List<AiModelInfo> models;
  List<AiStreamEvent> responseEvents;
  Stream<AiStreamEvent> Function(AiChatRequest request)? responseStreamBuilder;
  Object? startResponseError;
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

class FakeAiConversationStore extends InMemoryAiConversationStore {
  FakeAiConversationStore({super.conversations});
}

class FakeAiApplicationContextReadService
    implements AiApplicationContextReadService {
  FakeAiApplicationContextReadService({DateTime? generatedAt})
    : generatedAt = generatedAt ?? DateTime.utc(2026, 8, 29);

  final DateTime generatedAt;
  AiApplicationContextEnvelope? tasksContext;
  AiApplicationContextEnvelope? eventsContext;
  AiNoteSearchContextResult? noteSearchResult;

  AiApplicationContextEnvelope get _empty => AiApplicationContextEnvelope(
    generatedAt: generatedAt,
    attachments: const [],
  );

  @override
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  }) async => tasksContext ?? _empty;

  @override
  Future<AiApplicationContextEnvelope> eventsForDateRange({
    required AiApplicationReadScope scope,
    required CalendarQueryRange range,
    int limit = AiApplicationContextLimits.maxEvents,
  }) async => eventsContext ?? _empty;

  @override
  Future<AiApplicationContextEnvelope> getNote({
    required AiApplicationReadScope scope,
    required String noteId,
  }) async => _empty;

  @override
  Future<AiNoteSearchContextResult> searchNotes({
    required AiApplicationReadScope scope,
    required String query,
    int limit = AiApplicationContextReadLimits.maxSearchResults,
  }) async =>
      noteSearchResult ??
      AiNoteSearchContextResult(context: _empty, sourceNoteIds: const []);
}
