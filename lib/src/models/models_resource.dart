import 'dart:async';

import '../client.dart';
import '../core/exceptions.dart';
import '../core/http_transport.dart';
import '../core/json_utils.dart';

class ModelsResource {
  const ModelsResource(this._client);

  final InferKitClient _client;

  Future<ModelList> list() async {
    try {
      final response = await _client.transport.send(
        HttpTransportRequest(
          method: 'GET',
          uri: _client.endpoint('/models'),
          headers: _client.headers(),
          body: null,
          timeout: _client.config.timeout,
        ),
      );
      final body = await _readBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throwHttpFailure(response.statusCode, body, 'Models request failed');
      }
      return ModelList.fromJson(decodeJsonObject(body));
    } on TimeoutException {
      throw const InferKitTimeoutException('The models request timed out.');
    } on InferKitException {
      rethrow;
    } catch (error) {
      throw NetworkException('Could not reach the inference server: $error');
    }
  }

  Future<String> _readBody(HttpTransportResponse response) async {
    try {
      return await response.bodyText(timeout: _client.config.timeout);
    } on TimeoutException {
      throw const InferKitTimeoutException('The models response timed out.');
    } on InferKitException {
      rethrow;
    } catch (error) {
      throw NetworkException('The models response failed: $error');
    }
  }
}

class ModelList {
  const ModelList(this.data);

  final List<ModelInfo> data;

  factory ModelList.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const InvalidResponseException(
        'The inference server returned no models.',
      );
    }
    return ModelList([
      for (final item in data)
        if (item is Map && item['id'] is String)
          ModelInfo(id: item['id'] as String),
    ]);
  }
}

class ModelInfo {
  const ModelInfo({required this.id});

  final String id;
}
