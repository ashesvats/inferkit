import '../core/exceptions.dart';
import 'choice.dart';
import 'message.dart';
import 'reasoning_config.dart';
import 'tool_call.dart';
import 'usage.dart';

class ChatCompletionResponse {
  const ChatCompletionResponse({
    required this.id,
    required this.model,
    required this.choices,
    this.created,
    this.usage,
  });

  final String id;
  final String model;
  final int? created;
  final List<ChatCompletionChoice> choices;
  final Usage? usage;

  String get text {
    if (choices.isEmpty) return '';
    final content = choices.first.message.content;
    return content is String ? content : '';
  }

  List<ChatToolCall> get toolCalls {
    if (choices.isEmpty) return const [];
    return choices.first.message.toolCalls;
  }

  factory ChatCompletionResponse.fromJson(
    Map<String, dynamic> json, {
    ReasoningConfig reasoning = ReasoningConfig.defaults,
  }) {
    final choicesJson = json['choices'];
    if (choicesJson is! List) {
      throw const InvalidResponseException(
        'The inference server returned no choices.',
      );
    }
    return ChatCompletionResponse(
      id: json['id'] is String ? json['id'] as String : '',
      model: json['model'] is String ? json['model'] as String : '',
      created: json['created'] is num ? (json['created'] as num).toInt() : null,
      usage: json['usage'] is Map ? Usage.fromJson(json['usage'] as Map) : null,
      choices: [
        for (var i = 0; i < choicesJson.length; i++)
          _choiceFromJson(choicesJson[i], i, reasoning),
      ],
    );
  }
}

ChatCompletionChoice _choiceFromJson(
  Object? raw,
  int fallbackIndex,
  ReasoningConfig reasoning,
) {
  if (raw is! Map) {
    throw const InvalidResponseException('A chat choice was malformed.');
  }
  final message = raw['message'];
  if (message is! Map) {
    throw const InvalidResponseException('A chat choice had no message.');
  }
  final content = message['content'];
  final toolCalls = message['tool_calls'];
  final extracted = _extractReasoning(content, message, reasoning);
  return ChatCompletionChoice(
    index: raw['index'] is num ? (raw['index'] as num).toInt() : fallbackIndex,
    finishReason:
        raw['finish_reason'] is String ? raw['finish_reason'] as String : null,
    reasoningText: extracted.reasoning,
    reasoningSummaryText: extracted.summaries,
    message: ChatMessage.assistant(
      extracted.content,
      toolCalls: [
        if (toolCalls is List)
          for (var i = 0; i < toolCalls.length; i++)
            if (toolCalls[i] is Map)
              ChatToolCall.fromJson(toolCalls[i] as Map, index: i),
      ],
    ),
  );
}

_ExtractedReasoning _extractReasoning(
  Object? content,
  Map<dynamic, dynamic> message,
  ReasoningConfig config,
) {
  final visibleContent = _contentText(content);
  if (!config.emitEvents) {
    return _ExtractedReasoning(content: visibleContent);
  }
  final reasoning = <String>[];
  final summaries = <String>[];
  for (final key in config.contentKeys) {
    final value = message[key];
    if (value is String && value.isNotEmpty) reasoning.add(value);
  }
  for (final key in config.summaryKeys) {
    final value = message[key];
    if (value is String && value.isNotEmpty) summaries.add(value);
  }
  final tags = config.inlineTags;
  if (tags == null || visibleContent.isEmpty) {
    return _ExtractedReasoning(
      content: visibleContent,
      reasoning: reasoning,
      summaries: summaries,
    );
  }
  final stripped = _stripInlineReasoning(visibleContent, tags);
  return _ExtractedReasoning(
    content: stripped.content,
    reasoning: [...reasoning, ...stripped.reasoning],
    summaries: summaries,
  );
}

String _contentText(Object? content) {
  if (content is String) return content;
  if (content is! List) return '';
  final buffer = StringBuffer();
  for (final part in content) {
    if (part is! Map) continue;
    final text = part['text'];
    if (text is String) buffer.write(text);
  }
  return buffer.toString();
}

_InlineStripResult _stripInlineReasoning(
  String source,
  ReasoningTagConfig tags,
) {
  final content = StringBuffer();
  final reasoning = <String>[];
  var remaining = source;
  while (remaining.isNotEmpty) {
    final openIndex = remaining.indexOf(tags.openTag);
    if (openIndex == -1) {
      content.write(remaining);
      break;
    }
    content.write(remaining.substring(0, openIndex));
    final afterOpen = openIndex + tags.openTag.length;
    final closeIndex = remaining.indexOf(tags.closeTag, afterOpen);
    if (closeIndex == -1) {
      reasoning.add(remaining.substring(afterOpen));
      break;
    }
    reasoning.add(remaining.substring(afterOpen, closeIndex));
    remaining = remaining.substring(closeIndex + tags.closeTag.length);
  }
  return _InlineStripResult(content: content.toString(), reasoning: reasoning);
}

class _ExtractedReasoning {
  const _ExtractedReasoning({
    required this.content,
    this.reasoning = const [],
    this.summaries = const [],
  });

  final String content;
  final List<String> reasoning;
  final List<String> summaries;
}

class _InlineStripResult {
  const _InlineStripResult({required this.content, required this.reasoning});

  final String content;
  final List<String> reasoning;
}
