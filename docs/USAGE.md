# InferKit Usage

InferKit is a pure-Dart client for OpenAI-compatible inference servers. It
works with local runtimes and hosted endpoints that expose
`/v1/chat/completions` and `/v1/models`.

## Install

```bash
dart pub add inferkit
```

For Flutter apps:

```bash
flutter pub add inferkit
```

## Import

```dart
import 'package:inferkit/inferkit.dart';
```

## Create A Client

```dart
final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080/v1',
    timeout: Duration(minutes: 5),
  ),
);
```

`baseUrl` is required. InferKit normalizes it to the `/v1` API root and only
sends an `Authorization` header when `apiKey` is non-empty.

Dispose the client when you are done if it owns its own HTTP transport:

```dart
client.dispose();
```

## Non-Streaming Chat

```dart
final response = await client.chat.completions.create(
  ChatCompletionRequest(
    model: 'local-model',
    messages: [
      ChatMessage.system('You are concise.'),
      ChatMessage.user('Write a one-sentence summary of Dart streams.'),
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

## Stream Phase Tracking

Use `trackPhase()` when you want the stream to surface phase changes alongside
the raw events.

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

`Phase` values include `idle`, `reasoning`, `answering`, `toolCalling`,
`done`, and `failed`.

## Reasoning Configuration

By default, InferKit extracts reasoning from common structured fields such as
`reasoning_content`, `reasoning`, `thinking`, and `reasoning_summary`, plus
inline `<think>...</think>` tags.

```dart
final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080',
    reasoning: ReasoningConfig.defaults,
  ),
);
```

Disable reasoning extraction when you want the response content to pass through
unchanged:

```dart
final client = InferKitClient(
  config: const ClientConfig(
    baseUrl: 'http://localhost:8080',
    reasoning: ReasoningConfig.none,
  ),
);
```

You can also customize the field names or inline tag pair with
`ReasoningConfig(...)` and `ReasoningTagConfig`.

## Multimodal Content Parts

`ChatMessage.user(...)` accepts either a plain string or a list of
`ContentPart`s.

```dart
final message = ChatMessage.user([
  const TextPart('Describe this image briefly:'),
  const ImagePart.dataUrl(
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...',
  ),
]);
```

`TextPart`, `ImagePart`, and `AudioPart` are available for multimodal requests.
`ImagePart.file(...)` and `AudioPart.file(...)` can build base64 payloads from
local files when you have `dart:io` available.

## Tool Calls Without Agent

The protocol client exposes tool calls, but it does not execute them for you.
You can send tools, inspect the returned tool calls, run your own code, and
feed results back in the next request.

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

`ToolChoice.auto`, `ToolChoice.none`, `ToolChoice.required`, and
`ToolChoice.function('name')` are all available.

## Agent Helper

Use `Agent` when you want InferKit to manage the recursive tool-call loop for
you.

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

`Agent` emits phase updates, reasoning deltas, tool lifecycle events, the final
answer, and terminal `AgentDone` / `AgentFailed` events.

## List Models

```dart
final models = await client.models.list();
for (final model in models.data) {
  print(model.id);
}
```

## Common Notes

- Streaming events are collected with `collect()` when you need a final
  `ChatCompletionResponse` from a stream.
- The client accepts an injectable HTTP transport, which is useful for tests
  and custom runtime wiring.
