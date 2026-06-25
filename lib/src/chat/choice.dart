import 'message.dart';

class ChatCompletionChoice {
  const ChatCompletionChoice({
    required this.index,
    required this.message,
    this.finishReason,
    this.reasoningText = const [],
    this.reasoningSummaryText = const [],
  });

  final int index;
  final ChatMessage message;
  final String? finishReason;
  final List<String> reasoningText;
  final List<String> reasoningSummaryText;
}
