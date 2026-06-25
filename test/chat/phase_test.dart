import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

void main() {
  test('tracks phase transitions without duplicate emissions', () async {
    final tracked =
        Stream<ChatCompletionStreamEvent>.fromIterable(const [
          ReasoningEvent('thinking'),
          ReasoningEvent('more'),
          ContentDeltaEvent('answer'),
          ToolCallDeltaEvent(index: 0, name: 'lookup'),
          DoneEvent(),
        ]).trackPhase();

    final phasesFuture = tracked.phaseChanges.toList();
    await tracked.events.drain<void>();

    expect(await phasesFuture, [
      Phase.reasoning,
      Phase.answering,
      Phase.toolCalling,
      Phase.done,
    ]);
    expect(tracked.phase, Phase.done);
  });
}
