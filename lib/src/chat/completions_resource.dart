import 'dart:async';

import '../client.dart';
import '../core/exceptions.dart';
import '../core/http_transport.dart';
import '../core/json_utils.dart';
import 'completion_request.dart';
import 'completion_response.dart';
import 'completion_stream.dart';
import 'request_behavior_resolver.dart';

class ChatCompletionsResource {
  const ChatCompletionsResource(this._client);

  final InferKitClient _client;

  Future<ChatCompletionResponse> create(ChatCompletionRequest request) async {
    final behavior = describeRequestBehavior(_client.config, request);
    final response = await _send(request, behavior: behavior, stream: false);
    final body = await _readBody(response, 'chat');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwHttpFailure(response.statusCode, body, 'Chat request failed');
    }
    return ChatCompletionResponse.fromJson(
      decodeJsonObject(body),
      reasoning: behavior.reasoning,
    );
  }

  Stream<ChatCompletionStreamEvent> createStream(
    ChatCompletionRequest request,
  ) async* {
    final behavior = describeRequestBehavior(_client.config, request);
    final response = await _send(request, behavior: behavior, stream: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await _readBody(response, 'chat');
      throwHttpFailure(response.statusCode, body, 'Chat request failed');
    }
    try {
      yield* parseChatCompletionStream(
        response.bodyStream,
        reasoning: behavior.reasoning,
        timeout: _client.config.timeout,
      );
    } on TimeoutException {
      throw const InferKitTimeoutException('The chat stream timed out.');
    } on InferKitException {
      rethrow;
    } catch (error) {
      throw NetworkException('The chat stream failed: $error');
    }
  }

  Future<HttpTransportResponse> _send(
    ChatCompletionRequest request, {
    required ResolvedRequestBehavior behavior,
    required bool stream,
  }) async {
    try {
      return await _client.transport.send(
        HttpTransportRequest(
          method: 'POST',
          uri: _client.endpoint('/chat/completions'),
          headers: _client.headers(),
          body: behavior.toJson(request, stream: stream),
          timeout: _client.config.timeout,
        ),
      );
    } on TimeoutException {
      throw const InferKitTimeoutException('The chat request timed out.');
    } on InferKitException {
      rethrow;
    } catch (error) {
      throw NetworkException('Could not reach the inference server: $error');
    }
  }

  Future<String> _readBody(
    HttpTransportResponse response,
    String operation,
  ) async {
    try {
      return await response.bodyText(timeout: _client.config.timeout);
    } on TimeoutException {
      throw InferKitTimeoutException('The $operation response timed out.');
    } on InferKitException {
      rethrow;
    } catch (error) {
      throw NetworkException('The $operation response failed: $error');
    }
  }
}
