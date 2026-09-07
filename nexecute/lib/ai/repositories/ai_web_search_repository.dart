import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_web_search.dart';

abstract interface class AiWebSearchRepository {
  bool get isAvailable;

  Future<AiConnectionResult> testConnection(
    AiWebSearchConnectionProfile profile,
  );

  Future<AiWebSearchResponseHandle> startSearch(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
  );
}

final class AiWebSearchCancelledException implements Exception {
  const AiWebSearchCancelledException([this.cause]);

  final Object? cause;
}
