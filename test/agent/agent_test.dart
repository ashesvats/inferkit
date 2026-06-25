import 'dart:async';
import 'dart:convert';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test('streams a no-tool answer', () async {
    final transport = FakeTransport(
      (_) async => sseResponse([
        _chunk(content: 'Hello'),
        _chunk(content: ' there', finishReason: 'stop'),
        '[DONE]',
      ]),
    );
    final agent = _agent(transport, tools: const []);

    final events = await agent.run(messages: [ChatMessage.user('Hi')]).toList();

    expect(_content(events), 'Hello there');
    expect(_final(events), 'Hello there');
    expect(events.whereType<AgentDone>(), hasLength(1));
  });

  test('executes one tool round then answers', () async {
    var requestCount = 0;
    final transport = FakeTransport((_) async {
      requestCount++;
      if (requestCount == 1) {
        return sseResponse([
          _toolChunk(
            id: 'call_1',
            name: 'clock',
            arguments: '{"local":true}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      return sseResponse([
        _chunk(content: 'It is noon.', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(
      transport,
      tools: [
        _tool(
          'clock',
          (arguments) => ToolResult('12:00', metadata: {'seen': arguments}),
        ),
      ],
    );

    final events =
        await agent.run(messages: [ChatMessage.user('Time?')]).toList();

    final batch = events.whereType<AgentToolCallsRequested>().single;
    expect(batch.iteration, 1);
    expect(batch.toolCalls.map((call) => call.id), ['call_1']);
    expect(events.whereType<AgentToolStarted>(), hasLength(1));
    expect(events.whereType<AgentToolFinished>(), hasLength(1));
    expect(
      events.indexOf(batch),
      lessThan(_firstIndex<AgentToolStarted>(events)),
    );
    expect(_final(events), 'It is noon.');
    expect(requestCount, 2);
  });

  test('recurses through multiple tool rounds', () async {
    var requestCount = 0;
    final transport = FakeTransport((_) async {
      requestCount++;
      if (requestCount < 3) {
        return sseResponse([
          _toolChunk(
            id: 'call_$requestCount',
            name: 'step',
            arguments: '{"n":$requestCount}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      return sseResponse([
        _chunk(content: 'Done.', finishReason: 'stop'),
        '[DONE]',
      ]);
    });

    final events =
        await _agent(
          transport,
          tools: [_tool('step', (arguments) => ToolResult('ok'))],
        ).run(messages: [ChatMessage.user('Go')]).toList();

    expect(events.whereType<AgentToolFinished>(), hasLength(2));
    expect(
      events.whereType<AgentToolCallsRequested>().map(
        (event) => event.iteration,
      ),
      [1, 2],
    );
    expect(
      events.whereType<AgentToolFinished>().map((event) => event.iteration),
      [1, 2],
    );
    expect(_final(events), 'Done.');
  });

  test('executes multiple tools in deterministic order', () async {
    var requestCount = 0;
    final completions = <Completer<ToolResult>>[
      Completer<ToolResult>(),
      Completer<ToolResult>(),
    ];
    final transport = FakeTransport((_) async {
      requestCount++;
      if (requestCount == 1) {
        return sseResponse([
          _toolChunk(index: 0, id: 'slow', name: 'slow', arguments: '{}'),
          _toolChunk(
            index: 1,
            id: 'fast',
            name: 'fast',
            arguments: '{}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      return sseResponse([
        _chunk(content: 'ok', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(
      transport,
      tools: [
        _tool('slow', (_) => completions[0].future),
        _tool('fast', (_) => completions[1].future),
      ],
    );
    final future = agent.run(messages: [ChatMessage.user('Tools')]).toList();
    completions[1].complete(const ToolResult('fast'));
    completions[0].complete(const ToolResult('slow'));

    final events = await future;
    final finished = events.whereType<AgentToolFinished>().toList();
    expect(finished.map((event) => event.result.call.id), ['slow', 'fast']);
  });

  test('passes tool display payload through execution result', () async {
    var requestCount = 0;
    final transport = FakeTransport((_) async {
      requestCount++;
      if (requestCount == 1) {
        return sseResponse([
          _toolChunk(
            id: 'call_1',
            name: 'panel',
            arguments: '{}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      return sseResponse([
        _chunk(content: 'ok', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(
      transport,
      tools: [
        _tool(
          'panel',
          (_) => const ToolResult(
            'tool content',
            displayPayload: {'title': 'Display this'},
          ),
        ),
      ],
    );

    final events =
        await agent.run(messages: [ChatMessage.user('Show')]).toList();

    final finished = events.whereType<AgentToolFinished>().single;
    expect(finished.result.content, 'tool content');
    expect(finished.result.displayPayload, {'title': 'Display this'});
  });

  test('isolates failed and unsupported tools', () async {
    var requestCount = 0;
    final transport = FakeTransport((request) async {
      requestCount++;
      if (requestCount == 1) {
        return sseResponse([
          _toolChunk(index: 0, id: 'bad', name: 'bad', arguments: '{}'),
          _toolChunk(
            index: 1,
            id: 'missing',
            name: 'missing',
            arguments: '{}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      final body = request.body as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      expect(messages.where((m) => m['role'] == 'tool'), hasLength(2));
      return sseResponse([
        _chunk(content: 'Recovered.', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(
      transport,
      tools: [_tool('bad', (_) => throw StateError('boom'))],
    );

    final events =
        await agent.run(messages: [ChatMessage.user('Fail')]).toList();

    final failed = events.whereType<AgentToolFailed>().toList();
    expect(failed, hasLength(2));
    expect(failed.last.result.unsupported, isTrue);
    expect(_final(events), 'Recovered.');
  });

  test('forces a final answer when max iterations is reached', () async {
    var requestCount = 0;
    final transport = FakeTransport((request) async {
      requestCount++;
      if (requestCount == 1) {
        return sseResponse([
          _toolChunk(
            id: 'again',
            name: 'again',
            arguments: '{}',
            finishReason: 'tool_calls',
          ),
          '[DONE]',
        ]);
      }
      final body = request.body as Map<String, dynamic>;
      expect(body.containsKey('tools'), isFalse);
      return sseResponse([
        _chunk(content: 'Final.', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(
      transport,
      tools: [_tool('again', (_) => const ToolResult('again'))],
      maxIterations: 1,
    );

    final events =
        await agent.run(messages: [ChatMessage.user('Loop')]).toList();

    expect(events.whereType<AgentMaxIterationsReached>(), hasLength(1));
    final finalAnswer = events.whereType<AgentFinalAnswer>().single;
    expect(finalAnswer.text, 'Final.');
    expect(finalAnswer.forced, isTrue);
    expect(finalAnswer.reason, AgentFinalReason.maxIterations);
    expect(finalAnswer.finishReason, 'stop');
  });

  test('keeps concurrent runs isolated', () async {
    var requestCount = 0;
    final transport = FakeTransport((request) async {
      requestCount++;
      final body = request.body as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final user = messages.firstWhere((m) => m['role'] == 'user')['content'];
      return sseResponse([
        _chunk(content: 'answer:$user', finishReason: 'stop'),
        '[DONE]',
      ]);
    });
    final agent = _agent(transport, tools: const [], concurrencyLimit: 2);

    final results = await Future.wait([
      agent.run(messages: [ChatMessage.user('a')]).toList(),
      agent.run(messages: [ChatMessage.user('b')]).toList(),
    ]);

    expect(_final(results[0]), 'answer:a');
    expect(_final(results[1]), 'answer:b');
    expect(requestCount, 2);
  });
}

Agent _agent(
  FakeTransport transport, {
  required List<ToolSpec> tools,
  int maxIterations = 8,
  int concurrencyLimit = 1,
}) {
  return Agent(
    client: InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080/v1',
        transport: transport,
      ),
    ),
    tools: ToolRegistry(tools),
    options: AgentOptions(
      model: 'model',
      maxIterations: maxIterations,
      concurrencyLimit: concurrencyLimit,
    ),
  );
}

ToolSpec _tool(String name, ToolHandler handler) => ToolSpec(
  name: name,
  description: '$name tool',
  parameters: const {'type': 'object'},
  handler: handler,
);

String _content(List<AgentEvent> events) =>
    events.whereType<AgentContentDelta>().map((event) => event.text).join();

String _final(List<AgentEvent> events) =>
    events.whereType<AgentFinalAnswer>().single.text;

int _firstIndex<T extends AgentEvent>(List<AgentEvent> events) =>
    events.indexWhere((event) => event is T);

String _chunk({String? content, String? finishReason}) => jsonEncode({
  'choices': [
    {
      'delta': {if (content != null) 'content': content},
      if (finishReason != null) 'finish_reason': finishReason,
    },
  ],
});

String _toolChunk({
  int index = 0,
  required String id,
  required String name,
  required String arguments,
  String? finishReason,
}) => jsonEncode({
  'choices': [
    {
      'delta': {
        'tool_calls': [
          {
            'index': index,
            'id': id,
            'type': 'function',
            'function': {'name': name, 'arguments': arguments},
          },
        ],
      },
      if (finishReason != null) 'finish_reason': finishReason,
    },
  ],
});
