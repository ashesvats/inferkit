import '../chat/phase.dart';
import '../chat/tool_call.dart';
import 'tool_registry.dart';

enum AgentFinalReason { stop, length, contentFilter, maxIterations, unknown }

sealed class AgentEvent {
  const AgentEvent();
}

class AgentPhaseChanged extends AgentEvent {
  const AgentPhaseChanged(this.phase);

  final Phase phase;
}

class AgentReasoningDelta extends AgentEvent {
  const AgentReasoningDelta(this.text, {this.isSummary = false});

  final String text;
  final bool isSummary;
}

class AgentContentDelta extends AgentEvent {
  const AgentContentDelta(this.text);

  final String text;
}

class AgentToolStarted extends AgentEvent {
  const AgentToolStarted(this.toolCall, {required this.iteration});

  final ChatToolCall toolCall;
  final int iteration;
}

class AgentToolCallsRequested extends AgentEvent {
  const AgentToolCallsRequested(this.toolCalls, {required this.iteration});

  final List<ChatToolCall> toolCalls;
  final int iteration;
}

class AgentToolFinished extends AgentEvent {
  const AgentToolFinished(this.result, {required this.iteration});

  final ToolExecutionResult result;
  final int iteration;
}

class AgentToolFailed extends AgentEvent {
  const AgentToolFailed(this.result, {required this.iteration});

  final ToolExecutionResult result;
  final int iteration;
}

class AgentFinalAnswer extends AgentEvent {
  const AgentFinalAnswer(
    this.text, {
    required this.reason,
    this.forced = false,
    this.finishReason,
  });

  final String text;
  final AgentFinalReason reason;
  final bool forced;
  final String? finishReason;
}

class AgentMaxIterationsReached extends AgentEvent {
  const AgentMaxIterationsReached(this.maxIterations);

  final int maxIterations;
}

class AgentDone extends AgentEvent {
  const AgentDone();
}

class AgentFailed extends AgentEvent {
  const AgentFailed(this.error);

  final Object error;
}
