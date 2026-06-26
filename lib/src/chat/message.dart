import 'content_part.dart';
import 'tool_call.dart';

class ChatMessage {
  const ChatMessage._({
    required this.role,
    required this.content,
    this.contentParts,
    this.toolCallId,
    this.toolCalls = const [],
  });

  factory ChatMessage.system(String content) =>
      ChatMessage._(role: 'system', content: content);

  factory ChatMessage.user(Object content) {
    final normalized = _messageContent(content);
    return ChatMessage._(
      role: 'user',
      content: normalized.content,
      contentParts: normalized.contentParts,
    );
  }

  factory ChatMessage.assistant(
    String? content, {
    List<ChatToolCall> toolCalls = const [],
  }) =>
      ChatMessage._(role: 'assistant', content: content, toolCalls: toolCalls);

  factory ChatMessage.toolResult({
    required String toolCallId,
    required String content,
  }) => ChatMessage._(role: 'tool', content: content, toolCallId: toolCallId);

  final String role;
  final Object? content;
  final List<ContentPart>? contentParts;
  final String? toolCallId;
  final List<ChatToolCall> toolCalls;

  Map<String, dynamic> toJson({List<ContentPart>? contentPartsOverride}) {
    final json = <String, dynamic>{'role': role};
    if (contentPartsOverride != null) {
      json['content'] = [
        for (final part in contentPartsOverride) part.toJson(),
      ];
    } else if (content != null) {
      json['content'] = content;
    } else if (role == 'assistant') {
      json['content'] = null;
    }
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    if (toolCalls.isNotEmpty) {
      json['tool_calls'] = [
        for (final toolCall in toolCalls) toolCall.toJson(),
      ];
    }
    return json;
  }
}

_NormalizedMessageContent _messageContent(Object content) {
  if (content is String) {
    return _NormalizedMessageContent(content: content);
  }
  if (content is List<ContentPart>) {
    return _NormalizedMessageContent(
      content: [for (final part in content) part.toJson()],
      contentParts: List<ContentPart>.unmodifiable(content),
    );
  }
  throw ArgumentError.value(
    content,
    'content',
    'Must be a String or List<ContentPart>.',
  );
}

class _NormalizedMessageContent {
  const _NormalizedMessageContent({required this.content, this.contentParts});

  final Object content;
  final List<ContentPart>? contentParts;
}
