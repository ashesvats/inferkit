import 'dart:convert';

class ChatToolCall {
  const ChatToolCall({required this.id, required this.function});

  final String id;
  final ChatToolCallFunction function;

  factory ChatToolCall.fromJson(Map<dynamic, dynamic> json, {int index = 0}) {
    final function = json['function'];
    final rawId = json['id'];
    return ChatToolCall(
      id: rawId is String && rawId.trim().isNotEmpty ? rawId : 'call_$index',
      function: ChatToolCallFunction.fromJson(
        function is Map ? function : const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'function',
    'function': function.toJson(),
  };
}

class ChatToolCallFunction {
  const ChatToolCallFunction({required this.name, required this.arguments});

  final String name;
  final String arguments;

  factory ChatToolCallFunction.fromJson(Map<dynamic, dynamic> json) {
    final name = json['name'];
    final arguments = json['arguments'];
    return ChatToolCallFunction(
      name: name is String ? name : '',
      arguments: arguments is String ? arguments : '{}',
    );
  }

  Map<String, dynamic> get argumentsMap {
    try {
      final decoded = jsonDecode(arguments.trim().isEmpty ? '{}' : arguments);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return const {};
    }
    return const {};
  }

  Map<String, dynamic> toJson() => {'name': name, 'arguments': arguments};
}
