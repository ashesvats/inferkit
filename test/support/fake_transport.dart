import 'dart:async';
import 'dart:convert';

import 'package:inferkit/inferkit.dart';

class FakeTransport implements HttpTransport {
  FakeTransport(this._handler);

  final FutureOr<HttpTransportResponse> Function(HttpTransportRequest request)
  _handler;

  final requests = <HttpTransportRequest>[];
  var closed = false;

  @override
  Future<HttpTransportResponse> send(HttpTransportRequest request) async {
    requests.add(request);
    return _handler(request);
  }

  @override
  void close() {
    closed = true;
  }
}

HttpTransportResponse jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => textResponse(jsonEncode(body), statusCode: statusCode);

HttpTransportResponse textResponse(String body, {int statusCode = 200}) {
  return HttpTransportResponse(
    statusCode: statusCode,
    headers: const {'content-type': 'application/json'},
    bodyStream: Stream.value(utf8.encode(body)),
  );
}

HttpTransportResponse sseResponse(List<String> events) {
  return HttpTransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'text/event-stream'},
    bodyStream: Stream.fromIterable([
      for (final event in events) utf8.encode('data: $event\n\n'),
    ]),
  );
}
