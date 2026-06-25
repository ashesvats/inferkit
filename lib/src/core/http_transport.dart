import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class HttpTransportRequest {
  const HttpTransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.timeout,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
  final Duration timeout;

  String get bodyText => body == null ? '' : jsonEncode(body);
}

class HttpTransportResponse {
  const HttpTransportResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyStream,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Stream<List<int>> bodyStream;

  Future<String> bodyText({Duration? timeout}) {
    final stream = bodyStream.transform(utf8.decoder);
    final future = stream.join();
    return timeout == null ? future : future.timeout(timeout);
  }
}

abstract interface class HttpTransport {
  factory HttpTransport.client({http.Client? client}) = HttpClientTransport;

  Future<HttpTransportResponse> send(HttpTransportRequest request);

  void close();
}

class HttpClientTransport implements HttpTransport {
  HttpClientTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<HttpTransportResponse> send(HttpTransportRequest request) async {
    final outgoing =
        http.Request(request.method, request.uri)
          ..headers.addAll(request.headers)
          ..body = request.bodyText;
    final response = await _client.send(outgoing).timeout(request.timeout);
    return HttpTransportResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyStream: response.stream,
    );
  }

  @override
  void close() => _client.close();
}
