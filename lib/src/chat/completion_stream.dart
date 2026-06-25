import 'dart:async';
import 'dart:convert';

import '../core/exceptions.dart';
import '../core/json_utils.dart';
import 'choice.dart';
import 'completion_response.dart';
import 'message.dart';
import 'phase.dart';
import 'reasoning_config.dart';
import 'tool_call.dart';
import 'usage.dart';

sealed class ChatCompletionStreamEvent {
  const ChatCompletionStreamEvent();
}

class ReasoningEvent extends ChatCompletionStreamEvent {
  const ReasoningEvent(this.text, {this.isSummary = false});

  final String text;
  final bool isSummary;
}

class ContentDeltaEvent extends ChatCompletionStreamEvent {
  const ContentDeltaEvent(this.text);

  final String text;
}

class ToolCallDeltaEvent extends ChatCompletionStreamEvent {
  const ToolCallDeltaEvent({
    required this.index,
    this.id,
    this.name,
    this.argumentsChunk,
  });

  final int index;
  final String? id;
  final String? name;
  final String? argumentsChunk;
}

class UsageEvent extends ChatCompletionStreamEvent {
  const UsageEvent(this.usage);

  final Usage usage;
}

class DoneEvent extends ChatCompletionStreamEvent {
  const DoneEvent({this.finishReason});

  final String? finishReason;
}

extension ChatCompletionStreamExtensions on Stream<ChatCompletionStreamEvent> {
  ChatStream trackPhase() => ChatStream(this);

  Future<ChatCompletionResponse> collect() async {
    final content = StringBuffer();
    final toolCalls = <int, _ToolCallAccumulator>{};
    Usage? usage;
    String? finishReason;
    await for (final event in this) {
      switch (event) {
        case ContentDeltaEvent():
          content.write(event.text);
        case ToolCallDeltaEvent():
          final accumulator = toolCalls.putIfAbsent(
            event.index,
            () => _ToolCallAccumulator(event.index),
          );
          if (event.id != null && event.id!.isNotEmpty) {
            accumulator.id = event.id!;
          }
          if (event.name != null && event.name!.isNotEmpty) {
            accumulator.name += event.name!;
          }
          if (event.argumentsChunk != null &&
              event.argumentsChunk!.isNotEmpty) {
            accumulator.arguments += event.argumentsChunk!;
          }
        case UsageEvent():
          usage = event.usage;
        case DoneEvent():
          finishReason = event.finishReason ?? finishReason;
        case ReasoningEvent():
          break;
      }
    }
    return ChatCompletionResponse(
      id: '',
      model: '',
      usage: usage,
      choices: [
        ChatCompletionChoice(
          index: 0,
          finishReason: finishReason,
          message: ChatMessage.assistant(
            content.toString(),
            toolCalls: [
              for (final accumulator in toolCalls.values)
                if (accumulator.name.trim().isNotEmpty)
                  ChatToolCall(
                    id:
                        accumulator.id.trim().isEmpty
                            ? 'call_${accumulator.index}'
                            : accumulator.id,
                    function: ChatToolCallFunction(
                      name: accumulator.name,
                      arguments:
                          accumulator.arguments.trim().isEmpty
                              ? '{}'
                              : accumulator.arguments,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

Stream<ChatCompletionStreamEvent> parseChatCompletionStream(
  Stream<List<int>> source, {
  required ReasoningConfig reasoning,
  required Duration timeout,
}) async* {
  final inline = _InlineReasoningExtractor(reasoning);
  String? finishReason;
  try {
    await for (final line in source
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(timeout)) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') {
        final flushed = inline.flush();
        if (flushed != null) yield flushed;
        yield DoneEvent(finishReason: finishReason);
        continue;
      }
      final decoded = decodeJsonObject(data);
      final usage = decoded['usage'];
      if (usage is Map) yield UsageEvent(Usage.fromJson(usage));
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choice = choices.first;
      if (choice is Map && choice['finish_reason'] is String) {
        finishReason = choice['finish_reason'] as String;
      }
      final delta = choice is Map ? choice['delta'] : null;
      if (delta is! Map) continue;
      if (reasoning.emitEvents) {
        for (final key in reasoning.contentKeys) {
          final value = delta[key];
          if (value is String && value.isNotEmpty) {
            yield ReasoningEvent(value);
          }
        }
        for (final key in reasoning.summaryKeys) {
          final value = delta[key];
          if (value is String && value.isNotEmpty) {
            yield ReasoningEvent(value, isSummary: true);
          }
        }
      }
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        for (final event in inline.add(content)) {
          yield event;
        }
      }
      final toolCalls = delta['tool_calls'];
      if (toolCalls is List) {
        for (final rawToolCall in toolCalls) {
          if (rawToolCall is! Map) continue;
          final index =
              rawToolCall['index'] is num
                  ? (rawToolCall['index'] as num).toInt()
                  : 0;
          final function = rawToolCall['function'];
          yield ToolCallDeltaEvent(
            index: index,
            id:
                rawToolCall['id'] is String
                    ? rawToolCall['id'] as String
                    : null,
            name:
                function is Map && function['name'] is String
                    ? function['name'] as String
                    : null,
            argumentsChunk:
                function is Map && function['arguments'] is String
                    ? function['arguments'] as String
                    : null,
          );
        }
      }
    }
  } on TimeoutException {
    throw const InferKitTimeoutException('The chat stream timed out.');
  } on InferKitException {
    rethrow;
  } catch (error) {
    throw NetworkException('The chat stream failed: $error');
  }
}

class _InlineReasoningExtractor {
  _InlineReasoningExtractor(this.config);

  final ReasoningConfig config;
  final StringBuffer _reasoning = StringBuffer();
  final StringBuffer _content = StringBuffer();
  bool _insideReasoning = false;
  String _pending = '';

  Iterable<ChatCompletionStreamEvent> add(String chunk) sync* {
    final tags = config.inlineTags;
    if (!config.emitEvents || tags == null) {
      yield ContentDeltaEvent(chunk);
      return;
    }
    var text = _pending + chunk;
    _pending = '';
    while (text.isNotEmpty) {
      if (_insideReasoning) {
        final closeIndex = text.indexOf(tags.closeTag);
        if (closeIndex == -1) {
          if (_couldBePartialTag(text, tags.closeTag)) {
            final split = _partialTagStart(text, tags.closeTag);
            _reasoning.write(text.substring(0, split));
            _pending = text.substring(split);
          } else {
            _reasoning.write(text);
          }
          return;
        }
        _reasoning.write(text.substring(0, closeIndex));
        final reasoningText = _reasoning.toString();
        _reasoning.clear();
        if (reasoningText.isNotEmpty) yield ReasoningEvent(reasoningText);
        _insideReasoning = false;
        text = text.substring(closeIndex + tags.closeTag.length);
        continue;
      }
      final openIndex = text.indexOf(tags.openTag);
      if (openIndex == -1) {
        if (_couldBePartialTag(text, tags.openTag)) {
          final split = _partialTagStart(text, tags.openTag);
          _content.write(text.substring(0, split));
          _pending = text.substring(split);
        } else {
          _content.write(text);
        }
        final visible = _takeContent();
        if (visible.isNotEmpty) yield ContentDeltaEvent(visible);
        return;
      }
      _content.write(text.substring(0, openIndex));
      final visible = _takeContent();
      if (visible.isNotEmpty) yield ContentDeltaEvent(visible);
      _insideReasoning = true;
      text = text.substring(openIndex + tags.openTag.length);
    }
  }

  ChatCompletionStreamEvent? flush() {
    if (!config.emitEvents || config.inlineTags == null) {
      if (_pending.isEmpty) return null;
      final pending = _pending;
      _pending = '';
      return ContentDeltaEvent(pending);
    }
    if (_insideReasoning) {
      _reasoning.write(_pending);
      _pending = '';
      final text = _reasoning.toString();
      _reasoning.clear();
      return text.isEmpty ? null : ReasoningEvent(text);
    }
    _content.write(_pending);
    _pending = '';
    final text = _takeContent();
    return text.isEmpty ? null : ContentDeltaEvent(text);
  }

  String _takeContent() {
    final value = _content.toString();
    _content.clear();
    return value;
  }

  bool _couldBePartialTag(String text, String tag) =>
      _partialTagStart(text, tag) < text.length;

  int _partialTagStart(String text, String tag) {
    final max = text.length < tag.length - 1 ? text.length : tag.length - 1;
    for (var length = max; length > 0; length--) {
      if (tag.startsWith(text.substring(text.length - length))) {
        return text.length - length;
      }
    }
    return text.length;
  }
}

class _ToolCallAccumulator {
  _ToolCallAccumulator(this.index);

  final int index;
  String id = '';
  String name = '';
  String arguments = '';
}
