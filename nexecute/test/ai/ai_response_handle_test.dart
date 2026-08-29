import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test(
    'response handle exposes events and cancels its operation once',
    () async {
      var cancellationCount = 0;
      final handle = StreamAiResponseHandle(
        events: Stream.fromIterable(const [
          AiTextDelta('Hel'),
          AiTextDelta('lo'),
          AiResponseCompleted(finishReason: 'stop'),
        ]),
        onCancel: () async => cancellationCount += 1,
      );

      final events = await handle.events.toList();
      await Future.wait([handle.cancel(), handle.cancel()]);

      expect(events.whereType<AiTextDelta>().map((event) => event.text), [
        'Hel',
        'lo',
      ]);
      expect(events.last, isA<AiResponseCompleted>());
      expect(cancellationCount, 1);
    },
  );
}
