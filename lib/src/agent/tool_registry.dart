import 'dart:async';
import 'dart:convert';

import '../chat/tool.dart';
import '../chat/tool_call.dart';

typedef ToolHandler =
    FutureOr<ToolResult> Function(Map<String, dynamic> arguments);

class ToolResult {
  const ToolResult(
    this.content, {
    this.metadata = const {},
    this.displayPayload,
  });

  final String content;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? displayPayload;
}

class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final ToolHandler handler;

  Tool toProtocolTool() => Tool.function(
    name: name,
    description: description,
    parameters: parameters,
  );
}

class ToolRegistry {
  ToolRegistry(Iterable<ToolSpec> tools)
    : _tools = {for (final tool in tools) tool.name: tool};

  final Map<String, ToolSpec> _tools;

  List<Tool> get protocolTools => [
    for (final tool in _tools.values) tool.toProtocolTool(),
  ];

  ToolSpec? operator [](String name) => _tools[name];

  bool contains(String name) => _tools.containsKey(name);

  Future<ToolExecutionResult> execute(ChatToolCall call) async {
    final spec = _tools[call.function.name];
    if (spec == null) {
      return ToolExecutionResult.failed(
        call: call,
        content: jsonEncode({
          'error': 'Unsupported tool: ${call.function.name}',
        }),
        error: 'Unsupported tool: ${call.function.name}',
        unsupported: true,
      );
    }
    try {
      final result = await spec.handler(call.function.argumentsMap);
      return ToolExecutionResult.completed(
        call: call,
        content: result.content,
        metadata: result.metadata,
        displayPayload: result.displayPayload,
      );
    } catch (error) {
      final message = '$error';
      return ToolExecutionResult.failed(
        call: call,
        content: jsonEncode({'error': message}),
        error: message,
      );
    }
  }
}

class ToolExecutionResult {
  const ToolExecutionResult._({
    required this.call,
    required this.content,
    required this.succeeded,
    this.error,
    this.unsupported = false,
    this.metadata = const {},
    this.displayPayload,
  });

  factory ToolExecutionResult.completed({
    required ChatToolCall call,
    required String content,
    Map<String, dynamic> metadata = const {},
    Map<String, dynamic>? displayPayload,
  }) => ToolExecutionResult._(
    call: call,
    content: content,
    succeeded: true,
    metadata: metadata,
    displayPayload: displayPayload,
  );

  factory ToolExecutionResult.failed({
    required ChatToolCall call,
    required String content,
    required String error,
    bool unsupported = false,
    Map<String, dynamic>? displayPayload,
  }) => ToolExecutionResult._(
    call: call,
    content: content,
    succeeded: false,
    error: error,
    unsupported: unsupported,
    displayPayload: displayPayload,
  );

  final ChatToolCall call;
  final String content;
  final bool succeeded;
  final String? error;
  final bool unsupported;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? displayPayload;
}
