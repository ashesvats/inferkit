# InferKit

InferKit is a pure-Dart client for OpenAI-compatible inference servers. It is
designed for local and hosted LLM runtimes such as llama.cpp, vLLM, LM Studio,
Ollama-compatible gateways, and OpenAI-compatible cloud endpoints.

The package has two layers:

- A thin protocol client for `/v1/chat/completions` and `/v1/models`.
- An optional Agent helper that runs recursive tool-call loops for you.

InferKit has no Flutter dependency, so it can be used from Dart CLIs, servers,
tests, Flutter apps, and other Dart packages.

## Features

- OpenAI-compatible chat completions.
- Non-streaming and streaming responses.
- Typed chat messages, multimodal content parts, tools, tool choices, usage,
  and tool calls.
- Reasoning extraction from structured fields such as `reasoning_content` and
  inline tags such as `<think>...</think>`.
- Stream phase tracking for reasoning, answering, tool calling, done, and
  failed states.
- Tolerant parsing for local servers that omit fields commonly present in the
  OpenAI cloud API.
- Optional Agent layer with recursive tool execution, parallel tool calls,
  tool lifecycle events, and a concurrency limiter.
- Injectable HTTP transport for tests.

## Install

```bash
dart pub add inferkit
```

For Flutter projects:

```bash
flutter pub add inferkit
```

## Create a Client

```dart
import 'package:inferkit/inferkit.dart';

final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080/v1',
    timeout: Duration(minutes: 5),
  ),
);
```

`baseUrl` is required. InferKit appends `/v1` when it is missing, and it sends
an `Authorization` header only when `apiKey` is not empty.

## Non-Streaming Chat

```dart
final response = await client.chat.completions.create(
  ChatCompletionRequest(
    model: 'local-model',
    messages: [
      ChatMessage.system('You are concise.'),
      ChatMessage.user('Write a one sentence summary of Dart streams.'),
    ],
    temperature: 0.2,
  ),
);

print(response.text);
```

## Streaming Chat

```dart
final stream = client.chat.completions.createStream(
  ChatCompletionRequest(
    model: 'local-model',
    messages: [
      ChatMessage.user('Explain tool calling in two short paragraphs.'),
    ],
  ),
);

await for (final event in stream) {
  switch (event) {
    case ReasoningEvent():
      // Reasoning is surfaced separately from visible answer text.
      break;
    case ContentDeltaEvent():
      stdout.write(event.text);
    case ToolCallDeltaEvent():
    case UsageEvent():
    case DoneEvent():
      break;
  }
}
```

Add `import 'dart:io';` when using `stdout`.

## Track Stream Phase

```dart
final tracked = client.chat.completions
    .createStream(
      ChatCompletionRequest(
        model: 'local-model',
        messages: [ChatMessage.user('Think briefly, then answer.')],
      ),
    )
    .trackPhase();

tracked.phaseChanges.listen((phase) {
  print('phase: $phase');
});

await for (final event in tracked.events) {
  if (event is ContentDeltaEvent) {
    stdout.write(event.text);
  }
}
```

## Reasoning Configuration

By default, InferKit extracts reasoning from common local-server fields and
from inline `<think>...</think>` tags:

```dart
final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080',
    reasoning: ReasoningConfig.defaults,
  ),
);
```

Disable extraction when you want content to pass through unchanged:

```dart
final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080',
    reasoning: ReasoningConfig.none,
  ),
);
```

## Tool Calls Without Agent

The protocol client exposes tool calls but does not execute them. You can run
tools in your application and feed results back to the next request:

```dart
final tools = [
  Tool.function(
    name: 'get_current_time',
    description: 'Return the current UTC time.',
    parameters: {
      'type': 'object',
      'properties': {},
    },
  ),
];

final first = await client.chat.completions.create(
  ChatCompletionRequest(
    model: 'local-model',
    messages: [
      ChatMessage.user('What time is it? Use the tool if needed.'),
    ],
    tools: tools,
    toolChoice: ToolChoice.auto,
  ),
);

final messages = <ChatMessage>[
  ChatMessage.user('What time is it? Use the tool if needed.'),
  ChatMessage.assistant(null, toolCalls: first.toolCalls),
  for (final call in first.toolCalls)
    ChatMessage.toolResult(
      toolCallId: call.id,
      content: DateTime.now().toUtc().toIso8601String(),
    ),
];

final finalResponse = await client.chat.completions.create(
  ChatCompletionRequest(model: 'local-model', messages: messages),
);

print(finalResponse.text);
```

## Agent Helper

Use `Agent` when you want InferKit to own the recursive tool-call loop:

```dart
final agent = Agent(
  client: client,
  tools: ToolRegistry([
    ToolSpec(
      name: 'get_current_time',
      description: 'Return the current UTC time.',
      parameters: const {
        'type': 'object',
        'properties': {},
      },
      handler: (_) {
        return ToolResult(DateTime.now().toUtc().toIso8601String());
      },
    ),
  ]),
  options: const AgentOptions(
    model: 'local-model',
    maxIterations: 4,
    parallelTools: true,
    concurrencyLimit: 1,
  ),
);

await for (final event in agent.run(
  messages: [
    ChatMessage.user('What time is it? Use the tool if needed.'),
  ],
)) {
  if (event is AgentContentDelta) {
    stdout.write(event.text);
  }
  if (event is AgentFinalAnswer) {
    print('\nfinal: ${event.text}');
  }
}
```

## List Models

```dart
final models = await client.models.list();
for (final model in models.data) {
  print(model.id);
}
```

## Scope

InferKit currently focuses on OpenAI-compatible chat completions, streaming,
models, reasoning extraction, and agent tool orchestration. Embeddings and
provider-native APIs are intentionally deferred.
