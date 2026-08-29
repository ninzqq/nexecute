import 'package:nexecute/ai/domain/ai_stream_event.dart';

abstract interface class AiResponseHandle {
  Stream<AiStreamEvent> get events;

  Future<void> cancel();
}

class StreamAiResponseHandle implements AiResponseHandle {
  StreamAiResponseHandle({
    required this.events,
    required Future<void> Function() onCancel,
  }) : _onCancel = onCancel;

  @override
  final Stream<AiStreamEvent> events;

  final Future<void> Function() _onCancel;
  Future<void>? _cancellation;

  @override
  Future<void> cancel() => _cancellation ??= _onCancel();
}
