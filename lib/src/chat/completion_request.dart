import 'message.dart';
import 'model_profile.dart';
import 'tool.dart';

class ChatCompletionRequest {
  const ChatCompletionRequest({
    required this.model,
    required this.messages,
    this.tools = const [],
    this.toolChoice,
    this.temperature,
    this.includeUsage = true,
    this.thinking = ThinkingMode.profileDefault,
  });

  final String model;
  final List<ChatMessage> messages;
  final List<Tool> tools;
  final ToolChoice? toolChoice;
  final double? temperature;
  final bool includeUsage;
  final ThinkingMode thinking;

  Map<String, dynamic> toJson({required bool stream}) => {
    'model': model,
    'messages': [for (final message in messages) message.toJson()],
    'stream': stream,
    if (temperature != null) 'temperature': temperature,
    if (stream && includeUsage) 'stream_options': {'include_usage': true},
    if (tools.isNotEmpty) 'tools': [for (final tool in tools) tool.toJson()],
    if (toolChoice != null) 'tool_choice': toolChoice!.toJson(),
  };
}
