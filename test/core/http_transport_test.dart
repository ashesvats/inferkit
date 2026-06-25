import 'dart:convert';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test(
    'chat completions append /v1 and send auth only when api key is set',
    () async {
      final transport = FakeTransport((request) {
        expect(request.method, 'POST');
        expect(
          request.uri.toString(),
          'http://localhost:8080/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer secret');
        expect(request.headers['X-Test'], 'yes');
        final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
        expect(body['model'], 'llama');
        expect(body['stream'], false);
        expect(body['messages'], [
          {'role': 'user', 'content': 'hello'},
        ]);
        return jsonResponse({
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'hi'},
            },
          ],
        });
      });
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          apiKey: ' secret ',
          headers: const {'X-Test': 'yes'},
          transport: transport,
        ),
      );

      final response = await client.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      );

      expect(response.text, 'hi');
    },
  );

  test(
    'authorization header is omitted for local servers without api keys',
    () async {
      final transport = FakeTransport((request) {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return jsonResponse({'data': []});
      });
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080/v1',
          transport: transport,
        ),
      );

      await client.models.list();
    },
  );
}
