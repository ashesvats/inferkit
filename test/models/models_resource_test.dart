import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test('lists model ids from OpenAI-compatible /models response', () async {
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: FakeTransport((request) {
          expect(request.method, 'GET');
          expect(request.uri.toString(), 'http://localhost:8080/v1/models');
          return jsonResponse({
            'data': [
              {'id': 'llama'},
              {'id': 'qwen'},
            ],
          });
        }),
      ),
    );

    final models = await client.models.list();

    expect(models.data.map((model) => model.id), ['llama', 'qwen']);
  });
}
