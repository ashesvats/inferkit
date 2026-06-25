import 'dart:async';

import '../chat/completion_request.dart';
import '../chat/completion_stream.dart';
import '../chat/message.dart';
import '../chat/phase.dart';
import '../chat/tool_call.dart';
import '../client.dart';
import '../core/semaphore.dart';
import 'agent_event.dart';
import 'agent_options.dart';
import 'tool_registry.dart';

class Agent {
  Agent({
    required InferKitClient client,
    required ToolRegistry tools,
    required AgentOptions options,
    bool disposeClient = false,
  }) : _client = client,
       _tools = tools,
       _options = options,
       _disposeClient = disposeClient,
       _limiter = Semaphore(options.concurrencyLimit);

  final InferKitClient _client;
  final ToolRegistry _tools;
  final AgentOptions _options;
  final bool _disposeClient;
  final Semaphore _limiter;

  void dispose() {
    if (_disposeClient) _client.dispose();
  }

  Stream<AgentEvent> run({
    required List<ChatMessage> messages,
    List<ToolSpec>? tools,
  }) {
    final controller = StreamController<AgentEvent>();
    unawaited(_run(controller, messages: messages, tools: tools));
    return controller.stream;
  }

  Future<void> _run(
    StreamController<AgentEvent> controller, {
    required List<ChatMessage> messages,
    List<ToolSpec>? tools,
  }) async {
    final workingMessages = List<ChatMessage>.of(messages);
    final runTools = tools == null ? _tools : ToolRegistry(tools);
    try {
      var iteration = 0;
      while (true) {
        final currentIteration = iteration + 1;
        final forceNoTools = iteration >= _options.maxIterations;
        if (forceNoTools) {
          controller.add(AgentMaxIterationsReached(_options.maxIterations));
        }
        final request = ChatCompletionRequest(
          model: _options.model,
          messages: workingMessages,
          tools: forceNoTools ? const [] : runTools.protocolTools,
          toolChoice: forceNoTools ? null : _options.toolChoice,
          temperature: _options.temperature,
        );
        final responseEvents = <ChatCompletionStreamEvent>[];
        await _limiter.withResource(() async {
          final tracked =
              _client.chat.completions.createStream(request).trackPhase();
          final phaseSubscription = tracked.phaseChanges.listen(
            (phase) => controller.add(AgentPhaseChanged(phase)),
          );
          try {
            await for (final event in tracked.events) {
              responseEvents.add(event);
              _addAgentEventsFor(controller, event);
            }
          } finally {
            await phaseSubscription.cancel();
          }
        });

        final response =
            await Stream<ChatCompletionStreamEvent>.fromIterable(
              responseEvents,
            ).collect();
        final text = response.text;
        final toolCalls = response.toolCalls;
        final finishReason =
            response.choices.isEmpty
                ? null
                : response.choices.first.finishReason;
        if (toolCalls.isEmpty || forceNoTools) {
          controller.add(
            AgentFinalAnswer(
              text,
              reason:
                  forceNoTools
                      ? AgentFinalReason.maxIterations
                      : _finalReasonFor(finishReason),
              forced: forceNoTools,
              finishReason: finishReason,
            ),
          );
          controller.add(const AgentDone());
          await controller.close();
          return;
        }

        workingMessages.add(ChatMessage.assistant(null, toolCalls: toolCalls));
        controller.add(const AgentPhaseChanged(Phase.toolCalling));
        controller.add(
          AgentToolCallsRequested(toolCalls, iteration: currentIteration),
        );
        final results = await _executeTools(
          controller,
          runTools,
          toolCalls,
          iteration: currentIteration,
        );
        for (final result in results) {
          controller.add(
            result.succeeded
                ? AgentToolFinished(result, iteration: currentIteration)
                : AgentToolFailed(result, iteration: currentIteration),
          );
          workingMessages.add(
            ChatMessage.toolResult(
              toolCallId: result.call.id,
              content: result.content,
            ),
          );
        }
        iteration++;
      }
    } catch (error) {
      controller.add(AgentFailed(error));
      controller.addError(error);
      await controller.close();
    }
  }

  AgentFinalReason _finalReasonFor(String? finishReason) {
    switch (finishReason) {
      case 'stop':
        return AgentFinalReason.stop;
      case 'length':
        return AgentFinalReason.length;
      case 'content_filter':
        return AgentFinalReason.contentFilter;
      default:
        return AgentFinalReason.unknown;
    }
  }

  void _addAgentEventsFor(
    StreamController<AgentEvent> controller,
    ChatCompletionStreamEvent event,
  ) {
    switch (event) {
      case ReasoningEvent():
        controller.add(
          AgentReasoningDelta(event.text, isSummary: event.isSummary),
        );
      case ContentDeltaEvent():
        controller.add(AgentContentDelta(event.text));
      case ToolCallDeltaEvent():
      case UsageEvent():
      case DoneEvent():
        break;
    }
  }

  Future<List<ToolExecutionResult>> _executeTools(
    StreamController<AgentEvent> controller,
    ToolRegistry registry,
    List<ChatToolCall> toolCalls, {
    required int iteration,
  }) async {
    Future<ToolExecutionResult> execute(ChatToolCall call) async {
      controller.add(AgentToolStarted(call, iteration: iteration));
      return registry.execute(call);
    }

    if (_options.parallelTools) {
      return Future.wait([for (final call in toolCalls) execute(call)]);
    }
    final results = <ToolExecutionResult>[];
    for (final call in toolCalls) {
      results.add(await execute(call));
    }
    return results;
  }
}
