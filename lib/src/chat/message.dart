import 'content_part.dart';
import 'tool_call.dart';

class ChatMessage {
  const ChatMessage._({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls = const [],
  });

  factory ChatMessage.system(String content) =>
      ChatMessage._(role: 'system', content: content);

  factory ChatMessage.user(Object content) =>
      ChatMessage._(role: 'user', content: _messageContent(content));

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
  final String? toolCallId;
  final List<ChatToolCall> toolCalls;

  Map<String, dynamic> toJson() => {
    'role': role,
    if (content != null) 'content': content,
    if (content == null && role == 'assistant') 'content': null,
    if (toolCallId != null) 'tool_call_id': toolCallId,
    if (toolCalls.isNotEmpty)
      'tool_calls': [for (final toolCall in toolCalls) toolCall.toJson()],
  };
}

Object _messageContent(Object content) {
  if (content is String) return content;
  if (content is List<ContentPart>) {
    return [for (final part in content) part.toJson()];
  }
  throw ArgumentError.value(
    content,
    'content',
    'Must be a String or List<ContentPart>.',
  );
}
