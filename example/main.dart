import 'dart:io';

import 'package:inferkit/inferkit.dart';

Future<void> main() async {
  final client = InferKitClient(
    config: const ClientConfig(
      baseUrl: 'http://localhost:8080/v1',
      timeout: Duration(minutes: 5),
    ),
  );

  try {
    final request = ChatCompletionRequest(
      model: 'local-model',
      messages: [
        ChatMessage.system('You are concise.'),
        ChatMessage.user('Say hello from InferKit in one sentence.'),
      ],
      temperature: 0.2,
    );

    final stream = client.chat.completions.createStream(request).trackPhase();
    stream.phaseChanges.listen((phase) {
      stderr.writeln('phase: $phase');
    });

    await for (final event in stream.events) {
      if (event is ContentDeltaEvent) {
        stdout.write(event.text);
      }
    }
    stdout.writeln();
  } finally {
    client.dispose();
  }
}
