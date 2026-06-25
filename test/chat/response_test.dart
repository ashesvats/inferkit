import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test(
    'parses tolerant non-stream responses with content, tools, and usage',
    () async {
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: FakeTransport(
            (_) => jsonResponse({
              'choices': [
                {
                  'index': 0,
                  'finish_reason': 'tool_calls',
                  'message': {
                    'role': 'assistant',
                    'content': '',
                    'tool_calls': [
                      {
                        'id': 'call_a',
                        'type': 'function',
                        'function': {
                          'name': 'lookup',
                          'arguments': '{"query":"ports"}',
                        },
                      },
                    ],
                  },
                },
              ],
              'usage': {
                'prompt_tokens': 2,
                'completion_tokens': 3,
                'total_tokens': 5,
              },
            }),
          ),
        ),
      );

      final response = await client.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      );

      expect(response.id, '');
      expect(response.usage?.totalTokens, 5);
      expect(response.toolCalls.single.id, 'call_a');
      expect(response.toolCalls.single.function.argumentsMap['query'], 'ports');
    },
  );

  test(
    'extracts non-stream structured and inline reasoning from content',
    () async {
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: FakeTransport(
            (_) => jsonResponse({
              'choices': [
                {
                  'index': 0,
                  'message': {
                    'role': 'assistant',
                    'reasoning_content': 'structured thought',
                    'reasoning_summary': 'summary',
                    'content': '<think>inline thought</think>Visible answer',
                  },
                },
              ],
            }),
          ),
        ),
      );

      final response = await client.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      );

      expect(response.text, 'Visible answer');
      expect(response.choices.single.reasoningText, [
        'structured thought',
        'inline thought',
      ]);
      expect(response.choices.single.reasoningSummaryText, ['summary']);
    },
  );

  test(
    'ReasoningConfig.none suppresses non-stream reasoning extraction',
    () async {
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          reasoning: ReasoningConfig.none,
          transport: FakeTransport(
            (_) => jsonResponse({
              'choices': [
                {
                  'index': 0,
                  'message': {
                    'role': 'assistant',
                    'reasoning_content': 'hidden',
                    'content': '<think>kept visible</think>Answer',
                  },
                },
              ],
            }),
          ),
        ),
      );

      final response = await client.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      );

      expect(response.text, '<think>kept visible</think>Answer');
      expect(response.choices.single.reasoningText, isEmpty);
    },
  );
}
