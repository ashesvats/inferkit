import 'dart:convert';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

void main() {
  test(
    'serializes multimodal messages, tools, tool choice, and stream options',
    () {
      final request = ChatCompletionRequest(
        model: 'vision-model',
        temperature: 0.2,
        messages: [
          ChatMessage.system('be useful'),
          ChatMessage.user([
            const TextPart('read this'),
            const ImagePart.dataUrl('data:image/png;base64,abc'),
          ]),
        ],
        tools: const [
          Tool.function(
            name: 'lookup',
            description: 'Look up facts',
            parameters: {'type': 'object'},
          ),
        ],
        toolChoice: ToolChoice.function('lookup'),
      );

      final json = request.toJson(stream: true);

      expect(json['stream'], true);
      expect(json['stream_options'], {'include_usage': true});
      expect(json['temperature'], 0.2);
      expect(json['tool_choice'], {
        'type': 'function',
        'function': {'name': 'lookup'},
      });
      expect(jsonEncode(json['messages']), contains('image_url'));
    },
  );

  test('serializes assistant tool-call and tool-result messages', () {
    final toolCall = ChatToolCall(
      id: 'call_1',
      function: const ChatToolCallFunction(
        name: 'lookup',
        arguments: '{"query":"x"}',
      ),
    );

    expect(ChatMessage.assistant(null, toolCalls: [toolCall]).toJson(), {
      'role': 'assistant',
      'content': null,
      'tool_calls': [
        {
          'id': 'call_1',
          'type': 'function',
          'function': {'name': 'lookup', 'arguments': '{"query":"x"}'},
        },
      ],
    });
    expect(
      ChatMessage.toolResult(toolCallId: 'call_1', content: 'result').toJson(),
      {'role': 'tool', 'content': 'result', 'tool_call_id': 'call_1'},
    );
  });
}
