import 'dart:convert';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test(
    'streams content, structured reasoning, usage, and done events',
    () async {
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: FakeTransport(
            (_) => sseResponse([
              jsonEncode({
                'choices': [
                  {
                    'delta': {'reasoning_content': 'thinking'},
                  },
                ],
              }),
              jsonEncode({
                'choices': [
                  {
                    'delta': {'content': 'Hello'},
                  },
                ],
              }),
              jsonEncode({
                'choices': [],
                'usage': {'total_tokens': 9},
              }),
              '[DONE]',
            ]),
          ),
        ),
      );

      final events =
          await client.chat.completions
              .createStream(
                ChatCompletionRequest(
                  model: 'llama',
                  messages: [ChatMessage.user('hi')],
                ),
              )
              .toList();

      expect(events.whereType<ReasoningEvent>().single.text, 'thinking');
      expect(events.whereType<ContentDeltaEvent>().single.text, 'Hello');
      expect(events.whereType<UsageEvent>().single.usage.totalTokens, 9);
      expect(events.last, isA<DoneEvent>());
    },
  );

  test('strips inline reasoning split across chunks', () async {
    final events =
        await parseChatCompletionStream(
          sseResponse([
            jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'A <thi'},
                },
              ],
            }),
            jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'nk>secret</think> B'},
                },
              ],
            }),
            '[DONE]',
          ]).bodyStream,
          reasoning: ReasoningConfig.defaults,
          timeout: const Duration(seconds: 1),
        ).toList();

    expect(
      events.whereType<ContentDeltaEvent>().map((event) => event.text).join(),
      'A  B',
    );
    expect(events.whereType<ReasoningEvent>().single.text, 'secret');
  });

  test('disabled reasoning leaves inline tags in content', () async {
    final events =
        await parseChatCompletionStream(
          sseResponse([
            jsonEncode({
              'choices': [
                {
                  'delta': {'content': '<think>visible</think>'},
                },
              ],
            }),
            '[DONE]',
          ]).bodyStream,
          reasoning: ReasoningConfig.none,
          timeout: const Duration(seconds: 1),
        ).toList();

    expect(events.whereType<ReasoningEvent>(), isEmpty);
    expect(
      events.whereType<ContentDeltaEvent>().single.text,
      '<think>visible</think>',
    );
  });

  test('collect assembles text and streamed tool calls', () async {
    final response =
        await Stream<ChatCompletionStreamEvent>.fromIterable(const [
          ContentDeltaEvent('Hi'),
          ToolCallDeltaEvent(index: 0, id: 'call_1', name: 'lookup'),
          ToolCallDeltaEvent(index: 0, argumentsChunk: '{"query"'),
          ToolCallDeltaEvent(index: 0, argumentsChunk: ':"x"}'),
          DoneEvent(finishReason: 'tool_calls'),
        ]).collect();

    expect(response.text, 'Hi');
    expect(response.choices.single.finishReason, 'tool_calls');
    expect(response.toolCalls.single.function.name, 'lookup');
    expect(response.toolCalls.single.function.argumentsMap['query'], 'x');
  });

  test('stream parser carries finish reason from final choice chunk', () async {
    final events =
        await parseChatCompletionStream(
          sseResponse([
            jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'Done'},
                },
              ],
            }),
            jsonEncode({
              'choices': [
                {'delta': {}, 'finish_reason': 'stop'},
              ],
            }),
            '[DONE]',
          ]).bodyStream,
          reasoning: ReasoningConfig.defaults,
          timeout: const Duration(seconds: 1),
        ).toList();

    expect(events.whereType<DoneEvent>().single.finishReason, 'stop');
  });
}
