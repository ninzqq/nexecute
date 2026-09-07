import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/repositories/ai_web_search_repository.dart';

final class UnavailableAiWebSearchRepository implements AiWebSearchRepository {
  const UnavailableAiWebSearchRepository();

  @override
  bool get isAvailable => false;

  @override
  Future<AiConnectionResult> testConnection(
    AiWebSearchConnectionProfile profile,
  ) async => const AiConnectionResult(
    status: AiConnectionStatus.unsupported,
    message: 'The web-search adapter is not installed yet.',
  );

  @override
  Future<AiWebSearchResponseHandle> startSearch(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
  ) => throw UnsupportedError('The web-search adapter is not installed yet.');
}
