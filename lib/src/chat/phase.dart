import 'dart:async';

import 'completion_stream.dart';

enum Phase { idle, reasoning, answering, toolCalling, done, failed }

class ChatStream {
  ChatStream(Stream<ChatCompletionStreamEvent> source) {
    _events = _track(source).asBroadcastStream();
  }

  Phase _phase = Phase.idle;
  late final Stream<ChatCompletionStreamEvent> _events;
  final StreamController<Phase> _phaseChanges =
      StreamController<Phase>.broadcast();

  Phase get phase => _phase;

  Stream<Phase> get phaseChanges => _phaseChanges.stream;

  Stream<ChatCompletionStreamEvent> get events => _events;

  Stream<ChatCompletionStreamEvent> _track(
    Stream<ChatCompletionStreamEvent> source,
  ) async* {
    try {
      await for (final event in source) {
        switch (event) {
          case ReasoningEvent():
            _setPhase(Phase.reasoning);
          case ContentDeltaEvent():
            _setPhase(Phase.answering);
          case ToolCallDeltaEvent():
            _setPhase(Phase.toolCalling);
          case DoneEvent():
            _setPhase(Phase.done);
          case UsageEvent():
            break;
        }
        yield event;
      }
    } catch (_) {
      _setPhase(Phase.failed);
      rethrow;
    } finally {
      unawaited(_phaseChanges.close());
    }
  }

  void _setPhase(Phase next) {
    if (_phase == next) return;
    _phase = next;
    _phaseChanges.add(next);
  }
}
