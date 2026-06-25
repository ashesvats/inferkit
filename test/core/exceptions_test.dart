import 'dart:async';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test('maps common HTTP failures to typed exceptions', () async {
    final cases = <int, Type>{
      400: BadRequestException,
      401: AuthenticationException,
      403: AuthenticationException,
      429: RateLimitException,
      500: ServerException,
    };

    for (final entry in cases.entries) {
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: FakeTransport(
            (_) => jsonResponse({
              'error': {'message': 'boom'},
            }, statusCode: entry.key),
          ),
        ),
      );

      expect(
        () => client.chat.completions.create(
          ChatCompletionRequest(
            model: 'llama',
            messages: [ChatMessage.user('hello')],
          ),
        ),
        throwsA(
          isA<InferKitException>().having(
            (error) => error.runtimeType,
            'type',
            entry.value,
          ),
        ),
      );
    }
  });

  test('invalid JSON becomes InvalidResponseException', () async {
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: FakeTransport((_) => textResponse('{nope')),
      ),
    );

    expect(
      () => client.models.list(),
      throwsA(isA<InvalidResponseException>()),
    );
  });

  test('transport timeout and arbitrary failures map to typed exceptions', () {
    final timeoutClient = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: FakeTransport((_) => throw TimeoutException('slow')),
      ),
    );
    final networkClient = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: FakeTransport((_) => throw StateError('socket gone')),
      ),
    );

    expect(
      () => timeoutClient.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      ),
      throwsA(isA<InferKitTimeoutException>()),
    );
    expect(
      () => networkClient.chat.completions.create(
        ChatCompletionRequest(
          model: 'llama',
          messages: [ChatMessage.user('hello')],
        ),
      ),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'body read timeout and stream body failures map to typed exceptions',
    () {
      final timeoutClient = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          timeout: const Duration(milliseconds: 1),
          transport: FakeTransport(
            (_) => HttpTransportResponse(
              statusCode: 200,
              headers: const {},
              bodyStream: Stream<List<int>>.periodic(
                const Duration(milliseconds: 50),
                (_) => const <int>[],
              ),
            ),
          ),
        ),
      );
      final streamFailureClient = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: FakeTransport(
            (_) => HttpTransportResponse(
              statusCode: 200,
              headers: const {},
              bodyStream: Stream<List<int>>.error(StateError('socket gone')),
            ),
          ),
        ),
      );

      expect(
        () => timeoutClient.chat.completions.create(
          ChatCompletionRequest(
            model: 'llama',
            messages: [ChatMessage.user('hello')],
          ),
        ),
        throwsA(isA<InferKitTimeoutException>()),
      );
      expect(
        () =>
            streamFailureClient.chat.completions
                .createStream(
                  ChatCompletionRequest(
                    model: 'llama',
                    messages: [ChatMessage.user('hello')],
                  ),
                )
                .drain<void>(),
        throwsA(isA<NetworkException>()),
      );
    },
  );
}
